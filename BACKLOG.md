# Zoom-In Chile — Backlog

Things parked during a release to keep the envelope tight. Pull from here when starting a new dev cycle.

## Security / API hardening

- **Rate-limit POST endpoints.** Add `express-rate-limit` in `admin-backend/server.js` on `POST /api/leaderboard*` and `POST /api/backup*` (≈10 req/min per IP). Deploys without app changes. Why: today the leaderboard submit + backup create endpoints are public and unbounded — a bad actor could spam fake scores or generate thousands of backup codes. Cheap mitigation, blocks 95% of the realistic abuse.
- **Firebase App Check + Play Integrity.** Add `firebase_app_check` to the Flutter app, init in `main.dart`, attach the App Check token to every API request. Server middleware verifies via Google. Why: the only real way to assert "this request comes from my real APK on a Play Store install". Defer until ~1k users or visible abuse. Tradeoff: rooted/emulator users break — need a policy.
- **API hardening review** before going past 1k DAU: audit each public endpoint for what data leaks (currently locations + scoring + trophies + leaderboard, all considered public game content).

## Filters / map UX

- **Rethink zone filters.** Removed from the filter row in 1.12.1 because they doubled chip count and no clear ordering. Decide: do we want zones as a separate accordion, a long-press shortcut on cards, or a dedicated map view? Pending design pass.

## Share flow

- **Spot-check share text in admin Settings tab end-to-end.** New as of 1.12.1: text + link configurable from `https://games.sabino.cl/zoominchile/admin`, but I haven't validated the round-trip on a real device after editing.
- **Robust share-result detection on Android.** `share_plus` returns `unavailable` on most Android share sheets even on success — current logic treats Android `unavailable` as success which over-rewards (e.g. user opens sheet, cancels). If abuse appears, switch to a confirmation prompt ("¿Compartiste?") or migrate to a newer share API.

## Polish

- **Refactor custom-Container "buttons" in `completion_drawer.dart`.** Share / Maps / Favorite / Ranking are inline `GestureDetector + Container`. A shared `PrimaryButton` widget would centralize hit area, ripple, and disabled states.
- **Bitmask the per-puzzle flags.** `hasShared` / `photoViewed` / `mapsOpened` are 3 bools today. Fine for now; bitmask if more flags appear.
- **Localize Play Store URL in email templates.** `admin-backend/email-templates.js:11` is hardcoded. Low priority — server-only.
