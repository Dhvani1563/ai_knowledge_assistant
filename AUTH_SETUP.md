# Authentication setup (Google + Facebook)

Email/password works with **no setup**. Google and Facebook need a few
one-time steps in their developer consoles — that is the part I can't do
for you. Budget ~30–40 minutes. Do Google first, test it, then Facebook.

## What you need on your laptop

| Need | Why |
|---|---|
| Flutter SDK **3.27+** (`flutter --version`) | the UI uses current Material 3 APIs |
| Docker Desktop | runs the backend, Postgres and Qdrant |
| Java/`keytool` (ships with Android Studio, or install a JDK) | to read your Android signing fingerprint |
| A Google account | Google Cloud Console + Gemini key |
| A Facebook account | Facebook for Developers |
| Phone + laptop on the **same Wi-Fi** | phone must reach the backend |

---

## Part A — Google Sign-In

### A1. Create the project + consent screen
1. Go to https://console.cloud.google.com → project picker → **New Project** → name it `Archive`.
2. **APIs & Services → OAuth consent screen** → User type **External** → fill app name + your email → Save.
3. On the **Audience / Test users** step, **add your own Google account** as a test user
   (while the app is in "Testing", only listed accounts can sign in).

### A2. Create three OAuth client IDs (APIs & Services → Credentials → Create credentials → OAuth client ID)

**1) Web application** — the important one
- Name: `Archive Web`. Create. Copy the **Client ID**
  (`123…apps.googleusercontent.com`).
- Paste it in **two places** (they must be identical):
  - `backend/.env` → `GOOGLE_CLIENT_ID=...`
  - `frontend/lib/core/constants/app_constants.dart` → `googleWebClientId`

**2) Android** (needed even though the code uses the web ID — Google uses it to
recognise your app)
- Package name: open `frontend/android/app/build.gradle(.kts)` → `applicationId`
  (e.g. `com.example.ai_knowledge_assistant`).
- SHA-1 of your debug key:
  - Mac/Linux: `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android`
  - Windows: `keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore -alias androiddebugkey -storepass android -keypass android`
  - Copy the `SHA1:` line.
- Create the client with that package name + SHA-1.
- **Shipping a release build later?** Add the release keystore's SHA-1 too.

**3) iOS** (only if you test on an iPhone)
- Bundle ID from Xcode (Runner → Signing & Capabilities). Create the client.
- In `ios/Runner/Info.plist` add (use the iOS client's ID; the URL scheme is that
  ID *reversed*, e.g. `com.googleusercontent.apps.123-abc`):
```xml
<key>GIDClientID</key>
<string>123-abc.apps.googleusercontent.com</string>
<key>GIDServerClientID</key>
<string>YOUR_WEB_CLIENT_ID.apps.googleusercontent.com</string>
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array><string>com.googleusercontent.apps.123-abc</string></array>
  </dict>
</array>
```

### A3. Test
Restart the backend after editing `.env` (`docker compose up -d --force-recreate api`),
run the app, tap **Continue with Google**.

---

## Part B — Facebook Login

### B1. Create the app
1. https://developers.facebook.com → **My Apps → Create App**.
2. Use case: **Authenticate and request data from users with Facebook Login**.
3. **App settings → Basic**: copy **App ID** and **App Secret**
   → `backend/.env` (`FACEBOOK_APP_ID`, `FACEBOOK_APP_SECRET`).
4. **App settings → Advanced → Security → Client token**: copy it (used below).
5. **Roles → Roles / Test Users**: your app starts in **Development mode** —
   only people with a role can log in. Make sure **your** Facebook account is an
   Admin/Developer/Tester.

### B2. Android setup
Add the **Android** platform in the Facebook dashboard: package name (same
`applicationId`), class name `<applicationId>.MainActivity`, and your **key hash**:

```bash
# Mac/Linux (needs openssl)
keytool -exportcert -alias androiddebugkey -keystore ~/.android/debug.keystore | openssl sha1 -binary | openssl base64
# password when asked: android
```

Create `android/app/src/main/res/values/strings.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">Archive</string>
    <string name="facebook_app_id">YOUR_APP_ID</string>
    <string name="fb_login_protocol_scheme">fbYOUR_APP_ID</string>
    <string name="facebook_client_token">YOUR_CLIENT_TOKEN</string>
</resources>
```

In `android/app/src/main/AndroidManifest.xml`:
```xml
<manifest ...>
    <uses-permission android:name="android.permission.INTERNET"/>

    <!-- lets the app detect the Facebook app on Android 11+ -->
    <queries>
        <package android:name="com.facebook.katana"/>
    </queries>

    <application
        android:networkSecurityConfig="@xml/network_security_config" ...>
        <meta-data android:name="com.facebook.sdk.ApplicationId" android:value="@string/facebook_app_id"/>
        <meta-data android:name="com.facebook.sdk.ClientToken" android:value="@string/facebook_client_token"/>
        ...
    </application>
</manifest>
```
(`network_security_config` is the plain-HTTP dev exception from the device setup guide.)

### B3. iOS setup (iPhone only)
Add to `ios/Runner/Info.plist`:
```xml
<key>FacebookAppID</key><string>YOUR_APP_ID</string>
<key>FacebookClientToken</key><string>YOUR_CLIENT_TOKEN</string>
<key>FacebookDisplayName</key><string>Archive</string>
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array><string>fbYOUR_APP_ID</string></array>
  </dict>
</array>
<key>LSApplicationQueriesSchemes</key>
<array><string>fbapi</string><string>fb-messenger-share-api</string></array>
```

### B4. Going public later
To let people who aren't on your team log in you must switch the app to **Live**,
which requires a Privacy Policy URL, an app icon and a category. `email` and
`public_profile` normally need no extra review.

---

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Google: `ApiException: 10` / `DEVELOPER_ERROR` | Android client's package name or SHA-1 doesn't match the build you're running |
| Google: "did not return an ID token" | `googleWebClientId` in `app_constants.dart` is still the placeholder, or isn't the **Web** client |
| Backend: "Invalid Google token … audience" | `GOOGLE_CLIENT_ID` in `backend/.env` ≠ the ID in `app_constants.dart` (or you didn't restart the API) |
| Google picker shows "access blocked" | your account isn't in the consent screen's **Test users** |
| Facebook: "App not active" / login page errors | app is in Development mode and your account has no role on it |
| Facebook: "key hash does not match" | regenerate the hash from the keystore you're actually signing with |
| Facebook: "no email to sign up with" | user has no verified email on Facebook; use Google or email signup instead |
| Any social login: "Could not reach the server" | wrong `apiBaseUrl` (must be your laptop's LAN IP on a physical device) |

The token check happens **on the server** (`backend/app/services/oauth_service.py`):
the app only ever sends a provider token; the backend verifies it with
Google/Facebook and issues its own JWT. Never trust profile data sent by the client.
