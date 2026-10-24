# SECURITY AUDIT — Masar Al-Lugha v3.3 → v4.0

**Scope:** Android manifest/permissions, repository secrets, signing, data-at-rest,
logging, third-party surface.

## 1. Permissions — PASS (minimal)

`android/app/src/main/AndroidManifest.xml` declares **zero permissions**.
- No INTERNET in release → the app cannot exfiltrate anything; fully offline.
- `INTERNET` exists only in `src/debug/` (hot reload during development) — standard
  Flutter template, never ships to release builds.
- No storage/camera/mic/location access of any kind.
- `<queries>` PROCESS_TEXT declaration is the Flutter engine text-selection default.

## 2. Repository secrets — PASS (with one false positive explained)

- `git ls-files | grep -E "ghp_|AKIA|password"` matches `assets/data/course_en.json`
  solely because **"password" is a vocabulary word** in the Technology unit
  (`en_password`). Not a secret.
- CI authenticates via the GitHub-provided `GITHUB_TOKEN` at runtime; no tokens in YAML.
- `.gitignore` covers build outputs, `.pub-cache`, IDE files. No keystores,
  `key.properties`, or credential files are tracked. ✅

## 3. Signing — IMPROVED in v4.0

v3.3 signed release builds with the debug key (Flutter template TODO). v4.0:
- Adds an explicit `signingConfigs` seam reading `android/key.properties`
  (keystore path/passwords) **when present**, else falls back to debug signing so CI
  and local reproducible builds keep working.
- Documents that real release keystores are generated **outside the repo** and
  `key.properties` must never be committed.
- Debug and release signing paths are now visibly separate in `build.gradle.kts`.

## 4. Data at rest — acceptable for a local-only learning app

Stored: XP, streak, lesson stars, SRS card metadata, prefs — **no personal data
collected by design** (no accounts, no analytics, no identifiers, no network).
Corrupt-state handling now preserves a recoverable backup instead of silently wiping
(H2 in PROJECT_AUDIT.md). Export/import writes only this same local profile.

## 5. Logging & debug surface — PASS

- No `print`/`dart:developer` logging of user data in `lib/`.
- `debugShowCheckedModeBanner: false`; no debug prints.
- No WebView, no JavaScript bridge, no deep links → no injection surface.

## 6. Supply chain — small and pinned

Direct deps: `shared_preferences`, `flutter_tts` (first-party Flutter ecosystem) with
bounded ranges; `dependency_overrides` pins `shared_preferences_android` (documented
build workaround). CI uses pinned Flutter 3.47.7 + JDK 17 + actions v4. No codegen, no
native plugins beyond the two above.

## 7. Residual risks (accepted & tracked)

1. Debug-signed release APK in CI artifacts — fine for sideloading beta; Play release
   requires creating a real keystore outside the repo (documented in README).
2. SharedPreferences JSON is readable via root/adb-backup on rooted devices — inherent
   to local-first apps holding no sensitive personal data; accepted.
3. Third-party TTS engines invoked by the OS may be cloud-backed (device-dependent) —
   outside app control; core features remain fully local.
