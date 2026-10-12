# Seed-data conversion report — Fauridoc real KP research → JSON

Generated 2026-10-12 from the three research files in `seed_data/` (not modified).
Assets written to `assets/seed_data/`; every file validated with `python3 -m json.tool`.

## Counts written
| File | Records |
|---|---|
| `doctors.json` | **189** (d001–d189, entry order) |
| `labs.json` | **14** (l001–l014) |
| `hospitals.json` | **21** (h001–h021, research order: 12 govt + 9 private) |
| `config.json` | 41 specialties, 41 Urdu labels, 12 cities |

- Doctor city coverage: Peshawar 67, Mardan 35, Abbottabad 24, Kohat 12, Nowshera 10, Swat 10, Swabi 8, Bannu 6, Haripur 6, Charsadda 4, D.I. Khan 4, Mansehra 3.
- Doctors with a published fee: 80/189. Doctors with hours text: 105/189.
- Automated duplicate-name scan (prefix-normalized): no duplicates found.

## Merges performed (2)
1. **Dr. Tahir Mehmood Khattak** (entry 15) — single record `d015`, primary city Peshawar, `alsoPractices: ["Kohat"]`; Kohat clinic moved to `sourceNote`.
2. **Dr. Kanza Hamid** (entry 57) — single record `d057`, primary city Abbottabad, `alsoPractices: ["Mardan"]`, `verified: false`, note "thin Mardan listing, likely same doctor".

Multi-doctor joint listings kept as ONE record each (no invented split): d146 (Salman Khan + Adil Hamayun), d164 (Sadique Ahmad Orakzai + Ayesha Naseem), d182 (Taran Kumar + Imy Kumar), d137 (Jehangir Khan + Tooba Fayaz), d079 (Shehbaz Ali + Waleed Bilal) — co-doctors named in `sourceNote`.

## Records with verified = false
**Doctors (19):** d046 Seema Nazir Khattak · d051 Arshad Khan · d057 Kanza Hamid · d058 Osama Rashid Qazi · d063 Muazzam Ali Shehzad · d087 Hikmatullah · d091 Gul Badshah · d092 Qaiser Khan · d094 Shehreyar Khan · d095 Arifullah · d107 Ibrahim Ahmad Yousafzai · d126 Rameez Khan · d127 Abdus Subhan · d128 Sameed Khan · d166 Ishtiaq Ahmad · d167 Asghar Ali · d168 Muhammad Zarar Niazi · d169 Salman Malik · d180 Sohail Khan.
Reasons: thin records, template/helpline phones, or "verify before publishing" flags in the research.
**Hospitals (1):** h016 Health Net Hospital — no official website; aggregator-only data, lower confidence.
**Labs:** none.

## phoneKind breakdown
- Doctors: direct 75 · none 89 · exchange 18 · unverified 7 (phone `""` in all non-direct cases).
- Labs: direct 13 · none 1 (govt/MTI collection).
- Hospitals: `phone` always digits-only; `emergencyPhone` set ONLY where a genuinely separate published line exists — h006 Ayub Teaching Hospital `09929311155` (officially advertised for emergencies) and h017 Al-Khidmat `1023` (24/7 ambulance line). All other hospitals: `emergencyPhone: ""`.
- `emergency247: true` for 10 hospitals with official 24/7 claims (LRH, KTH, HMC, ATH, DHQ Kohat, DHQ Bannu, Northwest General, RMI, Prime Teaching, Al-Khidmat); false elsewhere with the reason in `sourceNote` (third-party claim only: Mercy, Kuwait, Health Net; unknown: the rest).

## Price conflicts flagged (in sourceNote, never silently resolved)
- **Chughtai Lab:** CBC 400 (hamariweb 2026) vs 680 (page header) vs 1300 (alllabtests) vs 800–1500 (searchit); HbA1c 1000 vs 2100; LFT 1050 vs 1950; RFT stored as 1440 with range 1440–1800 noted. Primary values used = hamariweb 2026 rate list.
- **Excel Labs:** hours conflict — hamariweb "Mon–Sat 8 AM–1 AM, Sun closed" vs oladoc "24/7".
- Fee ranges stored as the lower bound with the full range in `sourceNote` (e.g. d037 Rs. 1,500–3,000 → fee 1500).
- IDC / Aga Khan / Shaukat Khanum / Nayab / Citi / govt labs: no public per-test prices → `tests: []`.

## Specialty normalization (canonical list from the research)
Applied mappings include: Gynaecologist→Gynecologist / Obstetrician · Skin Specialist/Aesthetic/Cosmetologist→Dermatologist · Child Specialist→Pediatrician (Child Specialist) · Eye Specialist→Eye Specialist (Ophthalmologist) · ENT Consultant/Surgeon→ENT Specialist · Medical Specialist/Diabetologist (d023)→Endocrinologist / Diabetologist · General/Laparoscopic Surgeon (d020/d090)→General Surgeon (noted) · Gastroenterologist/Hepatologist (d037)→Gastroenterologist (noted) · Anesthesiologist (d169)→Anesthetist / Pain Specialist. Original labels preserved in `sourceNote` wherever the mapping was non-obvious.

## Judgment calls (deviations / additions vs. the task spec)
1. **Config cities = 12, not 10.** The task's list omitted Mansehra (3 doctors) and Haripur (6 doctors); both added so every doctor's city exists in the filter list.
2. **Lab split (14):** Chughtai × 6 KP cities (each carries the chain price list + city branch phones) + IDC Peshawar + Dr. Essa Peshawar + Excel Peshawar + Aga Khan Mardan + Shaukat Khanum Mardan + Nayab Mardan + Citi Lab Kohat + Govt/MTI hospital labs (city `"Multiple"`). Other branches noted in `sourceNote`.
3. **h014 RMI city** normalized to Peshawar (was "Hayatabad") for filter consistency; Hayatabad kept in the address.
4. **Urdu specialty labels are drafts** in spoken style (e.g. Cardiologist → دل کا ڈاکٹر); review by a native speaker before release.
5. Clinic-only entries (no named doctor, e.g. d072/d073, d142–d145, d155, d158, d160–d163, d170, d172–d176, d181, d185, d186) are included with the clinic name as `name` and "doctor name not public" in `sourceNote`, per the approved lists.
6. Correction from the expanded file applied: d024 Adil Afridi phone `03145767187` (direct). Excluded entries were not added.
