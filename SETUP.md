# Fauridoc — Firebase & Maps Setup (step by step)

The app runs **fully without Firebase** (demo mode, with the full researched
KP directory: 189 doctors, 14 labs, 21 hospitals). Follow these steps only
when you want real cloud data, Google/phone logins, and the live map.

**What you'll end with:** Google sign-in + phone OTP login, your 189 doctors
in Firestore, an admin account that can edit/delete every record, and a
working Map tab.

---

## 1. Create the Firebase project

1. Go to https://console.firebase.google.com/ → **Add project** → name it
   `fauridoc` (any name works). You can skip Google Analytics.

## 2. Register the Android app

1. In the project: **Project settings → Add app → Android**.
2. Android package name: `com.afzal.fauridoc`
3. App nickname: `Fauridoc`.
4. **Download `google-services.json`** and place it at:
   `fauridoc/android/app/google-services.json`
   (The Gradle build applies the Google Services plugin automatically only
   when this file exists — the repo is already wired for this.)

## 3. Enable sign-in methods (Google + Phone)

1. **Build → Authentication → Get started → Sign-in method**.
2. Enable **Google** — this powers the "Continue with Google" button.
   - Support email: your email. Save.
3. Enable **Phone** — this powers the phone-OTP login.
   - Save. (For testing on your own number you can add it under
     "Phone numbers for testing" with a fixed code like `123456`, so you
     don't burn SMS quota while trying the flow.)

> The app has no email/password login — only Google and phone OTP, plus a
> demo login when Firebase isn't configured.

## 4. Add your SHA-1 / SHA-256 keys (required for Google sign-in)

Google sign-in silently fails on Android if the app's signing key isn't
registered. Add **both** your debug and release keys:

1. **Project settings → Your apps → Android app → Add fingerprint.**
2. Get the fingerprints:
   - Debug (your machine): `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android`
   - Release: the keystore you sign the Play build with (same command,
     your keystore path/alias/password).
3. Paste the SHA-1 (and SHA-256) values, save.
4. **Re-download `google-services.json`** (it embeds the OAuth client) and
   replace the file in `fauridoc/android/app/`.

## 5. Create the Firestore database

1. **Build → Firestore Database → Create database** → production mode →
   pick the closest region (e.g. `asia-south1`).
2. **Rules tab** → replace the rules with the contents of `firestore.rules`
   in this repo → **Publish**.

Collections are created automatically on first write: `doctors`, `labs`,
`hospitals`, `questions` (+ `replies` subcollection), `users`, `admins`,
`config`, `doctor_stats`.

## 6. Enable Storage (clinic photos)

1. **Build → Storage → Get started** → production mode.
2. Rules tab → allow signed-in users to upload:
   ```
   rules_version = '2';
   service firebase.storage {
     match /b/{bucket}/o {
       match /entity_photos/{allPaths=*} {
         allow read: if true;
         allow write: if request.auth != null;
       }
     }
   }
   ```

## 7. Make yourself admin

1. Install the app, open the Profile tab, and sign in (Google or phone).
2. In Firebase console → **Authentication → Users** → copy your **UID**.
3. **Firestore → `admins` collection → Add document**:
   - Document ID = your UID (paste it as the ID, don't auto-generate).
   - Add any field, e.g. `name: "owner"` → Save.
4. Restart the app — **Admin panel** now appears in your Profile tab.

## 8. Import the researched directory (one tap)

1. Open the app → Profile → **Admin panel** (bottom of the page).
2. Scroll to the **Seed data** card → tap **Import seed data**.
3. It copies all 189 doctors, 14 labs, and 21 hospitals into Firestore
   (overwrites by ID — safe to re-run, never duplicates).
4. From then on you can **edit or delete any record** from the same panel,
   and approve/reject new user submissions.

## 9. Google Maps API key (for the Map tab)

1. Go to https://console.cloud.google.com/ → select your project →
   **APIs & Services → Library** → enable **Maps SDK for Android**.
   (Billing must be enabled on the Google Cloud project — Google gives a
   monthly free quota that covers a directory app like this.)
2. **APIs & Services → Credentials → Create credentials → API key**.
3. Restrict the key: Android apps → package `com.afzal.fauridoc` + your
   SHA-1 (recommended).
4. Put the key in **two** places, then rebuild:
   - `fauridoc/lib/src/config.dart` → replace `YOUR_MAPS_API_KEY`
   - `fauridoc/android/app/src/main/AndroidManifest.xml` → replace `YOUR_MAPS_API_KEY`
5. Until you do this, the Map tab shows a stylized placeholder with
   tappable pins — everything else works.

## 10. Rebuild

Push to `main` — GitHub Actions builds fresh APKs (artifact:
`fauridoc-apks`). If you pushed with the GitHub App token and no build
started, run manually: `gh workflow run "Android" --ref main`.

---

## Quick checklist

- [ ] `google-services.json` in `android/app/`
- [ ] Auth: Google **and** Phone enabled
- [ ] SHA-1/SHA-256 fingerprints added (debug + release)
- [ ] Firestore created + `firestore.rules` published
- [ ] Storage created + photo rules published
- [ ] Your UID added to `admins`
- [ ] Seed data imported from the Admin panel
- [ ] Maps API key in `config.dart` + `AndroidManifest.xml`
