# Fauridoc — Firebase & Maps Setup

The app runs **fully without Firebase** (demo mode, with sample KP data).
Follow these steps only when you want real cloud data, logins, and the map.

## 1. Create the Firebase project

1. Go to https://console.firebase.google.com/ → **Add project** → name it `fauridoc` (any name works).
2. You can skip Google Analytics.

## 2. Register the Android app

1. In the project: **Project settings → Add app → Android**.
2. Android package name: `com.afzal.fauridoc`
3. App nickname: `Fauridoc`.
4. **Download `google-services.json`** and place it at:
   `fauridoc/android/app/google-services.json`
   (The build applies the Google Services plugin automatically only when this file exists.)

## 3. Enable Authentication

1. **Build → Authentication → Get started**.
2. Enable **Email/Password**.
3. Enable **Google** (needed for the "Continue with Google" button).

## 4. Create the Firestore database

1. **Build → Firestore Database → Create database** → production mode → pick the closest region (e.g. `asia-south1`).
2. **Rules tab** → replace the rules with the contents of `firestore.rules` in this repo → **Publish**.

Collections are created automatically by the app on first write:
`doctors`, `labs`, `hospitals`, `questions` (+ `replies` subcollection),
`users`, `admins`, `config`, `doctor_stats`.

## 5. Enable Storage (clinic photos)

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

## 6. Make yourself admin

1. Run the app once and create an account (or log in with Google).
2. In Firestore, open the `admins` collection → **Add document**.
3. Document ID = your user's UID (from Authentication → Users → copy UID).
4. Add any field, e.g. `name: "owner"` → Save.
5. Restart the app — the **Admin panel** now appears in your Profile tab.

## 7. Google Maps API key (for the Map tab)

1. Go to https://console.cloud.google.com/ → same project → **APIs & Services → Credentials → Create credentials → API key**.
2. Enable **Maps SDK for Android** (APIs & Services → Library).
3. Restrict the key to Android apps with package `com.afzal.fauridoc` (recommended).
4. Put the key in **two** places, then rebuild:
   - `fauridoc/lib/src/config.dart` → replace `YOUR_MAPS_API_KEY`
   - `fauridoc/android/app/src/main/AndroidManifest.xml` → replace `YOUR_MAPS_API_KEY`
5. Until you do this, the Map tab shows a friendly setup card — everything else works.

## 8. Rebuild

Push to `main` — GitHub Actions builds fresh APKs automatically
(artifact: `fauridoc-apks`).
