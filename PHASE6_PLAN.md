# Phase 6 — Territory capture & real-time

Phase 6 adds capture rules (claim tiles when a run touches them), optional real-time updates, and leaderboard/anti-cheat.

## Goals

- **Backend**: When a run is saved, compute which tiles the path intersects and assign ownership to the runner.
- **App**: Show who owns which tiles (e.g. different color); optional real-time refresh.
- **Later**: WebSockets for live tile/leaderboard updates; anti-cheat; leaderboard API + screen.

## 6.1 Backend — Territory capture rules

- [x] Add `owner_id` (nullable UUID FK to users) to `tiles` table.
- [x] On `POST /runs` success: compute tiles that the run path intersects (point-in-rect); set those tiles’ `owner_id` to the run’s user (`TilesService.captureTilesByPath`).
- [x] `GET /tiles` returns `ownerId` (entity serialization) so the app can style by owner.

**Definition of done**: Saving a run that passes through tiles assigns those tiles to the user; GET /tiles includes owner.

## 6.2 App — Show tile ownership on map

- [x] Use `ownerId` from tiles: two layers — unowned (blue), owned (green).
- [x] Refresh tiles after saving a run so the map updates.

**Definition of done**: Map reflects tile ownership visually.

## 6.3 Backend — Leaderboard (optional)

- [x] `GET /tiles/leaderboard`: top users by tile count; optional `?limit=20` (max 100).
- [x] App: Leaderboard screen (rank, username, tile count); link from Home; pull-to-refresh.

## 6.4 WebSockets & anti-cheat (optional / later)

- [x] WebSocket gateway: broadcast tile changes when a tile is captured so other clients can update without polling.
- [x] Anti-cheat: basic run validation (e.g. max speed, path consistency) before allowing capture.

---

## Order of implementation

1. **6.1** — Tile `owner_id`, run–tile intersection on POST /runs, GET /tiles returns owner.
2. **6.2** — App: style tiles by owner on map; optional refresh after run save.
3. **6.3** — Leaderboard endpoint (optional).
4. **6.4** — WebSockets + anti-cheat (later).

## Prerequisites

- Phase 5 complete (runs, tiles, map).
- Tiles table and RunsService in place.
