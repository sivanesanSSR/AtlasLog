# Gym Manager — Project Context (Handoff Document)

This document gives full context on the Gym Manager Flutter app so
anyone — human developer or AI assistant — can pick up this project
without needing prior conversation history. It covers what the app is,
how it's built, every feature implemented, every bug fixed along the
way, and known gaps.

---

## 1. What this app is

A single-gym membership management app for Android (developer builds on
Windows; iOS is explicitly out of scope). One gym owner runs the app on
their own phone to track members, plans, payments, and renewal
reminders. There is **no backend server and no user accounts** — this
is a deliberate, considered architecture decision (see Section 3).

**Package name:** `com.atlas_log.atlas_log`
**App name:** Gym Manager

---

## 2. Tech stack

- **Flutter** (Dart), Material 3
- **State management:** Riverpod (`flutter_riverpod`)
- **Storage:** Local JSON files on-device (no cloud, no backend)
- **Charts:** `fl_chart`
- **Notifications:** `flutter_local_notifications` (on-device only)
- **Photos:** `image_picker` + `image_cropper`
- **Messaging:** `url_launcher` (opens WhatsApp/SMS apps, doesn't send programmatically)
- **Backup:** `file_picker` + `share_plus`

Full dependency list is in `pubspec.yaml` — nothing exotic, all mainstream packages.

---

## 3. Architecture decisions and why

### No backend — fully local storage
**Original design used Google Drive** (OAuth + Drive API) so a gym
owner's data could sync via their own Drive account. This was
**abandoned** after the developer (not deeply experienced with
Android/OAuth tooling) hit a long chain of setup failures: SHA-1
certificate mismatches, `DEVELOPER_ERROR`/`NETWORK_ERROR` codes, Google
Cloud Console configuration complexity. The friction wasn't worth it
for a single-user app, so the whole Drive integration was ripped out.

**Current design:** `LocalStorageService`
(`lib/services/local_storage_service.dart`) reads/writes JSON files in
the app's private documents directory, under a `GymManagerApp/`
subfolder:
- `gym_profile.json` — gym name, address, contact, logo path
- `plans.json` — membership plans (name, duration, price)
- `members.json` — member records
- `payments.json` — payment history
- `member_photos/` — member photo image files
- `gym_logo.*` — gym logo image file
- `reminder_template.txt` — customizable WhatsApp/SMS message template
- `theme_preference.txt` — `"dark"` or `"light"`

**No real-time multi-device sync.** A manual **Export/Import Backup**
feature (`lib/services/backup_service.dart`) bundles all *data* (not
photo files — known gap, see Section 8) into one timestamped JSON,
shared via the native share sheet or restored via a file picker.

### State management
Riverpod. All services are wired as `Provider`s in
`lib/services/providers.dart`. Screens obtain services via
`ref.read(xProvider)` / `ref.watch(xProvider)`.

### Data access layer
All screens go through `GymRepository` (`lib/services/gym_repository.dart`)
— never directly through `LocalStorageService`. This is where business
logic lives: duplicate validation, expiry-date calculation, dashboard
aggregation, photo file lifecycle management.

### Notifications vs. reminders — an important distinction
- **`NotificationService`** (`flutter_local_notifications`): schedules
  an on-device notification 3 days before a member's plan expires. This
  is the **only fully-automatic** reminder, and it notifies the **gym
  owner**, not the member.
- **`ReminderService`** (WhatsApp/SMS): there is **no backend or paid
  messaging API** integrated. "Sending" a reminder to a member always
  opens WhatsApp or the SMS app with the message pre-filled via URL
  scheme — the gym owner must tap Send themselves. This limitation is
  explicitly surfaced in the Send Reminders screen UI. A "bulk send"
  mode exists but is a UI convenience queue (step through selected
  members one at a time), not true bulk messaging.

---

## 4. Navigation structure

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

  Drawer (hamburger icon, available on all tabs):
    Dashboard, Analytics & Reports, Send Reminders, Manage Plans,
    Gym Profile, Settings — jumps to the relevant tab or pushes a screen
```

**Key implementation detail:** `DashboardScreen` and `AnalyticsScreen`
both have an `embedded: bool` constructor parameter (default `false`).
When `true` (used inside `HomeShellScreen`'s `IndexedStack`), they
render only their body content — no own `Scaffold`/`AppBar`/`Drawer` —
since the shell owns that chrome. When `false`, they behave as
standalone full-screen routes (kept for flexibility, though nothing in
the current app pushes them that way anymore).

`HomeShellScreen` refreshes the Dashboard tab after Add Member / plan
changes by **remounting it via a changing `ValueKey`** (bumping an
integer counter triggers `initState` → reload) rather than exposing
private state through a `GlobalKey` — chosen because Dart's leading-underscore
privacy is library-scoped, so reaching into another file's `State`
class isn't straightforward without making it public.

---

## 5. Full feature list (as of this document)

### Setup flow
- **Gym Profile**: name, address, contact, **logo** (photo picker with
  cropping, shown in the drawer header)
- **Plan management**: CRUD (name, duration in months, price)

### Dashboard (Tab 0)
- Counts grid: Total / Paid / Unpaid / Active / Expiring Soon / Expired
- **Tappable count cards act as filters** — tapping one filters the
  member list below; shown as a removable chip; tap again (or the
  Total card) to clear
- **Search box**: name / mobile / member ID
- **Date range filter**: defaults to current month (based on member's
  join/renewal date — `startDate`), adjustable, clearable. **Important
  interaction rule**: the date filter is automatically bypassed when a
  status card filter is active (see Section 6, bug #2) — otherwise a
  member expiring soon but who joined in an earlier month would be
  incorrectly hidden.
- Member list with photo thumbnails, color-coded status
  (green=active, amber=expiring ≤3 days, red=expired)

### Members (Tab 1)
Full member list, search only, no counts/date filter — a simpler
browse view than Dashboard.

### Reports (Tab 2) — `AnalyticsScreen`
Revenue summary (total / this month / outstanding due), 6-month revenue
bar chart, plan distribution pie chart, payment mode breakdown,
membership status bars.

### Settings (Tab 3)
Consolidated list: **theme switch** (dark/light toggle), Gym Profile,
Manage Plans, Send Reminders, Reminder Message template editor, Export
Backup, Import Backup.

### Add Member
- Name, mobile (validated unique — see bug #1 below), plan selection
- **Custom Member ID** (optional — leave blank to auto-generate `GM0001`
  style, or type your own, validated for uniqueness)
- **Custom Join/Payment Date** picker (defaults to today; backdating
  affects the calculated expiry date too)
- Amount paid + payment mode (Cash/UPI/Card/Other)
- **Photo capture** with cropping (camera or gallery)
- If no plans exist yet, or none is selected, a dialog/inline prompt
  guides the user to create one instead of silently failing

### Member Detail
Photo, status, plan info, payment history. Actions: Renew Plan, Edit
(pencil icon), Delete (trash icon, confirmation dialog), quick
SMS/WhatsApp reminder buttons.

### Edit Member
Name, mobile, **join/payment date** (added after a bug report — see
Section 6), photo. Plan/expiry/payment changes are intentionally **not**
editable here — those go through Renew, since they're billing logic.

### Renew Plan
Current status display, new plan selection, **custom Renewal Date**
picker (defaults to today, editable — expiry recalculates from
whichever is later: current expiry or the chosen renewal date), amount
paid, payment mode.

### Send Reminders
Lists expiring-soon/expired members. Send individually (WhatsApp/SMS
icon buttons) or select several for a bulk **queue** (steps through
selected members one at a time, since WhatsApp's URL scheme only
supports one recipient per launch — true bulk sending isn't possible
without a paid API). Message template is customizable (see below).

### Customizable reminder message template
`lib/services/message_template_service.dart` +
`lib/screens/edit_message_template_screen.dart`. Placeholder tokens:
`{{MEMBERNAME}}`, `{{GYMNAME}}`, `{{EXPIRYDATE}}`, `{{DAYSLEFT}}`,
`{{PLANNAME}}`, `{{AMOUNT}}`. Default template:
```
Hi {{MEMBERNAME}}, this is a reminder that your membership at {{GYMNAME}} expires on {{EXPIRYDATE}} (in {{DAYSLEFT}} days). kindly renew your membership 
Thank you🙂!
Stay Strong 💪🏻
```
Live preview with sample data while editing; "Reset" restores default.

### Theming — switchable, persisted
`lib/theme/app_theme.dart` builds two full `ThemeData` variants (dark
and light) sharing the same brand accent (orange gradient:
`#FFB300 → #FF8C00 → #FF5A00` fill, `#FFD54F → #FF8C00 → #FF4500`
border — matches the developer's supplied CSS/design reference). Choice
persisted via `ThemeModeController`
(`lib/services/theme_controller.dart`) to `theme_preference.txt`,
toggled from Settings.

**Custom gradient widgets** (`lib/widgets/`):
- `GradientBorderBox` — replicates the CSS `padding-box`/`border-box`
  double-gradient technique (a Container with gradient background,
  holding an inset Container with the actual fill color, so only a
  gradient ring shows around the edge). Used for Dashboard count cards,
  search box, date filter pill, drawer's active nav item.
- `GradientButton` — pill-shaped button filled with the orange fill
  gradient plus a soft glow shadow. Used for the primary "Add Member" CTA.

---

## 6. Bugs found and fixed (chronological, useful for understanding what NOT to reintroduce)

1. **Duplicate member silently not saving / false "add failed" error.**
   Root cause: `addMember()` wrote the member to storage *then*
   scheduled the local notification; if scheduling threw, the outer
   `catch` showed "failed" even though the member had already saved.
   Also, there was **no actual duplicate-mobile validation** originally.
   Fixed: mobile-number uniqueness is validated *before* any write;
   notification scheduling wrapped in its own try/catch so it can never
   masquerade as a save failure. Later hardened further: the duplicate
   error is now a **blocking dialog** (not just a snackbar, which was
   easy to miss), and a **separate real bug** was found and fixed where
   the Plan dropdown's own `validator` fired during
   `_formKey.currentState!.validate()` and silently blocked the whole
   form before ever reaching the "select/create a plan" prompt — that
   validator was removed since plan selection is now handled manually.

2. **"Expiring Soon" dashboard filter showing 0 results.** Root cause:
   the date-range filter (defaulting to "this month," based on member
   join date) was being ANDed with the status card filter. A member
   expiring soon may have joined months ago, so combining both hid
   everyone. Fixed: date range is now skipped entirely whenever a
   status card filter is active; the date button shows "(paused while
   filtering)" so the behavior is visible, not silent.

3. **"Total Members" card stopped working after visiting "Unpaid".**
   Root cause: the Total card's `onTap` was hardcoded to `null`
   (disabled) since it represents "no filter," so once another filter
   was active there was no way to tap Total to clear it. Fixed: Total's
   tap handler now clears whatever filter is active, when one is active.

4. **Member added without a plan selected → member vanished from
   dashboard after saving, no error shown.** Root cause: `_submit()`
   silently returned if `_selectedPlan == null`, with no user feedback.
   Fixed: if no plans exist at all, a dialog offers to jump into Plan
   creation and returns to Add Member afterward; if plans exist but none
   selected, a clear inline error + snackbar + "Add a Plan" shortcut.

5. **Edit Member couldn't change the join/payment date.** The field
   simply didn't exist on that screen originally. Added a date picker,
   wired through `GymRepository.updateMemberDetails()`.

### Android build issues (environment, not app-code bugs — resolved during setup, documented for reference)
- `keytool`/`JAVA_HOME` not on PATH → resolved by pointing at Android
  Studio's bundled JDK (`Android Studio\jbr\bin`)
- Windows Developer Mode required for Flutter plugin symlinks
- `flutter_local_notifications` requires **core library desugaring** —
  `compileOptions { isCoreLibraryDesugaringEnabled = true }` +
  `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")`
  dependency, both required together or the desugaring flag alone
  throws "configuration contains no dependencies"
- Groovy (`build.gradle`) vs Kotlin DSL (`build.gradle.kts`) syntax
  confusion — modern `flutter create` generates `.kts`, different
  syntax entirely (`=` assignment, `isX = true` style, double quotes)
- `image_cropper: ^8.0.2` pulled in a stale
  `com.android.tools.build:gradle:3.6.4` transitive dependency, causing
  Maven resolution failures that looked like network errors — fixed by
  bumping to `^8.1.0`
- **Lesson learned, now a standing practice**: giving "merge this block
  into your file" instructions repeatedly caused misplacement/syntax
  errors for this developer. Now Android Gradle config is provided as
  **complete files to paste in wholesale**
  (`android/build_gradle_kts_COMPLETE_FILE.txt`,
  `android/proguard_rules_COMPLETE_FILE.txt`), not partial snippets.

---

## 7. Design reference

The visual direction (both dark and light theme) is based on
screenshots the developer supplied: a black-background, orange-gradient
"EMUI-style" theme with thin gradient-bordered cards, plus AI-mockup
reference images showing a drawer with a gradient-bordered active nav
item and a bottom nav bar (Dashboard/Members/Reports/Settings icons).
The CSS gradient technique supplied:
```css
.con {
  background:
    linear-gradient(135deg, #FFB300 0%, #FF8C00 45%, #FF5A00 100%) padding-box,
    linear-gradient(140deg, #FFD54F 0%, #FF8C00 45%, #FF4500 100%) border-box;
  border: 3px solid transparent;
}
```
This exact technique is what `GradientBorderBox` replicates in Flutter.

---

## 8. Known gaps / not yet done

- **Export/Import Backup doesn't include photo files** — only JSON data
  records. Restoring a backup on a new device brings back all member
  data but not member/gym photos. Flagged in README, not yet fixed.
- **No multi-device real-time sync** — by design (see Section 3), not a bug.
- No attendance tracking, multiple branches, expense tracking, staff/
  role-based access, or referral codes — explicitly scoped out early on.
- WhatsApp/SMS "sending" is always a manual one-tap-per-message action;
  no paid messaging API integrated (explicit, documented limitation).
- iOS is out of scope (Windows-only development environment).

---

## 9. If you're an AI picking this up fresh

1. Read this whole document before making changes.
2. If told about a build error, ask for **exact current file content**
   rather than assuming — this project's Android build issues have
   repeatedly stemmed from a previous fix not actually landing as
   intended.
3. Prefer **complete files to paste in wholesale** over "merge this
   snippet" instructions for Android Gradle config specifically — that
   pattern has failed multiple times with this developer.
4. Don't reintroduce Google Drive/cloud storage — that was a deliberate
   decision after real friction, not an oversight.
5. The gradient/theme system is intentional brand identity (matches
   developer-supplied reference images) — don't revert to default
   Material colors without being asked.
6. `embedded` flags on `DashboardScreen`/`AnalyticsScreen` exist
   specifically so they can be hosted inside `HomeShellScreen`'s
   `IndexedStack` without double `Scaffold`/`AppBar` nesting — preserve
   this pattern if adding new tabs.
