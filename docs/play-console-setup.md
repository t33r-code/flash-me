# Google Play Console Setup

One-time setup guide for registering a Play Console account, creating the Flash Me app, and wiring up CI/CD access for GitHub Actions.

---

## Step 1 — Register a Google Play Developer account

1. Go to **play.google.com/console**
2. Sign in with the Google account you want to own the app (use your dev account, not a personal one you'd regret)
3. Accept the Developer Distribution Agreement
4. Pay the **one-time $25 USD registration fee** (credit card)
5. Fill in your developer profile — you can use your real name or a studio/brand name; this is what appears on the Play Store

Registration is usually approved within a few minutes to a few hours.

---

## Step 2 — Create the app

Once your account is active:

1. Click **Create app**
2. Fill in:
   - App name: `Flash Me`
   - Default language: English
   - App or game: App
   - Free or paid: Free
3. Accept the declarations and click **Create app**

---

## Step 3 — Minimum store listing

Play Console requires some basics even for internal testing:

1. Under **Grow → Store presence → Main store listing**, fill in:
   - Short description (80 chars)
   - Full description (placeholder is fine for now)
   - **App icon**: 512×512 PNG (required)
   - **Feature graphic**: 1024×500 PNG
   - At least **2 screenshots** (phone)
2. Under **Policy → App content**, complete:
   - Content rating questionnaire
   - Data safety form
   - Other required policy declarations

The content can be rough for now — polish it before going public.

---

## Step 4 — Set up internal testing track

Internal testing allows up to 100 testers via an invite link, with no Play Store review required and instant availability.

1. Go to **Testing → Internal testing**
2. Click **Create new release**
3. Upload the first AAB manually here (see note below)
4. Under **Testers**, click **Create email list**, name it (e.g. "Dev testers"), and add email addresses
5. Play Console provides a **shareable opt-in link** — share this with testers; the app is invisible to everyone else

> **First upload must be manual.** Play Console needs to see the first AAB through the web UI to register the package name and accept the signing key. After that, CI handles all subsequent uploads.
>
> See `docs/ci-cd-setup.md` for instructions on generating the release keystore and building a signed AAB.

---

## Step 5 — Service account for CI/CD

This allows GitHub Actions to push new builds automatically.

1. In Play Console, go to **Setup → API access**
2. Click **Link to a Google Cloud project** → choose an existing project or create a new one (e.g. `flash-me-ci`)
3. Click **Create new service account**
4. Follow the link to **Google Cloud Console**, then:
   - Click **Create service account**
   - Name: `github-actions-deploy`
   - Navigate to **Keys → Add key → Create new key → JSON** and download the file
5. Back in Play Console, click **Done** on the service account dialog
6. Find the new account in the service accounts list and click **Grant access**
7. Set the role to **Release manager**
8. Click **Invite user** to confirm

Store the downloaded JSON key file as a GitHub Actions secret named `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`.

---

## Summary — what each step unlocks

| Completed | Unlocks |
|---|---|
| Play Console account + app created | Manual uploads, internal test track |
| First AAB uploaded manually | CI can upload subsequent builds |
| Service account JSON in GitHub secrets | GitHub Actions auto-deploy on `release/**` push |
| Keystore in GitHub secrets | Consistent app signing across all builds |
