# Gym Manager (Flutter + Local Storage)

No backend, no cloud account required. All data lives as JSON files in
the app's private local storage on the device. Use **Export Backup** /
**Import Backup** (Dashboard menu) to move data between devices or keep
a manual backup — the exported file is a single JSON you can save,
email, or share via WhatsApp.

## Setup steps

1. Run `flutter pub get` in this folder.
2. Run `flutter run`.

That's it — no Google Cloud Console, no OAuth, no SHA-1 setup needed
for storage. (Local notifications still need the desugaring config
below for Android.)

## How storage works

- On first launch, `LocalStorageService.init()` creates a
  `GymManagerApp` folder inside the app's private documents directory
  (`getApplicationDocumentsDirectory()`).
- Inside that folder: `gym_profile.json`, `plans.json`, `members.json`,
  `payments.json` — each created on first access if missing.
- All reads/writes go through `GymRepository`, which wraps
  `LocalStorageService`.
- This data is private to the app — it's not visible in the phone's
  general file browser and is deleted if the app is uninstalled, unless
  you've exported a backup first.

## Export / Import (backup & device transfer)

- **Export Backup** (Dashboard → menu): bundles gym profile, plans,
  members, and payments into one timestamped JSON file and opens the
  native share sheet — save it to Downloads, Google Drive, email it to
  yourself, whatever you prefer.
- **Import Backup**: pick a previously exported JSON file — this
  **overwrites all current data**, so it's meant for restoring on a new
  device or rolling back, not merging.
- There's no automatic/scheduled backup — it's a manual action the gym
  owner triggers periodically or before switching phones.

## Known limitations (by design, per current scope)

- Single device = single copy of data. No real-time sync between
  devices; Export/Import is a manual, point-in-time transfer.
- Local notifications only — reminders are scheduled per-device at the
  time a member is added/renewed. If the app is uninstalled or the
  device changes, reminders won't fire until the data is re-imported
  and members are re-scanned (not automatic on import currently).
- No attendance, branches, expenses, photo/ID upload, roles, or referral
  codes — intentionally out of scope for this build.

## First-time Android/iOS project setup

This repo only contains the `lib/` Dart source + `pubspec.yaml` — the
native Android/iOS project folders aren't generated yet. Do this once:

```bash
cd gym_manager
flutter create . --org com.yourcompany --project-name gym_manager
flutter pub get
```

This scaffolds `android/`, `ios/`, etc. around your existing `lib/` code
without overwriting it. After that, **replace the entire contents**
(don't merge partial blocks — that's caused syntax errors before) of
`android/app/build.gradle.kts` with
`android/build_gradle_kts_COMPLETE_FILE.txt`, and
`android/app/proguard-rules.pro` with
`android/proguard_rules_COMPLETE_FILE.txt` (create it if it doesn't
exist yet). Both are complete, ready-to-use files — just copy their
content in wholesale.

## Running the app

```bash
flutter doctor          # fix any issues first
flutter devices         # confirm an emulator/device is attached
flutter run
```

## Building for Android

Debug APK (quick test, no signing needed):
```bash
flutter build apk --debug
```

Release APK (signed, for direct install):
```bash
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk
```

Release AAB (for Play Store upload):
```bash
flutter build appbundle --release
# → build/app/outputs/bundle/release/app-release.aab
```

**Signing setup (required for release builds):**
1. `keytool -genkey -v -keystore ~/gym-manager-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias gymmanager`
2. Create `android/key.properties`:
   ```
   storePassword=<your password>
   keyPassword=<your password>
   keyAlias=gymmanager
   storeFile=/absolute/path/to/gym-manager-key.jks
   ```
3. Replace the full contents of `android/app/build.gradle.kts` with
   `android/build_gradle_kts_COMPLETE_FILE.txt` (already includes the
   core library desugaring config required by
   `flutter_local_notifications`, signing config, and minification).
   Also replace `android/app/proguard-rules.pro` with
   `android/proguard_rules_COMPLETE_FILE.txt` — without this,
   minification in release builds can silently break scheduled
   reminder notifications even though debug builds work fine.
4. **Never commit `key.properties` or the `.jks` file** — add both to `.gitignore`.

## App icon + splash screen

Your logo is already in place at `assets/icon/icon.png`, with a padded
version at `assets/icon/icon_adaptive_foreground.png` (used for Android's
adaptive icon mask so the artwork doesn't get clipped by the circular/
squircle crop) and a scaled copy at `assets/splash/splash.png`.

To regenerate with a different logo later:
1. Replace `assets/icon/icon.png` (square, ≥1024×1024, transparent bg).
2. Re-create `icon_adaptive_foreground.png` with extra padding — Android
   only guarantees the center ~66% of the canvas is visible, so scale
   your artwork down to fit within that safe zone on a transparent
   1024×1024 canvas before saving.
3. Replace `assets/splash/splash.png` (a smaller, centered version).
4. Generate the icon:
   ```bash
   dart run flutter_launcher_icons
   ```
5. Generate the splash screen:
   ```bash
   dart run flutter_native_splash:create
   ```
6. Rebuild the app — icon and splash are now baked into the native
   Android/iOS projects. Re-run both commands any time you change the
   source images.

## Next steps not yet scaffolded

- Local caching optimizations (data is already fully local, but no
  in-memory cache layer yet — every screen re-reads from disk)
- Auto re-scheduling reminders for all members after an import

## WhatsApp / SMS reminders — Android manifest setup

On Android 11+ (API 30+), `url_launcher`'s app-detection needs a
`<queries>` block declared, or it will silently fail to detect WhatsApp/
SMS even when installed. Merge the contents of
`android/AndroidManifest_queries_snippet.txt` into
`android/app/src/main/AndroidManifest.xml` (inside `<manifest>`, as a
sibling of `<application>`).

**Important limitation**: there is no backend or paid messaging API
(WhatsApp Business API / SMS gateway) wired up, so "sending" a reminder
always opens WhatsApp or the SMS app with the message pre-filled — the
gym owner still taps Send themselves for each member. True automatic
sending (no tap required) would need a paid backend integration. The
on-device local notification is the only fully-automatic reminder, and
it notifies the gym owner, not the member — see `notification_service.dart`.

## New features summary (latest update)

- **Theming**: `lib/theme/app_theme.dart` — Material 3 theme with a
  custom amber/charcoal palette matching the app logo, applied globally.
- **Duplicate member bug fix**: `addMember()` now validates the mobile
  number is unique *before* writing anything, and notification-scheduling
  failures no longer surface as a false "add failed" error after the
  member was actually saved successfully.
- **Side navigation drawer** replaces the old 3-dot menu — swipe from
  the left edge or tap the hamburger icon.
- **Search + date filter** on the Dashboard member list — search by
  name/mobile/member ID, date range defaults to the current month
  (based on each member's join/renewal date), clearable via the filter-off icon.
- **Analytics & Reports** screen (drawer → Analytics & Reports):
  revenue summary, 6-month revenue trend chart, plan distribution pie
  chart, payment mode breakdown, membership status bars.
- **Send Reminders** screen (drawer → Send Reminders): lists
  expiring/expired members, send individually via WhatsApp/SMS icon
  buttons, or select several and step through a bulk-send queue.

## Member photos + Edit/Delete (latest update)

- **Photo capture**: tap the circular avatar on Add Member or Edit
  Member to take a photo or pick from gallery. Photos are stored
  locally in `member_photos/` inside the app's private storage folder
  (included automatically in Export Backup as file paths — note the
  actual image files are **not** bundled into the exported JSON backup,
  only the data records; photos don't currently transfer via
  Export/Import, only structured data does).
- **Member Detail screen**: tapping a member on the Dashboard now opens
  a detail view (photo, info, payment history) instead of jumping
  straight to Renew. From here: Renew Plan, Edit (top-right pencil),
  Delete (top-right trash, with confirmation), and quick SMS/WhatsApp
  reminder buttons.
- **Edit Member**: change name, mobile number, or photo. Plan/expiry/
  payment changes stay in the Renew Plan flow, since those are tied to
  billing logic.
- **Delete Member**: removes the member record, cancels their scheduled
  reminder notification, and deletes their stored photo file.
- Camera/gallery permissions: merge the additions in
  `android/AndroidManifest_queries_snippet.txt` (camera permission
  block) into your `AndroidManifest.xml`.

## Latest update: custom dates/IDs, photo cropping, dashboard filters, gym logo, WhatsApp fix

- **Add Member**: now has a custom **Member ID** field (leave blank to
  auto-generate, or type your own — validated for uniqueness), a
  **Join/Payment Date** picker (defaults to today, backdate/postdate as
  needed — this also drives the expiry date calculation), and a payment
  mode selector (Cash/UPI/Card/Other).
- **Photo cropping**: `image_cropper` is now wired into the photo picker
  (Add Member, Edit Member, Gym Profile logo) — square crop after taking
  or picking a photo, before saving.
- **Renew Plan**: added a **Renewal Date** picker (defaults to today,
  editable) — the new expiry date is calculated from whichever is later:
  the member's current expiry, or this renewal date.
- **Dashboard quick filters**: the Paid/Unpaid/Active/Expiring Soon/
  Expired count cards are now tappable — tapping one filters the member
  list below to just that group (shown as a removable chip next to
  "Members"). Tap the same card again, or the chip's × , to clear it.
- **Gym Profile logo**: added a photo picker (same crop/camera/gallery
  flow as member photos) on the Gym Profile screen. The logo now shows
  in the Dashboard's side-drawer header instead of the generic icon.
- **WhatsApp reminders — fixed**: previously used `canLaunchUrl()` +
  `wa.me` which fails silently in two ways: (1) `canLaunchUrl` requires
  Android 11+ package-visibility `<queries>` declarations that weren't
  fully in place, and (2) mobile numbers without a country code (e.g. a
  plain 10-digit Indian number) don't resolve correctly in WhatsApp's
  URL scheme. Now: numbers without a leading `+` get `+91` prepended
  automatically (edit `ReminderService.defaultCountryCode` if you're
  outside India), and sending tries the native `whatsapp://send` scheme
  first, falling back to `wa.me` then `api.whatsapp.com` if needed —
  and skips `canLaunchUrl` entirely in favor of directly attempting
  `launchUrl` with error handling, since `canLaunchUrl` was the main
  source of false negatives. **Also add the updated**
  `android/AndroidManifest_queries_snippet.txt` **contents** — it now
  includes a `whatsapp://` scheme query in addition to the existing
  `https` and `sms` ones.
- **Customizable reminder message**: tap the pencil icon (top-right) on
  the Send Reminders screen to edit the message template. Supports
  placeholder tokens — tap a chip to insert at cursor position:
  - `{{MEMBERNAME}}`, `{{GYMNAME}}`, `{{EXPIRYDATE}}`, `{{DAYSLEFT}}`,
    `{{PLANNAME}}`, `{{AMOUNT}}`
  - Default template:
    ```
    Hi {{MEMBERNAME}}, this is a reminder that your membership at {{GYMNAME}} expires on {{EXPIRYDATE}} (in {{DAYSLEFT}} days). kindly renew your membership 
    Thank you🙂!
    Stay Strong 💪🏻
    ```
  - Live preview with sample data shown while editing. "Reset" restores
    the default. Saved to local storage (`reminder_template.txt`),
    applies to both individual and bulk sends, WhatsApp and SMS alike.
