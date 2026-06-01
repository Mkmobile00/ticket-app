# Activating Google Sign-In & Push Notifications

The app is wired for both, but each needs a Firebase/Google project you own.
Until you complete the steps below, the rest of the app works normally —
the Google button stays hidden and push is simply inactive.

---

## A. Google Sign-In

**Code already in place:** `AuthNotifier.googleLogin()` (lib/providers/providers.dart),
a "Continue with Google" button on the login screen, and
`ApiConfig.googleServerClientId` (lib/core/api/api_config.dart). The backend
endpoint `POST /auth/google {id_token}` is already implemented.

**Steps:**
1. Create a project at <https://console.firebase.google.com> (or Google Cloud).
2. Add an **Android app** with package name `com.buleto.buleto_app`.
3. Get your app's signing SHA-1 and add it in Firebase:
   ```powershell
   cd android
   ./gradlew signingReport
   ```
   Copy the `SHA1` under the `debug` variant → Firebase → Project settings →
   your Android app → "Add fingerprint".
4. Download **`google-services.json`** → place it in `android/app/google-services.json`.
5. In Google Cloud console → APIs & Services → Credentials, copy the
   **Web client** OAuth 2.0 Client ID (auto-created by Firebase, type "Web client").
6. Paste it into `lib/core/api/api_config.dart`:
   ```dart
   static const String googleServerClientId =
       '1234567890-abcdef.apps.googleusercontent.com';
   ```
7. (Backend) ensure the same project's email is allowed; the Laravel side
   verifies the token against Google's tokeninfo endpoint — no extra config needed.
8. `flutter run`. The Google button now appears and works.

> Note: Google Sign-In needs the `google-services` Gradle plugin **only** if you
> also use Firebase. For Google Sign-In alone, `serverClientId` + the SHA-1
> fingerprint registered in the console is sufficient on Android.

---

## B. Push Notifications (FCM)

**Code already in place:** `ApiService.registerDevice(token, platform)` and
`removeDevice(token)` call the backend endpoints `POST /device-token` and
`DELETE /device-token`. What's left is adding Firebase Messaging and calling
`registerDevice` after login.

**Steps:**
1. Complete A.1–A.4 above (same Firebase project + `google-services.json`).
2. Add packages to `pubspec.yaml`:
   ```yaml
   firebase_core: ^3.6.0
   firebase_messaging: ^15.1.3
   ```
   then `flutter pub get`.
3. Apply the Google services Gradle plugin:
   - `android/settings.gradle` → add to the `plugins { }` block:
     ```
     id "com.google.gms.google-services" version "4.4.2" apply false
     ```
   - `android/app/build.gradle` → add to its `plugins { }` block:
     ```
     id "com.google.gms.google-services"
     ```
4. Generate Firebase options:
   ```powershell
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   This writes `lib/firebase_options.dart`.
5. In `lib/main.dart`, initialise Firebase before `runApp`:
   ```dart
   WidgetsFlutterBinding.ensureInitialized();
   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
   ```
6. After a successful login (e.g. in `AuthNotifier.login/register/googleLogin`),
   register the device token:
   ```dart
   final fcm = await FirebaseMessaging.instance.getToken();
   if (fcm != null) {
     await ref.read(apiProvider).registerDevice(fcm, platform: 'android');
   }
   ```
   And on logout call `removeDevice(fcm)` before clearing the session.
7. Handle messages:
   ```dart
   FirebaseMessaging.onMessage.listen((m) { /* show in-app banner */ });
   ```

> ⚠️ Do **not** add the `google-services` Gradle plugin until
> `android/app/google-services.json` exists — the build fails without it.
> That's why these steps are documented rather than pre-applied.
