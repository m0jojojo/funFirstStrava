# Phase 5 — Map, tile grid & run tracking

Phase 5 adds the core game world: a map, a grid of capturable tiles (PostGIS), and run tracking so the backend can validate and attribute territory.

## Goals

- **Backend**: Tile grid in PostGIS; API to read tiles and (later) claim them.
- **App**: Map (Mapbox) showing the play area and tiles.
- **App**: Run tracking (GPS) with periodic updates to the backend.
- **Backend**: Accept run/position updates and determine which tiles were visited (foundation for capture).

## 5.1 Backend — Tile grid (PostGIS)

- [ ] Create `tiles` table: `id` (uuid), `geometry` (PostGIS geography/polygon), optional `owner_id` (FK to users), `created_at`.
- [ ] Seed a grid of tiles for a fixed play region (e.g. bounding box; hex or square grid).
- [ ] `GET /tiles` (or `GET /map/tiles`) — return tiles in a bounding box (GeoJSON or id + bounds).
- [ ] Add Tile entity, TilesModule, TilesService, env for DB (PostGIS already in use from Phase 2).

**Definition of done**: API returns tile list for a region; tiles visible in DB/PostGIS.

## 5.2 App — Map (Mapbox)

- [x] Add Mapbox dependency (`mapbox_maps_flutter`) and configure access token via `--dart-define ACCESS_TOKEN=...`.
- [x] New screen: full-screen map (`MapScreen`) centered on default/play region; "Open map" from Home.
- [ ] (Optional) Request location permission and center on user.
- [x] Document: token from https://account.mapbox.com/access-tokens/; run `flutter run --dart-define ACCESS_TOKEN=your_token`. On web, map shows placeholder (SDK is Android/iOS only).

**Definition of done**: App shows a Mapbox map; can pan/zoom.

## 5.3 App — Tiles on map

- [x] Call `GET /tiles` when map is created and draw tile polygons (FillLayer) on the map.
- [x] Draw tile geometries as polygons (GeoJSON FeatureCollection → GeoJsonSource + FillLayer; semi-transparent blue).
- [ ] (Optional) Refresh tiles when map moves (debounced); for now tiles load once on open.

**Definition of done**: Map displays tiles from the backend; tiles match DB grid.

## 5.4 App — Run tracking (GPS)

- [x] Location permission (Android already in manifest); `geolocator` package; request permission on Start run.
- [x] “Start run” / “Stop run” on map screen; sample position every 4s and on start; POST /runs with path + Bearer idToken.
- [x] Backend stores run (5.5); tile intersection can be added later.

**Definition of done**: App records a short run and sends it to the backend; backend stores run.

## 5.5 Backend — Run storage & tile intersection

- [x] `runs` table: `id`, `user_id`, `started_at`, `ended_at`, `path` (jsonb array of { lat, lng, t }).
- [x] `POST /runs` — auth via FirebaseAuthGuard (Bearer token), body `{ path: [{ lat, lng, t }, ...] }`, store run.
- [x] `GET /runs/me` — list current user’s runs (id, startedAt, endedAt, pathLength).

**Definition of done**: Backend persists runs; ready for Phase 6 (capture rules). Tile intersection optional later.

---

## Order of implementation

1. **5.1** — Tile grid + GET /tiles (backend only).
2. **5.2** — Map in app (Mapbox, no tiles yet).
3. **5.3** — Fetch and show tiles on map.
4. **5.4** — Run tracking in app (send positions to backend).
5. **5.5** — Run storage and tile intersection in backend.

## Prerequisites

- PostGIS extension enabled (Phase 2).
- Mapbox account and access token for the app.
- Backend base URL and auth (Phase 4) — use Firebase ID token or session for `POST /runs`.

## Next phase (Phase 6)

- Territory capture rules (claim tile when run satisfies conditions).
- WebSockets for real-time tile/leaderboard updates.
- Anti-cheat and leaderboard.
