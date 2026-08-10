# Plates — App Store submission package

Everything below is ready to copy-paste into App Store Connect. Character
limits are noted where Apple enforces them; every field here is within limit.

---

## 1. One-time setup (only you can do these)

1. **App Store Connect → My Apps → “+” → New App**
   - Platform: iOS
   - Name: see §2 (must be unique on the App Store)
   - Primary language: English (U.S.)
   - Bundle ID: `com.dxzhang.plates` (already registered to team LBVWATHXH4 by the device builds)
   - SKU: `plates-001`
2. **Agreements, Tax, and Banking → Paid Applications** — must be Active
   before the $6.99 in-app purchase can be sold (bank account + tax forms).
3. **Privacy policy URL** — App Review requires one. `docs/PRIVACY.md` in the
   repo is ready to host. Easiest paths:
   - Make the GitHub repo public and use
     `https://github.com/Dzhang921/PlatesApp/blob/main/docs/PRIVACY.md`, or
   - Enable GitHub Pages on the repo and use the pages URL.
4. **Support URL** — same options; the repo’s Issues page works:
   `https://github.com/Dzhang921/PlatesApp/issues`

---

## 2. App Information

| Field | Value |
|---|---|
| Name (30 max) | `Plates — Restaurant Passport` *(28 — if taken, try `Plates: Collect Restaurants`)* |
| Subtitle (30 max) | `Scan receipts, collect places` *(29)* |
| Primary category | Food & Drink |
| Secondary category | Travel |
| Content rights | Does not contain third-party content |
| Age rating | 4+ (answer “None/No” to every questionnaire item) |
| Copyright | `© 2026 Jason Zhang` |

## 3. Pricing

- **App price:** Free
- **In-App Purchase** (create under Features → In-App Purchases):
  - Type: **Non-Consumable**
  - Reference name: `Plates Pro`
  - Product ID: `com.dxzhang.plates.pro`  ← must match exactly
  - Price: **$6.99** (Tier: pick the $6.99 tier)
  - Display name (30 max): `Plates Pro`
  - Description (45 max): `Unlimited plates, forever. One purchase.` *(40)*
  - Review screenshot: use `docs/appstore/07-paywall.png`
  - Availability: all countries

## 4. Promotional text (170 max)

```
Every restaurant you eat at becomes part of your collection. Scan the receipt, watch your world globe light up, and count the Michelin stars you've earned at the table.
```
*(166 characters)*

## 5. Description (4000 max)

```
Plates turns eating out into a collection.

Scan the receipt at the table — or upload a photo of it later — and Plates reads the restaurant, the date, the total, even the dishes, entirely on your iPhone. The restaurant becomes a plate in your collection, and a new light appears on your world globe.

THE GLOBE
Your dining life on a dark world map, glowing point by point. Cities fill in, countries light up, and the map slowly becomes a picture of everywhere you've ever eaten.

MICHELIN STARS, YOURS NOW
Eat at a starred restaurant and its stars join your lifetime count. Plates ships with the complete list of Michelin-starred and Bib Gourmand restaurants worldwide — collected offline, matched automatically when you scan.

KNOW YOUR TASTE
Plates learns what you actually love: your top cuisines, your favorite dish, what a meal usually costs you, how adventurous your palate really is. Heading somewhere new? Discover recommends restaurants in any city based on your own history — with reasons written on your device, for your taste alone.

YOUR PASSPORT
Badges for milestones — your first plate, your first star, ten cuisines, ten countries. Monthly streaks for trying new places. A shareable passport card with your photo, your stats, and your proudest badges, made for sending to friends.

THE NUMBERS
Annual spend on eating out, month by month. Cuisine breakdowns. Your most-visited and most-loved. Multi-currency, converted to your home currency automatically — eat in Tokyo, spend in yen, see it in dollars.

PRIVATE BY DESIGN
No account. No cloud. No tracking. Receipts are read by on-device intelligence and never leave your iPhone. Your dining history is yours.

FREE TO START
Collect your first 10 restaurants free. One single purchase unlocks unlimited plates forever — no subscription.

Every meal, collected.
```

## 6. Keywords (100 max, comma-separated)

```
restaurant,michelin,foodie,receipt,scanner,food,diary,dining,tracker,map,travel,collect,passport
```
*(96 characters)*

## 7. App Privacy (Data Collection)

Answer: **“No, we do not collect data from this app.”**

Everything is processed and stored on-device. There are no accounts, no
analytics, no third-party SDKs, and nothing is transmitted to the developer.
(Location is used only to rank nearby restaurant matches and is never sent
anywhere; purchases are processed by Apple.) Result: the App Privacy label
shows **“Data Not Collected.”**

## 8. App Review Information

- Contact: your name, phone, and email (jolenewjy@gmail.com or preferred)
- Sign-in required: **No**
- Notes for the reviewer:

```
Plates is a restaurant-collection app: the user scans a restaurant receipt (or uploads a photo of one), on-device OCR extracts the merchant, date, and total, and the app matches it to the real restaurant via Apple Maps. No account is needed and no data leaves the device.

To test quickly: tap the gold + button, then either scan any restaurant receipt, choose "From Photos", or tap "Enter manually" and type a restaurant name — the search field matches real restaurants worldwide. Confirm to add it to the collection; the Globe tab shows it light up on the world map.

Michelin star data is a bundled offline dataset; no third-party API is called. The one-time "Plates Pro" purchase (com.dxzhang.plates.pro) removes the 10-restaurant free limit and can be tested with a sandbox account after adding 10 restaurants.
```

## 9. Screenshots

Upload the 6.9-inch set from `docs/appstore/` (1320×2868, iPhone 17 Pro Max),
in this order:

1. `01-globe.png` — the lit world globe
2. `02-confirm.png` — receipt scanned into a confirm card
3. `03-collection.png` — the plate grid
4. `04-discover.png` — taste-based recommendations
5. `05-stats.png` — annual spend dashboard
6. `06-passport.png` — badges and streaks

Apple only requires the 6.9-inch set; smaller sizes scale down automatically.
(`07-paywall.png` is NOT an App Store screenshot — it is for the IAP review
field in §3.)

## 10. Build & upload

In Xcode (simplest):
1. Open `Plates.xcodeproj`, select the **Plates** scheme and **Any iOS Device (arm64)**.
2. Product → **Archive**.
3. In the Organizer: **Distribute App → App Store Connect → Upload** (defaults are fine; signing is automatic).
4. In App Store Connect → your app → the 1.0 version page → **Build** → select the uploaded build (it appears after ~15 min of processing).

Notes already handled in the project: export-compliance key is set
(`ITSAppUsesNonExemptEncryption = NO`, so no encryption questionnaire),
version is 1.0 (build 1), the App Group + widget extension are embedded, and
all debug/sample-data hooks are DEBUG-only — they do not exist in the
archived Release build.

## 11. Submit

On the version page: add screenshots, paste §4–§6, set the privacy answers
(§7), attach the build, add the IAP to the version, fill review info (§8),
then **Add for Review → Submit**. First reviews typically take 1–3 days.
