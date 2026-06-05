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

## B. Push Notifications (FCM) — NOW FULLY WIRED ✅

Both the **app** and the **Laravel backend** are implemented end to end. The only
things left are the two credential files only you can create from your Firebase
project. Until they're added, everything still runs — push is just inactive.

### What's already done (no code to write)

**Flutter** (`buleto_app`):
- `firebase_core`, `firebase_messaging`, `flutter_local_notifications` in `pubspec.yaml`.
- `google-services` Gradle plugin applied (`android/settings.gradle` + `android/app/build.gradle`).
- `POST_NOTIFICATIONS` permission in `AndroidManifest.xml`.
- `lib/core/push/push_service.dart` — init, permission request, foreground
  notifications, background handler, tap → deep-link routing.
- `main.dart` calls `PushService.init()`; `AuthNotifier` registers the device
  token after login/register/Google and on app-start, re-registers on token
  refresh, and unregisters on logout. Taps route via `app.dart`.

**Laravel** (`Buleto`):
- `App\Services\FcmService` — sends via the FCM **HTTP v1** API (auth by signing a
  JWT with the service-account key; no extra Composer package).
- Auto-push when a booking is confirmed (`SendBookingConfirmationNotification`).
- `php artisan bookings:remind` (scheduled every 15 min) for showtime reminders.
- Admin → **Push Notifications** page to broadcast / target one user.
- Config: `config/services.php → firebase`; env `FIREBASE_CREDENTIALS`, `FIREBASE_PROJECT_ID`.

### Steps to activate (your two credential files)

1. Firebase console → your project (steps A.1–A.3 above register the Android app
   `com.buleto.buleto_app` and SHA-1).
2. **App client key:** download **`google-services.json`** → place at
   `buleto_app/android/app/google-services.json`. Then:
   ```powershell
   cd buleto_app
   flutter pub get
   flutter run        # Android auto-reads google-services.json (no flutterfire needed)
   ```
   On first sign-in the app asks for notification permission and registers its token.
3. **Backend sender key:** Firebase console → Project settings → **Service accounts**
   → **Generate new private key** (downloads a JSON). Put it at:
   ```
   Buleto/storage/app/firebase/service-account.json
   ```
   (or set `FIREBASE_CREDENTIALS` in `.env` to its path). That's it — `project_id`
   is read from the file. Confirm in Admin → **Push Notifications** (status shows
   "Firebase connected") and hit **Send** to a registered device.
4. **Reminders (optional):** ensure the Laravel scheduler runs, e.g. a cron entry:
   ```
   * * * * * cd /path/to/Buleto && php artisan schedule:run >> /dev/null 2>&1
   ```

> iOS additionally needs an APNs key uploaded to Firebase and a
> `GoogleService-Info.plist`; the code paths are platform-agnostic and will work
> once that's added.
