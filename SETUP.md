# Flash Me Flutter Project Setup

This document outlines the setup steps for the Flash Me Flutter project.

## Project Structure

```
lib/
├── models/              # Data models (User, Card, CardSet, etc.)
├── services/            # Business logic and Firestore integration
├── providers/           # Riverpod state management providers
├── screens/             # UI screens
├── widgets/             # Reusable widgets
├── theme/               # Theme and styling
├── utils/               # Helper functions and constants
├── firebase_options.dart # Firebase configuration
└── main.dart            # App entry point
```

## Dependencies Installed

### Firebase
- `firebase_core` — Firebase core library
- `firebase_auth` — Authentication
- `cloud_firestore` — Database
- `firebase_storage` — File storage
- `google_sign_in` — Google OAuth
- `google_sign_in_web` — Web OAuth support

### State Management
- `riverpod` — Functional reactive programming
- `flutter_riverpod` — Flutter integration

### Other
- `file_picker` — File selection
- `csv` — CSV parsing
- `intl` — Internationalization
- `shared_preferences` — Local storage
- `logger` — Logging
- `http` — HTTP client
- `connectivity_plus` — Connectivity checking

## Next Steps: Firebase Configuration

### 1. Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create a new project: "flash-me"
3. Enable the following services:
   - **Authentication** (Email/Password + Google Sign-In)
   - **Firestore Database** (Production mode, start with restrictive rules)
   - **Cloud Storage** (for future features)

### 2. Run FlutterFire CLI
The fastest way to configure Firebase for all platforms:

```bash
# Install FlutterFire CLI if not already installed
dart pub global activate flutterfire_cli

# Configure Firebase (from project root)
flutterfire configure
```

This will:
- Detect all platforms
- Generate `firebase_options.dart` automatically
- Configure Android, iOS, Web, macOS, Windows, Linux

### 3. Android Setup (if not done by flutterfire configure)

#### 3.1 Generate Release Keystore

For Google Sign-In and app signing, generate a release keystore:

```bash
cd android/app
keytool -genkey -v -keystore release.keystore -keyalg RSA -keysize 2048 -validity 10000 -alias release
```

When prompted, enter:
- **Keystore password**: A secure password (save this!)
- **First and last name**: Your name
- **Organizational unit**: Leave empty (press Enter)
- **Organization**: Leave empty (press Enter)
- **City or Locality**: Your city
- **State or Province**: Your state
- **Two-letter country code**: Your country code (e.g., US, CZ)

Once created, extract the SHA-1 fingerprint for Firebase:

```bash
keytool -list -v -keystore release.keystore -alias release
```

Copy the SHA-1 value (format: XX:XX:XX:XX...). You'll add this to Firebase Console later.

#### 3.2 Android Services Configuration

1. Add Google services configuration:
   - Download `google-services.json` from Firebase Console
   - Place in `android/app/`

2. Update `android/build.gradle.kts`:
   ```kotlin
   buildscript {
       dependencies {
           classpath("com.google.gms:google-services:4.3.15")
       }
   }
   ```

3. Update `android/app/build.gradle.kts`:
   ```kotlin
   plugins {
       id("com.android.application")
       id("kotlin-android")
       id("com.google.gms.google-services")
       id("dev.flutter.flutter-gradle-plugin")
   }
   ```

### 4. iOS Setup (if not done by flutterfire configure)

1. Download `GoogleService-Info.plist` from Firebase Console
2. Add to Xcode:
   - Open `ios/Runner.xcworkspace`
   - Add file: `GoogleService-Info.plist`
   - Target: Runner

3. Update iOS deployment target to 11.0+ in Xcode

### 5. Web Setup (if not done by flutterfire configure)

Firebase Web SDK is automatically included in the HTML.

### 6. Update Firebase Security Rules

1. Go to Firebase Console → Firestore Database → Rules
2. Replace default rules with:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
    }

    // Templates collection
    match /templates/{templateId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == resource.data.userId;
      allow create: if request.auth != null && request.resource.data.userId == request.auth.uid;
    }

    // Cards collection
    match /cards/{cardId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == resource.data.createdBy;
      allow create: if request.auth != null && request.resource.data.createdBy == request.auth.uid;
    }

    // Card sets collection
    match /sets/{setId} {
      allow read, write: if request.auth.uid == resource.data.userId;
      allow create: if request.auth != null && request.resource.data.userId == request.auth.uid;
    }

    // Study sessions
    match /users/{userId}/studySessions/{sessionId} {
      allow read, write: if request.auth.uid == userId;
    }
  }
}
```

### 7. Enable Google Sign-In

1. Go to Firebase Console → Authentication → Sign-in method
2. Enable "Google"
3. Set project public name and support email
4. **For Android**: Add SHA-1 fingerprint
   - Go to Firebase Console → Project Settings → Android
   - Add new Android app (if not already added)
   - In the fingerprints section, add the SHA-1 you extracted from the keystore:
     ```
     18:0E:21:10:D6:C0:82:9D:74:9D:0F:0C:6D:FC:EE:34:9A:4E:7E:4B
     ```
     (Replace with your actual SHA-1 from `keytool -list -v -keystore release.keystore -alias release`)

### 8. Run Flutter Pub Get

```bash
flutter pub get
```

## Running the App

```bash
# Check connected devices
flutter devices

# Run on specific device
flutter run -d <device_id>

# Run with logging
flutter run -v

# Run on web (development)
flutter run -d chrome
```

## Troubleshooting

### Firebase initialization fails
- Ensure `firebase_options.dart` is correctly generated
- Check that Firebase project is created and configured
- Verify API keys are correct

### Build fails on iOS
- Ensure deployment target is 11.0+
- Run `flutter clean` and rebuild
- Delete `ios/Pods` and run `flutter pub get`

### Google Sign-In not working
- On Android: Ensure SHA-1 fingerprint is registered in Firebase
  ```bash
  ./gradlew signingReport  # from android/ directory
  ```
- Copy SHA-1 and add to Firebase Console → Project Settings → Android

### Firestore connection issues
- Verify security rules allow your user
- Check Firestore database is enabled
- Ensure Firebase is properly initialized

## Development Tips

- Use `flutter run` with `--dart-define-from-file=.env.json` for environment-specific configurations
- Enable Firestore logging for debugging: `FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false);`
- Use Firebase Emulator Suite for local development:
  ```bash
  firebase emulators:start
  ```

## Next: Phase 1 Implementation

After Firebase is configured, proceed with:
1. Creating authentication screens (sign up, sign in)
2. Implementing AuthService methods
3. Setting up auth state management
4. Testing authentication flows on all platforms
