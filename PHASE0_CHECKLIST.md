# Phase 0 — Development Environment Checklist

## What was completed in this repo

- [x] **Repository structure**: `app/` (Flutter) and `server/` (Backend) created
- [x] **Git**: Repository initialized; root `.gitignore` for Flutter + Node added
- [x] **Node.js**: Verified installed (v24.11.1)
- [x] **Git**: Verified installed (2.44.0)
- [x] **PATH**: Flutter and PostgreSQL `bin` added to user PATH (see paths below)

## Installed locations (already on PATH)

| Tool        | Path |
|------------|------|
| **Flutter** | `C:\Program Files\flutter` → `bin` in PATH |
| **PostgreSQL 18** | `C:\Program Files\PostgreSQL\18` → use `bin` in PATH |

**PostgreSQL**: `psql --version` verified (18.2).

**Flutter**: Open a **new** terminal (so PATH is reloaded) and run `flutter doctor`.

## What you must do manually

### 1. Verify Flutter (in a new terminal)

- PATH is already set. Open a **new** PowerShell or CMD window and run:
  ```powershell
  flutter doctor
  ```
  Resolve any reported issues (Android Studio, licenses, etc.).

### 2. PostGIS (required for backend Phase 2)

- PostgreSQL 18 is installed and on PATH.
- **PostGIS**: Install via Stack Builder (run from Start Menu after PostgreSQL install) or https://postgis.net/install/.
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
