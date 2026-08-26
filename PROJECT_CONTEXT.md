# Gym Manager / Atlas Log — Project Context (Handoff Document)

This document provides complete context on the **Atlas Log** Flutter app for any human developer or AI assistant picking up this project. It reflects the initial architecture, subsequent bug fixes, recent Google Play Store compliance actions, and active deployment status.

---

## 1. What this app is

An offline-first gym membership management app for Android (developed on Windows; iOS explicitly out of scope). Designed for solo gym owners and fitness studio operators to manage members, membership plans, payments/fees, and renewal reminders locally on their device with **zero recurring infrastructure or server costs**.

* **Package name:** `com.atlas_log.atlas_log`
* **Public App Name:** Atlas Log: Gym Management
* **Internal Working Name:** Gym Manager
* **Target Audience:** Gym owners, personal trainers, and studio operators.

---

## 2. Tech stack

* **Framework:** Flutter (Dart), Material 3
* **State Management:** Riverpod (`flutter_riverpod`)
* **Storage (v1):** Local JSON files on-device via `LocalStorageService` (no backend required)
* **Storage (Planned v2 Evolution):** Hybrid model — Firebase Firestore (Spark Plan) for lightweight metadata sync + Google Drive API (`appDataFolder`) or local device storage for member media/backups
* **Charts:** `fl_chart`
* **Notifications:** `flutter_local_notifications` (on-device scheduled notifications)
* **Photos:** `image_picker` (utilizing Android System Photo Picker) + `image_cropper`
* **Messaging:** `url_launcher` (direct intent triggers to WhatsApp / SMS; no programmatic bulk APIs)
* **Data Backup:** `file_picker` + `share_plus` (JSON export/import)

---

## 3. Architecture & Release Strategy

### Phase 1: Pure Offline-First (Current Production/Testing Target — v1.0.0+2)
* **Database:** `LocalStorageService` writes individual JSON files (`gym_profile.json`, `plans.json`, `members.json`, `payments.json`, `member_photos/`) in the application's private documents directory under `GymManagerApp/`.
* **Zero Backend Costs:** Completely eliminates backend maintenance, API keys, or cloud outage risks.
* **Manual Data Portability:** Users can generate and restore timestamped `.json` database backups using system share sheets and file pickers.

### Phase 2: Planned Hybrid Cloud Sync (Target: v2 Post-Launch)
* **Real-Time Data (Firestore):** Integration with Firebase Cloud Firestore (Spark Free Tier) for document-level CRUD sync across multiple devices (50k daily reads / 20k daily writes, permanently free, zero credit card required).
* **Media & Snapshots (Google Drive):** Member profile images and full database snapshots are stored directly within the user's private Google Drive `appDataFolder`, keeping developer cloud storage costs at **$0/month forever**.

### State & Repository Architecture
* **State Wiring:** All application services are exposed via Riverpod providers in `lib/services/providers.dart`.
* **Repository Pattern:** UI screens interact exclusively with `GymRepository` (`lib/services/gym_repository.dart`) for business logic (duplicate validation, expiry calculations, dashboard metrics aggregation, and image path lifecycles).

---

## 4. Google Play Console Compliance & Release History

### Permission Compliance (`READ_MEDIA_IMAGES` Removal)
* **Issue:** Google Play review rejected explicit declarations for `READ_MEDIA_IMAGES` / `READ_EXTERNAL_STORAGE` because profile photo picking is classed as "infrequent access."
* **Fix Applied:** Enforced Android's native system Photo Picker via `image_picker: ^1.1.2` and added explicit manifest node removals in `android/app/src/main/AndroidManifest.xml`:
  ```xml
  <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" tools:node="remove" />
  <uses-permission android:name="android.permission.READ_MEDIA_VIDEO" tools:node="remove" />
  <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" tools:node="remove" />
  ```

### Release Versioning
* `version: 1.0.0+1` — Initial test bundle (superseded due to version code reuse and permission form requirement).
* `version: 1.0.0+2` — Current clean bundle uploaded to Play Console with incremented `versionCode: 2`.

### Store Listing Metadata Update
Resolved automated Play Store rejection regarding feature clarity:
* **App Name:** `Atlas Log: Gym Management`
* **Short Description:** `Offline-first member management, fee tracking, and plan organizer for gyms.`
* **Full Description:** Fully structured listing detailing Member Management, Subscriptions, Fee Tracking, Renewal Reminders, Offline Privacy, and Backup/Restore.

---

## 5. Navigation Structure & Key Screens

```
AppInitScreen (splash/init)
  → GymProfileScreen (first run only, if no gym_profile.json exists)
      → PlanManagementScreen (first run, must add ≥1 plan)
          → HomeShellScreen
  → HomeShellScreen (returning users)

HomeShellScreen (bottom nav + drawer)
  ├── Tab 0: Dashboard (DashboardScreen, embedded=true)
  ├── Tab 1: Members (MembersTabScreen)
  ├── Tab 2: Reports (AnalyticsScreen, embedded=true)
  └── Tab 3: Settings (SettingsTabScreen)

  Drawer:
    Dashboard, Analytics & Reports, Send Reminders, Manage Plans,
    Gym Profile, Settings
```

* **Embedded Chrome Pattern:** `DashboardScreen` and `AnalyticsScreen` accept `embedded: bool` (default `false`). When `true`, their internal `Scaffold`/`AppBar` is omitted so the root `HomeShellScreen` manages navigation chroming.
* **State Refreshing:** `HomeShellScreen` refreshes child tabs upon returning from modal actions by bumping an integer `ValueKey`.

---

## 6. Full Feature List

* **Gym Profile:** Name, address, contact number, and custom cropped logo (rendered in drawer header).
* **Plan Management:** Create, Read, Update, Delete membership plans (plan name, month duration, fee amount).
* **Interactive Dashboard:**
  * Status metric cards: Total, Paid, Unpaid, Active, Expiring Soon, Expired.
  * Tappable count cards that dynamically filter the active member list.
  * Search bar (matches name, phone number, custom member ID).
  * Date range filter (defaults to current month; automatically bypassed when status card filter is active to prevent hiding long-term memberships).
* **Member CRUD:**
  * Auto-generated (`GM0001`) or custom unique Member IDs.
  * Backdated or custom join/payment dates.
  * Payment modes (Cash, UPI, Card, Other).
  * Profile photo capture with crop flow.
* **Plan Renewal Flow:** Extends expiry dates dynamically from whichever date is latest (current expiry vs. selected renewal date) and logs billing transaction history.
* **Reminder Dispatcher:**
  * Direct one-tap WhatsApp / SMS intent launching with pre-filled message templates.
  * Bulk queue runner to step through expiring members sequentially.
  * Template placeholders supported: `{{MEMBERNAME}}`, `{{GYMNAME}}`, `{{EXPIRYDATE}}`, `{{DAYSLEFT}}`, `{{PLANNAME}}`, `{{AMOUNT}}`.
* **Analytics & Reports:** Revenue summaries (total collected, monthly revenue, pending dues), 6-month bar charts, plan distribution pie charts, and payment mode breakdowns.
* **Branded Theming:** Dark and light theme modes with custom gradient styling (`GradientBorderBox` and `GradientButton` matching `#FFB300 → #FF8C00 → #FF5A00`).

---

## 7. Resolved Bugs & Fix History

1. **Duplicate Member Save Crash:** Duplicate mobile checks are validated prior to file writes; local notification exceptions are isolated in a nested `try/catch` to avoid false save failures.
2. **"Expiring Soon" Filter Empty State:** Filter query logic separates member `startDate` filtering from membership status queries so older members expiring this month are not masked.
3. **Total Members Card Lock:** Total card tap handler explicitly resets active status filter chips.
4. **Silent Plan Null Return:** Form validation intercepts unselected/empty plan states and guides the user through plan creation modal flows.
5. **Join Date Immutability:** Explicit join/payment date pickers were added to `EditMemberScreen` and piped through `GymRepository.updateMemberDetails()`.
6. **Android Build Tooling:**
   * Enabled Java 8+ core library desugaring (`isCoreLibraryDesugaringEnabled = true` + `desugar_jdk_libs:2.1.4`).
   * Updated `image_cropper` to `^8.1.0` to fix legacy transitive Android Gradle plugin dependencies.
   * Standardized build configs using Kotlin DSL (`build.gradle.kts`).

---

## 8. Current Deployment Status & Next Steps

* **Current Status:** **In Review (Submission 1)** in Google Play Console for the Closed Testing (Alpha) track.
* **Immediate Action Items Upon Approval:**
  1. Status turns to **Active**.
  2. Copy the **"Join on the web"** opt-in URL from **Testing $ightarrow$ Closed testing $ightarrow$ Testers**.
  3. Distribute the opt-in link to the 20 whitelisted testers.
  4. Track the **14 consecutive days** mandatory testing period before applying for production release.

---

## 9. Known Gaps & Future Roadmap

* **Media in Backups:** Local JSON export currently backs up tabular/text records; member photos are stored locally on-device and are not yet bundled into a single ZIP archive during export.
* **Multi-Device Cloud Sync:** Scoped for v2 using Firebase Firestore + Drive API.
* **Single Branch Only:** Multi-location support, staff sub-accounts, and automated SMS gateways remain out of scope to preserve 100% free-tier operation.
