# AGENTS.md — guidance for AI coding agents (OpenCode, Cursor, Claude, …)

You are working on **Openactive**, an open source outdoor planning and navigation project
for hiking and mountain biking. Read this file fully before making changes.

## Project state (what exists, what is planned)

This repository currently contains **only the web MVP** (Next.js app). Deliverables:

| Part | Status | Location |
|---|---|---|
| Web planning map (3D terrain) | ✅ works | `app/page.tsx`, `components/TourMap.tsx` |
| GPX/URL ingestion pipeline | ✅ works | `app/api/tours/route.ts`, `lib/extract.ts`, `lib/gpx.ts` |
| Household accounts (home server) | ✅ works | `lib/auth.ts`, `app/api/auth/login/route.ts`, `app/login/page.tsx` |
| Prepare-trip + offline bundle + tile cache | ✅ works | `app/api/tours/[slug]/prepare/route.ts`, `lib/bundle.ts`, `app/api/tiles/[...path]/route.ts`, `app/api/sync/prepared/route.ts` |
| iOS app (SwiftUI + MapKit) | ❌ not started | planned (see roadmap in `docs/ARCHITECTURE.md`) |
| watchOS app (map-free GPX "Backtrack-style" navigation) | ❌ not started | planned |

Do not touch the iOS/watchOS plan without reading `docs/ARCHITECTURE.md` — key decisions
are final (MapKit on iPhone, **no maps on the watch**, home-server sync architecture).

## Hard rules

1. **No cloud services.** The app runs entirely on a user's home server. Never add a
   third-party API that requires accounts, phone-home telemetry, or hosted SaaS.
   OpenFreeMap (tiles, free/unlimited, no key) and AWS terrain tiles are the only
   sanctioned externals, both accessed *through the home server cache*, never directly
   from a client app.
2. **Secrets stay local.** `data/.secret`, `data/users.json`, `data/tile-cache/` are
   gitignored. Never print, commit, or log their contents. Regenerate via `npm run setup`.
3. **GPL code is forbidden.** Several similar apps (iOS-Open-GPX-Tracker etc.) are GPL-3.
   Patterns may be studied; code may not be copied. Keep this repo permissively licensed.
4. **Offline-first is a contract, not an optimization.** Any trip data the phone needs on
   the trail must be part of the bundle (`/api/tours/<slug>/bundle`) and downloadable
   before departure from the home server alone.

## Verify before committing

```bash
npm run build          # typecheck + build must pass
npm run setup && npm run add-user -- test testpass   # creates data/.secret + user (gitignored)
# Then smoke test (ports: use something free, 3000/3030 may be taken):
PORT=3456 npm start &
# POST /api/auth/login {"username":"test","password":"testpass"} -> cookie
# Then per docs/ARCHITECTURE.md §API: ingest (needs a GPX), prepare, fetch bundle,
# fetch one tile, GET /api/sync/prepared.
```

Do not commit without a clean `npm run build`. Do not start long-running servers you
don't kill afterwards.

## Tech/conventions

- Next.js 15 App Router, React 19, TypeScript strict, no ESLint config yet (configs welcome).
- No CSS framework yet; plain CSS in `app/globals.css` (dark theme).
- Server: Node runtime (not edge) — routes use `node:fs` and `node:crypto` deliberately.
- Data is JSON on disk (`data/tours/*.json`). Postgres/PostGIS is a *future* migration,
  do not introduce an ORM yet.
- Client components (`"use client"`) only where needed (map, forms); keep API routes thin
  and put logic in `lib/`.
- No comments explaining obvious code; commit messages in imperative mood, one line.

## Roadmap priorities (in order)

1. Cache the MapLibre **style JSON** + DEM tiles on the home server too (currently the web
   map loads style from OpenFreeMap directly), making offline LAN operation real.
2. iOS app skeleton consuming the three sync endpoints (see API doc).
3. watchOS map-free navigation app.
4. Postgres/PostGIS migration + tour editing on the web map.
