# Phase 0 — Development Environment Checklist

## What was completed in this repo

- [x] **Repository structure**: `app/` (Flutter) and `server/` (Backend) created
- [x] **Git**: Repository initialized; root `.gitignore` for Flutter + Node added
- [x] **Node.js**: Verified installed (v24.11.1)
- [x] **Git**: Verified installed (2.44.0)

## What you must do manually

### 1. Install Flutter (required for mobile app)

- **Current status**: `flutter` not found in PATH.
- **Install**: https://docs.flutter.dev/get-started/install/windows  
  (e.g. download SDK, extract, add `flutter\bin` to PATH.)
- **Verify**:
  ```powershell
  flutter doctor
  ```
  Resolve any reported issues (Android Studio, licenses, etc.).

### 2. Install PostgreSQL 15+ with PostGIS (required for backend)

- **Current status**: `psql` not found in PATH.
- **Install**: https://www.postgresql.org/download/windows/  
  During setup, add PostgreSQL `bin` to PATH.
- **PostGIS**: Install via Stack Builder (with PostgreSQL) or https://postgis.net/install/.
- **Verify**:
  ```powershell
  psql --version
  ```
- **Create DB when starting Phase 2**:
  ```sql
  CREATE DATABASE territory_game;
  \c territory_game
  CREATE EXTENSION postgis;
  ```

### 3. Verify all tools (run these after installing)

```powershell
node -v
flutter doctor
psql --version
git --version
```

All four must succeed. Phase 0 is **done** when every command runs without error.

### 4. Push to GitHub (when ready)

1. Create a new repository on GitHub (e.g. `funFirstStrava`).
2. Do **not** add a README or .gitignore (we already have .gitignore).
3. From this folder:
   ```powershell
   git remote add origin https://github.com/YOUR_USERNAME/funFirstStrava.git
   git add .
   git commit -m "Phase 0: project structure (app + server)"
   git branch -M main
   git push -u origin main
   ```

## Phase 0 done when

- All four verify commands succeed.
- `app/` and `server/` exist and are committed.
- Repo is pushed to GitHub (optional for local dev; required for “Phase 0 complete” per spec).
