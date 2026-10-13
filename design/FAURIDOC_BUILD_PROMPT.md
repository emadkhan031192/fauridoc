# Fauridoc — Android build prompt (pixel-exact to the supplied UI)

You are a senior Flutter engineer. Build the Android app **Fauridoc** so that every screen matches the supplied design **exactly** — same colours, sizes, spacing, radii, type, icons, copy, and tap behaviour. I build on **GitHub Actions only** (no local Flutter), so everything must compile and build in CI without manual steps.

## 0. Source of truth
- `design/fauridoc-screens.html` is the **exact visual spec**: one standalone HTML file (open it in any browser, no build step) containing all 16 screens as 390 × 844 px phone artboards (1 CSS px = 1 Flutter logical px). Each screen is a `<section id="Main">`, `id="Doctor"`, etc. Its inline styles are the literal values to port: `padding`, `margin`, `gap`, `width/height`, `border-radius`, `font-size/weight`, `letter-spacing`, `line-height`, colours, borders, box-shadows and every inline `<svg>` (use `flutter_svg` `SvgPicture.string` with the same markup, or `CustomPaint` for the map).
- `design/source-dc/*.dc.html` are the original editable sources. They contain the **sample data and interaction logic** (`renderVals()`, state, `<sc-if>`/`<sc-for>`). They do not open on their own in a browser — use them only to read the data and behaviour, and use `fauridoc-screens.html` for the look.
- Do not "improve" the design. If something is ambiguous, the HTML wins. Do not add screens, colours or text that are not in the files.
- Screens: `Splash`, `Onboarding`, `Main` (Home, English), `HomeUrdu` (same Home in Urdu/RTL), `Search`, `Emergency`, `Doctor`, `Lab`, `Hospital`, `Map`, `Reviews`, `Community`, `Profile`, `Register`, `Stats`, `Admin`.

## 1. Product
Fauridoc is a health directory for Khyber Pakhtunkhwa (starting with Mardan): verified doctors, lab test price comparison, nearest emergency hospital, and a community Q&A. It is a **directory, not a booking app** — patients call, WhatsApp or open the map. Doctors/labs/hospitals submit listings; an admin approves them. English + Urdu (RTL). No ads, no data selling.

## 2. Tech stack
- Flutter stable, Dart 3, Material 3 turned on but **all components custom-styled to the design** (do not leave default Material look).
- State: `flutter_riverpod`. Navigation: `go_router` (or Navigator 2) with a 5-tab shell.
- Backend: **Firebase** — Auth (phone OTP), Cloud Firestore, Storage, Cloud Messaging optional. Use `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`. Provide `lib/firebase_options.dart` loading from `google-services.json` (placeholder file with clear instructions; the app must still **run with a local mock repository** when Firebase is not configured — a `Repository` interface with `MockRepository` (seed data from the design) and `FirestoreRepository`, switched by a single flag).
- Maps: `google_maps_flutter` for the Map screen with custom pin markers (render the design's pins to bitmaps via `PictureRecorder`), API key read from `AndroidManifest` meta-data placeholder `${MAPS_API_KEY}` fed from a GitHub secret. If no key, fall back to the static painted map from the design (`CustomPaint`).
- Others: `url_launcher` (tel:, WhatsApp wa.me, maps), `geolocator` (distance + "nearest"), `flutter_svg`, `google_fonts` (Albert Sans 400–800; Noto Nastaliq Urdu 400/500/700; **bundle the font files in `assets/fonts` so it works offline**), `image_picker`, `shared_preferences`, `intl`.
- minSdk 23, targetSdk latest. App id `com.afzal.fauridoc`, label "Fauridoc". Adaptive launcher icon: white rounded-square mark on `#0B6B5C` (use the logo SVG from `Splash.dc.html`).

## 3. Design tokens (use exactly)
Colours: primary green `#0B6B5C`, dark green `#0B5446`, ink `#0F2A2E`, page background `#F5F7F6`, border `#E1E7E4`, input border `#D5DEDA`, muted text `#566B68`, secondary text `#3E5754`, placeholder `#6B7F7B`, lime `#D2F55A` with lime-ink `#33430A`, mint `#DDF0EA`, emergency red `#C62828` / `#D7263D`, open green `#1FA463`, closed grey `#8A9A96`, leave orange `#FF7A1A`, rating star `#F5B400`. Doctor-card pastels (cycled): `#E1F3EC`, `#E3EBFF`, `#FFE9DA`, `#F8E3EE`, `#F1EFD8`. Hero tints: doctor `#FFE6D2` (text `#8A3F00`), lab `#E3E9FF` (`#2B3F9E`), hospital `#F8DDDB` (`#C62828`). Map background `#E7EDEA`. Splash background `#0B6B5C`. Copy any other colour straight from the file you are porting.
Type: Albert Sans; screen titles 28/800 (−0.02em), app-bar titles 20/800, section titles 17/700–800, body 14–15, captions 12–13; Urdu uses Noto Nastaliq Urdu with the line-heights in `HomeUrdu.dc.html`.
Shape: cards 18–26 radius, pills fully round, buttons 44–54 high, tap targets ≥ 44. Press feedback: scale to 0.97 in 80 ms (`.press` class). Every screen scrolls without a scrollbar. Leave the status bar area (top padding 48–52 px as in the files); use edge-to-edge with transparent status bar and dark icons.
Create `lib/design/tokens.dart` (colours, text styles, radii) and reusable widgets: `PressScale`, `Pill`, `RatingPill`, `StatusDot`, `VerifiedTick`, `StatStrip`, `AppBackBar`, `SectionTitle`, `PrimaryButton`, `BottomTabBar` (see §5).

## 4. Data model (Firestore collections)
- `doctors`: name, nameUr, specialty, specialtyUr, qualification, hospitalOrClinic, city, address, addressUr, geo (lat,lng), phone, whatsapp, languages[], workingDays/hours (per-day open/close), fee, parking, photoUrls[], rating, reviewCount, status {open|closed|leave}, leaveUntil, ownerUid, approval {pending|approved|rejected}, createdAt, views/whatsappClicks/calls/mapOpens counters.
- `labs`: name, city, address, geo, phone, hours, rating, reviewCount, tests[{name, note, price, category}], approval.
- `hospitals`: name, city, address, geo, emergencyPhone, emergency24x7, departments[], visitingHours, rating, reviewCount, approval.
- `reviews`: targetType, targetId, uid, authorName, stars, text, createdAt (one per user per target; edit/delete own).
- `posts` (community): authorUid, authorName, city, specialty/topic, title, body, score, replies[{by, isDoctor, text, when}], pinned, flags.
- `users`: phone, name, city, language, role {user|doctor|lab|hospital|admin}.
- Firestore rules: public read of `approval == approved`; owners write their own; admin custom claim writes all; reviews one-per-user; counters via increments. Provide `firestore.rules` and `storage.rules`.
- Seed the `MockRepository` with the **exact sample data** in the HTML files (names, prices, counts, reviews). All of it is placeholder — keep phone numbers as `XXX` style until I replace them.

## 5. Navigation
Bottom tab bar (exactly as drawn in Map/Community/Profile): **Home, Search, Map, Community, Profile** (icons + labels, active = primary green). Splash → Onboarding (first launch only) → tab shell. Emergency is opened from the red link on Home. Back arrows are 44 px round white buttons over hero images (Doctor/Lab/Hospital) or plain 44 px arrows in an app bar (others).

## 6. Screens (build each from its artboard; behaviours below)
1. **Splash** — green background, three faint concentric circles (560/400/250 px), white 104-px rounded logo tile with shadow, "Fauridoc", English tagline, Urdu tagline, footer "Made for Khyber Pakhtunkhwa". Auto-advance after ~1.6 s.
2. **Onboarding** — 3 SVG illustration slides, title (30/800) + body, dots, **Next / Get started**, **Skip** (top right). Saves "seen" flag.
3. **Home (EN + Urdu RTL)** — city pill, language toggle (switches whole app locale + RTL instantly), headline, red emergency link row → Emergency, search bar → Search, specialty chips (horizontal, selected = green fill) filtering the list, **lime featured card** (top-rated of the filtered list: rating pill, white initials avatar, verified tick, status dot + text, 2×2 working-hour chips, **View profile** + dark **Call** buttons, clinic address line) then **pastel list cards** (white avatar, rating pill, white stat strip Fee/Distance/Reviews with 1-px dividers, status line, address line, **View profile** + **Call now**). Empty state with "Add a doctor" link. Sort by rating; distance from `geolocator` (fallback to city centre).
4. **Search** — segmented Doctors / Lab Tests / Hospitals; query box; Doctors (same pastel cards, sort + 5 km filter), Lab Tests (test chips; labs sorted by price with "Cheapest" tag), Hospitals list. Result taps open Doctor / Lab / Hospital screens.
5. **Doctor** — 196-px tinted hero with big initials, back + save buttons; name + verified tick, specialty, qualification, rating row; "Currently: Open — Sees patients until 8 PM today · Updated by doctor" status card (live from `status`/leave); fee and parking tiles; clinic photos strip with captions; info rows; languages chips; working-hours table with today highlighted; "What patients say" with one review and **See all 186** → Reviews; sticky bottom bar **Call / WhatsApp / Map** (increment counters).
6. **Reviews** — header with doctor name, big 4.9 + stars + count, rating-bars breakdown, "Rate your visit" 5-star input + textarea + **Post review** (login required → prompt login), then the "You reviewed Dr. Sana" state with **Edit / Delete** (one review per person), "All reviews · Newest" list with initials avatars.
7. **Lab** — 150-px tinted hero, name + tick, subtitle, rating, "Open until 10 PM", info rows, "Tests and prices · 42 tests" with search field and category chips, test rows (name, note, price), **Show all 42 tests**, price disclaimer, bottom bar **Call / View on Map**.
8. **Hospital** — red-tinted hero, name + tick, rating, "Emergency 24/7" badge, emergency-number card, info rows, department chips, location row → Map, bottom bar **Call emergency / Directions**.
9. **Emergency** — "Nearest emergency" card with map thumbnail (SVG), hospital, address, "2.1 km · about 6 min", "Emergency open 24/7", department chips, **Call emergency**, **Directions**, **Share location** (share sheet with a maps link), the 1122 card ("Need an ambulance? Call Rescue 1122" + disclaimer that Fauridoc does not send ambulances), "Other emergency wards nearby" list. Nearest = by device location.
10. **Map** — full-screen map, top search/filter row with chips (All / Doctors / Labs / Hospitals), city pill, coloured circular pins (white 3-px border, shadow; selected pin grows), tapping a pin shows the bottom mini-card (name, "Type · dist km", rating, status line, chevron → profile). Bottom tab bar visible.
11. **Community** — title + **Ask** pill, filter chips, pinned post ("Pinned by Fauridoc team"), post cards with vote column (up/down + score), title, topic tags, top reply with **Doctor** badge, meta "by · when · N replies". **Ask the community** bottom sheet: question text, City chips (Mardan/Peshawar/Swabi/More), Specialty chips (Dermatologist/Pediatrician/Lab tests…), **Post question** (login required).
12. **Profile** — guest state ("You are browsing as a guest…", mobile number + **Send code** → OTP flow) and logged-in state (avatar initials, name, number · city), My listings (status chips Approved / Pending approval, **Add new** → Register, tap a doctor listing → Stats), Language (English / اردو), Admin entry (only for admin role), **Log out**, footer "Fauridoc 1.0 · No ads, no data selling".
13. **Register (Add a listing)** — type tabs Doctor / Lab / Hospital; fields, labels uppercase 12/700 +0.06em exactly as `.lbl`, inputs 50 px `.fld`. Doctor: photos (main + 3), name, specialization picker, qualification, hospital/clinic, city, full address + **Pin the exact location on the map**, phone, WhatsApp, languages chips, working-day chips + opens/closes, fee, parking switch. Lab: tests with **Add another test** rows, working hours. Hospital: emergency 24/7 switch, emergency number, departments chips, visiting hours. Notice "Your listing stays hidden until our team checks it…", **Submit for approval** → writes `approval: pending` and shows success.
14. **Stats (My dashboard)** — green hero card "This week · 43 profile views", tiles (12 WhatsApp clicks, 9 Calls, 17 Map opens), "Views by day" bar chart Mon–Sun (custom painted), **Leave mode** switch + "On leave until" date picker + live "How patients see it" preview, rating row, **Edit my profile**. All values from the doctor's counters.
15. **Admin** — back bar "Admin panel · Live counts", 3-column count tiles, "Pending approval" cards with **Approve / Reject** and **Undo**, "Needs a look" (flagged review → **Delete**; useful post → **Pin**), "Manage" rows. Writes `approval`, deletes reviews, pins posts.
16. Splash/launcher/notification icons and the Urdu Home are covered above.

## 7. Behaviour details
- Language switch is global and persisted; Urdu flips layout (`Directionality`), mirrors icons that point, and uses Noto Nastaliq Urdu with the spacing from `HomeUrdu.dc.html`. Every visible string needs an English and Urdu value (ARB files via `flutter gen-l10n`).
- Calls use `tel:`; WhatsApp uses `https://wa.me/92…` (strip leading 0); directions open Google Maps with the lat/lng.
- Open/closed status is computed from working hours and overridden by Leave mode; show "Open now · until 8 PM", "Closed · opens 5 PM", "On leave till 20 Oct".
- Auth only when needed (review, post, add listing, dashboard). Guests browse everything else.
- Offline: cache the approved directory in Firestore persistence; show last data with a small "Offline" note.
- Accessibility: semantic labels on icon buttons (`aria-label`s in the files), 44-px targets, contrast as designed.

## 8. Project structure
```
lib/
  main.dart  app.dart  router.dart
  design/ tokens.dart  widgets/…
  l10n/ app_en.arb  app_ur.arb
  data/ models/  repository.dart  mock_repository.dart  firestore_repository.dart  seed.dart
  features/ splash onboarding home search doctor reviews lab hospital emergency map community profile register stats admin
assets/ fonts/ svg/
design/            (the supplied HTML artboards — keep for reference)
firestore.rules  storage.rules  README.md
.github/workflows/build-apk.yml
```

## 9. GitHub build (mandatory)
`.github/workflows/build-apk.yml`, triggered on push to `main` and manual dispatch, `ubuntu-latest`: checkout → `actions/setup-java@v4` (temurin 17) → `subosito/flutter-action@v2` (stable, cache) → if `android/` is missing run `flutter create --platforms=android --org com.afzal --project-name fauridoc .` and patch the manifest (INTERNET, ACCESS_FINE/COARSE_LOCATION, CAMERA/READ_MEDIA_IMAGES as needed, `<queries>` for tel/https/WhatsApp, Maps API key meta-data) → write `google-services.json` and the Maps key from secrets `GOOGLE_SERVICES_JSON` and `MAPS_API_KEY` **only if present** (otherwise build with the mock repository) → `flutter pub get` → `flutter gen-l10n` → `flutter analyze` (must pass) → `flutter build apk --release --split-per-abi` → upload artifacts. Optional signing from secrets `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`, falling back to debug signing. Also build an `appbundle`.

## 10. Quality bar and delivery
1. Work screen by screen in this order: tokens + shared widgets → Splash/Onboarding → Home (EN/UR) → Search → Doctor → Lab → Hospital → Emergency → Map → Reviews → Community → Profile → Register → Stats → Admin → Firebase wiring.
2. After each screen, compare it against its artboard (size, spacing, colours, copy, icons). Fix differences before moving on.
3. Add widget golden tests for Home (EN + UR), Doctor and Search at 390×844 to guard the look.
4. Code must be null-safe, lint-clean, with no TODO stubs in shipped paths. The app must run end-to-end on the mock repository with zero configuration.
5. Deliver the full repo ready to push to GitHub, a README (setup of Firebase project, secrets list, how to download the APK from Actions), and a short list of anything not matched exactly.
