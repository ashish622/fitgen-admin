# FitGen Admin

Admin web panel for the FitGen app (Flutter Web). Plan:
`../fitgen/docs/ADMIN_PANEL_DEVELOPMENT_PLAN.md`.

## Architecture
- Reads: Firestore directly (gated by `isPlatformAdmin(<capability>)` rules).
- Writes: only via Cloud Functions in `../fitgen/functions/adminService.js`
  (capability check + audit log). The panel never writes Firestore directly.

## Setup
1. Register a **Web app** in the Firebase console (project `fitgen-fa9b4` or dev/staging).
2. `cp env/example.json env/dev.json` and fill in the web config values.
3. Deploy backend from `../fitgen`: `firebase deploy --only functions,firestore:rules`.
4. Grant yourself admin (in `../fitgen/functions`):
   ```
   node scripts/managePlatformAdmin.js grant --project=<id> --uid=<your-uid> \
     --capabilities=users_read,users_manage --actor=<your-email> --execute
   ```
5. Run: `flutter run -d chrome --dart-define-from-file=env/dev.json`

## Status
- [x] Phase 0: scaffold, login, capability-aware shell, dashboard counts
- [x] Phase 1 (part): users list/detail, block/suspend/activate, add user
- [ ] Coins adjust, support tickets, feature access, stats, campaigns
