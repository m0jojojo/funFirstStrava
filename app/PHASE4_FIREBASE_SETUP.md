# Phase 4 — Firebase setup

## 1. Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com) and create a project (or use an existing one).
2. **Authentication** → **Sign-in method** → enable **Google**.
3. **Project settings** (gear) → note your **Project ID** (e.g. `my-game-123`).

## 2. Backend (.env)

In `server/.env` add:

```env
FIREBASE_PROJECT_ID=your_project_id_here
```

Use the Project ID from step 1.

## 3. Android: google-services.json and SHA-1 (required for Google Sign-In)

1. In Firebase Console → **Project settings** → **Your apps** → **Add app** → **Android** (or open your existing Android app).
2. Package name: `com.territorygame.app`.
3. **Add your debug SHA-1** (required for Sign in with Google on device/emulator):
   - On Windows, in a terminal run:
     ```bash
     keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
     ```
   - Copy the **SHA-1** line (e.g. `SHA1: A1:B2:C3:...`).
   - In Firebase → Project settings → Your apps → your Android app → **Add fingerprint** → paste the SHA-1 → Save.
4. Download **google-services.json** again (so it includes the OAuth client for your SHA-1) and replace:
   ```
   app/android/app/google-services.json
   ```
5. Do **not** commit real `google-services.json` if it contains secrets; the repo may already ignore it or you can add it to `.gitignore` and use a placeholder for CI.

If you see **sign_in_failed / Api10** on Android, the app is not authorized: add the debug SHA-1 in Firebase and use the newly downloaded `google-services.json`.

## 4. Run backend and app

1. Start the server (from repo root):

   ```bash
   cd server
   npm run start:dev
   ```

2. Run the app (from repo root):

   ```bash
   cd app
   flutter pub get
   flutter run -d windows
   # or: flutter run -d chrome
   # or: flutter run   (and pick Android if configured)
   ```

3. Tap **Sign in with Google**; after success you should be on the home screen and a row should appear in the `users` table.

## 5. Web (Chrome): Google Sign-In client ID

To use **Sign in with Google** when running in the browser (`flutter run -d chrome`), you must set a **Web OAuth 2.0 Client ID**.

1. Open [Google Cloud Console → Credentials](https://console.cloud.google.com/apis/credentials) and select the **same project** as Firebase (e.g. `funfirststrava`).
2. Click **Create credentials** → **OAuth client ID**.
3. Application type: **Web application**. Name it e.g. "Territory Game Web".
4. Under **Authorized JavaScript origins** add:
   - `http://localhost`
   - `http://localhost:PORT` for any port you use (e.g. `http://localhost:57939`), or `http://127.0.0.1`
5. Create the client and copy the **Client ID** (format: `XXXXX-YYYYY.apps.googleusercontent.com`).
6. Replace the placeholder in **two places**:
   - **`app/web/index.html`** — in the `<meta name="google-signin-client_id" content="...">` tag, replace `626019867864-YOUR_WEB_CLIENT_HASH.apps.googleusercontent.com` with your full Client ID.
   - **`app/lib/firebase_options.dart`** — set `webGoogleSignInClientId` to the same Client ID string.

After that, `flutter run -d chrome` will be able to use Google Sign-In.

## 6. Android emulator → backend on host

If the app runs on an Android emulator and the backend is on your PC, use `http://10.0.2.2:3000` instead of `localhost:3000`. Change `apiBaseUrl` in `app/lib/core/api_config.dart` or add a build flavor/env for emulator.
