# Restart the Firebase emulators between integration-test retry attempts (#264).
#
# The emulators are started once per job (see integration_tests.yml) and shared by
# every retry attempt. That makes the retry only able to absorb *client-side* flakes:
# if the emulator itself wedges, the next attempt reconnects to the same broken
# server and fails identically — which is exactly what #264 observed, with both
# attempts failing on the same test with the same signature on two unrelated
# branches. Tearing the emulators down and bringing them back up gives each retry a
# genuinely independent backend.
#
# Wiping emulator data is safe here: every test run creates its own users and
# documents with unique per-run IDs (see integration_test/firebase_test_config.dart),
# so no attempt depends on state left behind by a previous one.

$ErrorActionPreference = 'Stop'

# Ports the auth + firestore emulators and their support services listen on,
# mirroring firebase.json. Killing by port rather than by process name avoids
# taking down unrelated node/java processes on the runner.
$emulatorPorts = @(8080, 9099, 4000, 4400, 4500, 9150)
$readinessPorts = @(8080, 9099)

Write-Host 'Stopping existing Firebase emulator processes...'
$emulatorPids = Get-NetTCPConnection -LocalPort $emulatorPorts -State Listen -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty OwningProcess -Unique

if (-not $emulatorPids) {
    # Expected when the previous attempt died outright rather than hanging.
    Write-Host '  nothing listening - emulator already gone'
} else {
    foreach ($emulatorPid in $emulatorPids) {
        try {
            Stop-Process -Id $emulatorPid -Force -ErrorAction Stop
            Write-Host "  stopped PID $emulatorPid"
        } catch {
            Write-Host "  could not stop PID $emulatorPid ($($_.Exception.Message))"
        }
    }
    # Give the OS a moment to release the ports before rebinding them.
    Start-Sleep -Seconds 5
}

Write-Host 'Starting Firebase emulators...'
# Launched via cmd so the npm-installed `firebase.cmd` shim resolves from PATH,
# and so the process outlives this script the way the job's initial bash `&` does.
Start-Process -FilePath 'cmd.exe' `
    -ArgumentList '/c', 'firebase emulators:start --only auth,firestore --project demo-test' `
    -NoNewWindow

# Poll until both ports accept connections, matching the job's initial readiness gate.
foreach ($port in $readinessPorts) {
    $deadline = (Get-Date).AddSeconds(90)
    $ready = $false
    while ((Get-Date) -lt $deadline) {
        try {
            $client = New-Object System.Net.Sockets.TcpClient
            $client.Connect('localhost', $port)
            $client.Close()
            $ready = $true
            break
        } catch {
            Start-Sleep -Seconds 3
        }
    }
    if (-not $ready) {
        throw "Firebase emulator port $port did not become ready within 90s"
    }
    Write-Host "  port $port ready"
}

Write-Host 'Emulators restarted.'
