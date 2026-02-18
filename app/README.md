# Territory Game — Flutter app

## Phase 3: Mobile app base

- **lib/core** — shared utilities, constants
- **lib/features** — feature screens (e.g. home)
- **lib/services** — API, auth, etc. (later phases)
- **lib/widgets** — reusable widgets

## Run locally

1. **Generate platform folders** (first time only; if `android/` and `ios/` are missing):
   ```bash
   cd app
   flutter create . --project-name app --org com.territorygame
   ```

2. **Install dependencies and run:**
   ```bash
   flutter pub get
   flutter run
   ```

Use a connected device or emulator. The home screen shows "Game Running".
