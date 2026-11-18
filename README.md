# Openactive

Open source outdoor planning and navigation for **hiking and mountain biking**: a web app to plan and review tours on a 3D terrain map, with GPX + description ingestion from tourism sites, and a companion iOS + Apple Watch app for offline navigation in the field.

## Status

- **Web MVP (this repo, `app/`)**: MapLibre 3D terrain map + tour ingestion pipeline. Works, under active development.
- **iOS / watchOS apps**: designed (see below), not yet scaffolded in this repo.

## Web MVP

Stack (chosen deliberately from reliable open source projects):

| Concern | Choice | Why |
|---|---|---|
| Framework | Next.js 15 + React 19 (TypeScript) | App/router + API routes for the ingestion endpoint in one project |
| Map | [MapLibre GL JS](https://maplibre.org/maplibre-gl-js/) (BSD-2) | Open source, GPU vector maps, 3D terrain, hillshade, pitch ~85° |
| Basemap | [OpenFreeMap](https://openfreemap.org/) `liberty` style | Free vector tiles, no API key, no rate limits |
| Terrain DEM | AWS Terrain Tiles (terrarium encoding, open data) | Global elevation raster; switchable to self-hosted Mapterhorn/Copernicus later |
| GPX parsing | `fast-xml-parser` | Fast, zero-dependency XML → track points + elevation/time |
| Page extraction | `cheerio` + schema.org JSON-LD | Title/description/GPX-link extraction from tourism pages |

## Home server: accounts, privacy, offline trips

Openactive is designed to **run on your own home server** (Raspberry Pi, NAS, mini PC, Docker on anything). Data, credentials, and tile caches never leave your network.

### Household accounts

- Simple username/password users you create locally. Passwords are scrypt-hashed (`data/users.json`), sessions are HMAC-signed cookies (`data/.secret`, both gitignored).
- Accounts exist to separate users within a household — every member sees all prepared trips (shared household library), while ingest/prepare requires being signed in.
- No email, no tracking, no external auth providers, nothing sent to third parties.

```bash
npm install
npm run setup                      # generates data/.secret
npm run add-user -- alice s3cret  # add household users
npm run dev                        # or: npm run build && npm start, behind your reverse proxy
```

### Push route from desktop → mobile (offline trip flow)

1. **Plan on desktop**: ingest a tour (URL or GPX paste), then hit **“Prepare trip for mobile.”**
2. The server computes an offline bundle manifest for the track: OpenFreeMap vector tile set (zoom 11–15, 2 km buffer around the track, capped at 60k tiles + estimated size) and marks the trip as prepared.
3. **On mobile**: tap **“Download prepared trip.”** The app lists prepared trips (`GET /api/sync/prepared`), then downloads the bundle (`GET /api/tours/<slug>/bundle`) and pulls every tile in the manifest from the **home server tile cache** (`GET /api/tiles/{z}/{x}/{y}.pbf`), which transparently fills its disk cache from OpenFreeMap on first request.
4. Once the phone has the bundle + tiles, **no connectivity of any kind is needed on the trip** — not to the home server, not to the internet. The watch gets the route via Watch Connectivity from the phone.

Privacy note: the trip reviews happen inside your LAN whenever you pre-download; the tile cache grows in `data/tile-cache/` and can be wiped at any time.

### Run

```bash
npm install
npm run setup
npm run add-user -- <username> <password>
npm run dev        # http://localhost:3000
```

### Ingestion pipeline (`POST /api/tours`)

Two modes:

1. **URL** — paste a tourism/tour page URL or a direct `.gpx` URL. The server:
   - fetches direct GPX, or fetches the HTML and discovers `.gpx` links,
   - extracts title/description from schema.org JSON-LD (`TouristTrip`, `Route`, `Place`, `Article`), falling back to OpenGraph/meta tags and article containers,
   - parses the GPX, computes distance/ascent/descent/elevation stats,
   - saves the tour to `data/tours/<slug>.json`.
2. **Paste** — paste GPX XML plus optional title/description for files you already have.

Tours: `GET /api/tours` (list) and `GET /api/tours/<slug>` (full record). Storage is file-based JSON for the MVP; the plan is to move to Postgres + PostGIS and PMTiles bundles for offline packaging later.

## iOS + watchOS app (design decisions)

- **iPhone**: Swift/SwiftUI + **MapKit** with an offline raster tile cache (region download as a tile bundle, `MKTileOverlay`; `MKPolyline` for the track). Google/OsmAnd-style vector rendering via MapLibre Native is the fallback option if we need hillshade on-device.
- **Apple Watch**: **no maps on the watch.** Navigate the GPX track "Backtrack-style": black-background SwiftUI screen with the breadcrumb polyline, current position, heading cone, distance to next waypoint, and wrist-tap haptics on off-route deviation or waypoint approach. Built with MapKit SwiftUI (`Map`, `MapPolyline`, `UserAnnotation`), CoreLocation (`CLHeading`), and a HealthKit/WorkoutKit hiking workout session so background location stays alive with 4G-free battery discipline.
  - Note: Apple's Compass Backtrack UI has **no public API**; everything above uses only sanctioned frameworks. `WKInterfaceMap` is avoided (MapKit for SwiftUI covers watchOS).
- **Transfer**: routes + downloaded regions go iPhone → Watch via Watch Connectivity; the watch works standalone (no iPhone in the field).
- **Sync**: via your home server (see above): phone pulls prepared trips and offline tiles on Wi-Fi, then works fully offline. No cloud service, ever.

## License

To be decided (recommend MIT or Apache-2.0 for app code). Do not copy code from GPL-3 projects (e.g., iOS-Open-GPX-Tracker) into this repo; patterns only.
