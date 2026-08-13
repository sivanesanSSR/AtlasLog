# After Pulling This Repo — Setup Checklist

Everything below is **gitignored on purpose** (secrets, machine-specific
paths, or auto-regenerable build output). A fresh `git clone` or
`git pull` will **not** include these — you need to recreate them
locally before the app runs or builds.

## 1. Install dependencies
```powershell
flutter pub get
```

## 2. Files you must recreate yourself (not in git)

| File | What it is | How to recreate |
|---|---|---|
| `android/key.properties` | Release keystore passwords | Create manually — see template below |
| `*.jks` (e.g. `gym-manager-release.jks`) | Your release signing key | Restore from your own backup, or generate a new one (see note below) |
| `android/local.properties` | Local SDK path | Auto-created by Android Studio/Flutter on first build — no action needed |

**`android/key.properties` template:**
```
storePassword=<your password>
keyPassword=<your password>
keyAlias=gymmanager
storeFile=C:\\Users\\sivan\\gym-manager-release.jks
```

⚠️ **If this is a fresh machine and you don't have a backup of your
`.jks` file**: you cannot recreate the *same* keystore — it's
cryptographically unique. If you've never published to Play Store yet,
just generate a new one (see `README.md` → "Signing setup"). If you
*have* published under the old key, you need that exact `.jks` file
back from wherever you backed it up — there's no way to regenerate an
identical one.

## 3. Assets that ARE in git (verify they pulled correctly)
These are tracked, not ignored — confirm they're present:
- `assets/icon/icon.png`, `assets/icon/icon_adaptive_foreground.png`
- `assets/splash/splash.png`
- `android/build_gradle_kts_COMPLETE_FILE.txt`
- `android/proguard_rules_COMPLETE_FILE.txt`
- `android/AndroidManifest_queries_snippet.txt`

## 4. Apply the Android config files (if `android/` was regenerated)
If you ever run `flutter create .` again (e.g. on a new machine, or
after deleting `android/`), you must re-apply:
1. Replace the full contents of `android/app/build.gradle.kts` with
   `android/build_gradle_kts_COMPLETE_FILE.txt`
2. Replace `android/app/proguard-rules.pro` with
   `android/proguard_rules_COMPLETE_FILE.txt`
3. Merge `android/AndroidManifest_queries_snippet.txt` into
   `android/app/src/main/AndroidManifest.xml`

If `android/` already exists and these are already merged in, skip this step.

## 5. Build
```powershell
flutter clean
flutter pub get
flutter build apk --release
```
Or for local testing:
```powershell
flutter run
```

## 6. On-device data — NOT part of git at all
Member data, gym profile, plans, payments, and photos live entirely on
the **installed app's local storage** on the phone — none of that
travels with git, ever. It's device-specific runtime data, not source
code. Use **Export Backup** (in-app, Settings tab) to move that data
between devices or machines — it has nothing to do with git.
