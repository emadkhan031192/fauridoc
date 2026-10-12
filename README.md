# Fauridoc — فوری ڈاک

Find a verified doctor, compare lab test prices, or locate the nearest
hospital — instantly. Built for KP (Mardan, Peshawar, Abbottabad, Swabi,
Nowshera and more).

- **Package:** `com.afzal.fauridoc` · **Version:** 1.0.0+1
- **Stack:** Flutter (Android first), Riverpod 3, Firebase (optional), Google Maps

## Features (all 13 spec sections)

1. **Home** — specialty chips, city-scoped doctor list, one-tap **Nearest Hospital Emergency** button.
2. **Search** — Doctors / Lab Tests / Hospitals toggle, city + specialty filters, sort (rating / most reviewed / newest), **Within 5 km** filter.
3. **Lab test search** — search by test name or category; lab cards show the price for that test; lab detail has full test-price list, hours, View on Map.
4. **Hospitals** — 24/7 emergency flag, departments, emergency contact, visiting hours, distance sorting, map pins.
5. **Doctor profiles** — photo + up to 3 clinic photos, qualification, clinic, address, phone/WhatsApp, hours, languages, **live open/closed status** computed from hours, **Leave Mode** banner, verified badge, Call/WhatsApp/Map buttons.
6. **Map** — doctor/lab/hospital pins in different colors, city jump, tap pin → mini card (rating, parking, fee) → full profile.
7. **Reviews** — one review per user per doctor (enforced), average recalculates automatically, admin can delete.
8. **Community Q&A** — questions tagged by city + specialty, Doctor badge on doctor replies, upvote/downvote, admin pin/delete.
9. **Registration** — anyone can register a doctor/lab/hospital → **Pending Approval** queue, invisible until admin approves. Admins can also create listings directly.
10. **Doctor stats dashboard** — weekly profile views + WhatsApp clicks on the doctor's own management screen.
11. **Admin panel** — live counts, one-tap approve/reject, edit/delete listings, editable city/specialty/test-category lists, review/post moderation.
12. **EN/UR** — one-tap toggle, instant RTL, Noto Nastaliq Urdu font, plain spoken Urdu strings.
13. **No login wall** — browsing is open; login only needed to review, register, or post.

## Demo mode (no Firebase needed)

If `Firebase.initializeApp()` fails (no `google-services.json` yet), the app
runs fully on an in-memory + SharedPreferences repository with seeded KP data:
10 doctors, 4 labs with test prices, 4 hospitals, sample community questions.
Registrations, reviews, votes, and config edits persist on-device.

In demo mode, **Settings → Admin preview** lets you try the admin panel.

## Setup (going live)

See [SETUP.md](SETUP.md): create Firebase project → drop in
`google-services.json` → enable Auth/Firestore/Storage → publish
`firestore.rules` → add your UID to the `admins` collection → add a Maps API
key (in `lib/src/config.dart` **and** `AndroidManifest.xml`).

## Builds

GitHub Actions (`.github/workflows/android.yml`): Flutter 3.47.7, Java 17 —
`pub get` → `analyze` → `test` → `flutter build apk --debug --split-per-abi` →
artifact **`fauridoc-apks`**. Debug-signed, sideloadable. No release keystore
yet — the user adds Play signing later.

## Judgment calls (beyond the brief)

- App icon: generated teal cross + pulse mark (`assets/icon_mark.png`); launcher icons generated via flutter_launcher_icons.
- Doctor "fee" and "parking" fields exist on the model and show on cards/map mini-cards (spec mentions them on map mini-cards).
- Leave Mode is a free-text "till" field (e.g. "10 Aug") on the registration form.
- Overnight clinic hours (e.g. 20:00–02:00) are supported in the open/closed computation.
- Firestore `doctor_stats` docs are admin-readable; view increments are open (needed pre-login).
- `firestore.rules`: public reads of approved listings only; pending visible to admins; users can create pending listings with their own `ownerUid`; one review per user enforced in the repository layer (rules require `userId == auth.uid` on create).
- Urdu specialty names are translated (e.g. Dermatologist → امراضِ جلد); city names stay in Latin script as proper nouns.
