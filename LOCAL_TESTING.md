# Phase 10: Local Testing (without affecting production)

Use this guide to run and test Phase 10 locally. **Production** (`master` on Railway) stays unchanged.

## Prerequisites

- Node.js, Flutter, PostgreSQL
- Git branch: `phase-10` (not `master`)

## 1. Run backend locally

```bash
cd server
npm install
npm run start:dev
```

Server runs at `http://localhost:3000`.

## 2. Point the app at local server

From `app/`, run the Flutter app with:

```bash
# Replace YOUR_PC_IP with your machine's LAN IP (e.g. 192.168.1.5)
# Use localhost only for Android emulator; use your PC IP for a real device.
flutter run --dart-define=API_BASE_URL=http://YOUR_PC_IP:3000 --dart-define=ACCESS_TOKEN=your_mapbox_token
```

- **Emulator**: `API_BASE_URL=http://10.0.2.2:3000` (Android) or `http://localhost:3000` (iOS)
- **Real device**: Use your PC's LAN IP (e.g. `http://192.168.1.5:3000`)

## 3. What to test

- Map centers on Sector 40 (28.45, 77.05)
- Three tile colors: **grey** = neutral, **blue** = yours, **red** = others
- Pan/zoom triggers tile refresh (debounced ~2s)
- Sign in to see “yours” vs “others” (backend needs Firebase configured)

## 4. Fallback behavior

If `GET /tiles/near` returns 404 (endpoint not deployed), the app falls back to `GET /tiles` and uses your Firebase UID to classify tiles.

## 5. Production stays safe

- `master` branch = production (no Phase 10)
- `phase-10` branch = feature branch
- Do **not** merge `phase-10` into `master` until you're ready to deploy.
