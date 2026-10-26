# FactoryOS Mobile — Physical-Device QA & Release Evidence

**Scope:** mobile review branch `ui/mobile-motion-polish-20261026`, PR #18. Never mark manual device checks as passed based only on Flutter widget tests, Linux builds, or iOS `--no-codesign` builds.

## Two different applications: do not confuse them

### Offline UI preview — safe design review

- GitHub Actions: **Mobile Release Quality** → Artifacts → `FACTORYOS-OFFLINE-UI-PREVIEW-NOT-FOR-STORE`.
- The downloadable debug APK is generated only from `apps/mobile/lib/qa_preview.dart` with `FACTORYOS_QA_PREVIEW=true`.
- Android application ID is `com.dkappsstudio.factoryos.qapreview` (unique from real FactoryOS).
- Home, Work, and Profile use openly marked synthetic fixtures; role selector previews Employee, Driver, Manager.
- No Supabase initialization, Firebase initialization, camera, employee attendance, stock transaction, or production data mutation.
- Visibly displays `OFFLINE UI PREVIEW · NO LIVE DATA` at all times.
- The artifact is **not** a signed Play Store release or a live end-to-end test.

To review on Android, download the ZIP from the successful workflow artifact, extract the APK and `QA_PREVIEW_SHA256.txt`, and verify the checksum before installation:

```bash
sha256sum -c QA_PREVIEW_SHA256.txt
adb install -r app-debug.apk
adb shell pm list packages | grep com.dkappsstudio.factoryos.qapreview
```

The checksum file uses the APK's basename and can be validated in the extracted artifact directory. The QA package uses its own `.qapreview` application ID and cannot be mistaken for a signed production build.

For development workstations that already have a Flutter/Android setup:

```bash
cd apps/mobile
FACTORYOS_QA_PREVIEW_BUILD=true flutter run --debug -t lib/qa_preview.dart --dart-define=FACTORYOS_QA_PREVIEW=true
```

PowerShell equivalent:

```powershell
cd apps/mobile
$env:FACTORYOS_QA_PREVIEW_BUILD = "true"
flutter run --debug -t lib/qa_preview.dart --dart-define=FACTORYOS_QA_PREVIEW=true
Remove-Item Env:FACTORYOS_QA_PREVIEW_BUILD
```

### Live mobile application — requires dedicated FactoryOS backend

Use **only** the normal `apps/mobile/lib/main.dart` entrypoint and an approved FactoryOS staging or pilot environment. Do not reuse Janseva/Salon projects. Production app ID: `com.dkappsstudio.factoryos`. A live test requires applied migrations, configured Auth, scoped memberships, storage, FCM and authorized test identities. It cannot be performed with the offline preview.

## Device test matrix

| Area | Device QA action | Required evidence |
| --- | --- | --- |
| Install / launch | Install preview APK and start cold/warm 3 times | App/version/build hash, video |
| Phone sizes | 320px, 375px and 430px logical widths, portrait | Screenshots, no overflow |
| Tablet | >= 720px logical layout with 3/4-column cards | Screenshot |
| Large text | OS text scaling up to 200% | Screenshots, readable navigation |
| RTL | Switch device/Flutter locale to an RTL language | Screenshots, no clipped chips/titles |
| Reduce Motion | Enable system Reduce Motion; switch tabs/open preview cards | Short video; no unwanted motion |
| Navigation | Home → Work → Profile → Home, repeat | Screen capture, no stuck pages |
| Search / roles | Search workspaces and switch Employee/Driver/Manager | Screen capture; Fleet absent to Employee |
| Offline mode | Airplane mode, restart preview | No external requirement or crashes |
| Memory/perf | Repeated tab switch 30x; background/foreground 5x | Crash log, jank notes |
| Visual checks | Color contrast, touch targets, text wraps, screen reader labels | Reviewer checklist |
| Real scanner | Approved live pilot: scan QR/barcode, cancel camera permission, tab away/back | Actual-device video |
| Real Auth | Approved live pilot: login, wrong password, sign-out and shared-phone user swap | Auth/RLS evidence, redact secrets |
| Real FCM | Approved live pilot: notification tap/deep link, revoked permissions, sign-out token disabled | Redacted event logs |
| Real workflows | Approved live pilot: Inventory, HR, Delivery, Fleet, Maintenance as allowed by role | Transaction IDs and RLS denials |
| iOS | Distribution-signed build on actual iPhone with APNs configured | Apple provisioning/build record and device video |

## Acceptance and sign-off

Record each case as **Passed / Failed / Blocked / Not Run**; include reviewer, timestamp, device model/OS, exact commit, APK SHA-256, screenshot/video and defects. Never label an unexecuted physical-device case Passed.

Release gate requires:
1. Green Flutter/Android/iOS compilation on the exact PR head;
2. completed manual visual QA on Android and iOS (or explicit platform-specific block for iOS);
3. approved FactoryOS-only backend with migrations and Auth;
4. tenant- and factory-scoped live role denial tests;
5. owner acceptance and merge approval;
6. separately approved signed store builds and deployment.

## Environment state observed October 26, 2026

Supabase project `factoryos-production` is now active/healthy. A read-only inspection returned zero public application tables, zero applied migrations and zero Edge Functions. Therefore **do not claim live FactoryOS or production smoke is ready**. Its existence does not authorize migration deployment. Set up a separate FactoryOS staging environment before pilot/device live workflow tests, or obtain explicit approval for a carefully limited production pilot after migrations and backups are reviewed.

Source: `docs/PHASE_16_PRODUCTION_RELEASE.md` and `docs/PRODUCTION_GO_LIVE_CHECKLIST.md`.
