import type { Tour, TourStats } from "@/lib/gpx";

export interface TileRef {
  z: number;
  x: number;
  y: number;
}

export interface OfflineBundle {
  slug: string;
  title: string;
  description: string;
  preparedAt: string;
  points: [number, number][];
  stats: TourStats;
  zoomMin: number;
  zoomMax: number;
  tileCount: number;
  estSizeMb: number;
  tileCacheBase: string;
  tiles: TileRef[];
}

const TILE_URL = "https://tiles.openfreemap.org/planet/{z}/{x}/{y}.pbf";
const AVG_TILE_BYTES = 25_000;

function lonToTileX(lon: number, z: number): number {
  return Math.floor(((lon + 180) / 360) * 2 ** z);
}

function latToTileY(lat: number, z: number): number {
  const rad = (lat * Math.PI) / 180;
  return Math.floor(((1 - Math.log(Math.tan(rad) + 1 / Math.cos(rad)) / Math.PI) / 2) * 2 ** z);
}

const MAX_TILES = 60_000;

export function computeTilesForTrack(
  track: [number, number][],
  bufferKm = 2,
  zoomMin = 11,
  zoomMax = 15
): { tiles: TileRef[]; truncated: boolean } {
  if (track.length === 0) return { tiles: [], truncated: false };
  const lats = track.map((p) => p[1]);
  const lons = track.map((p) => p[0]);
  const latMin = Math.min(...lats);
  const latMax = Math.max(...lats);
  const lonMin = Math.min(...lons);
  const lonMax = Math.max(...lons);
  const degLat = bufferKm / 111;
  const midLat = (latMin + latMax) / 2;
  const degLon = bufferKm / (111 * Math.cos((midLat * Math.PI) / 180) || 1);

  const seen = new Set<string>();
  const tiles: TileRef[] = [];
  let truncated = false;

  for (let z = zoomMin; z <= zoomMax; z++) {
    const x0 = lonToTileX(lonMin - degLon, z);
    const x1 = lonToTileX(lonMax + degLon, z);
    const y0 = latToTileY(latMax + degLat, z);
    const y1 = latToTileY(latMin - degLat, z);
    for (let x = x0; x <= x1; x++) {
      for (let y = y0; y <= y1; y++) {
        const key = `${z}/${x}/${y}`;
        if (seen.has(key)) continue;
        seen.add(key);
        tiles.push({ z, x, y });
        if (tiles.length > MAX_TILES) {
          truncated = true;
          return { tiles, truncated };
        }
      }
    }
  }
  return { tiles, truncated };
}

export function buildBundle(
  tour: Tour,
  tiles: TileRef[],
  origin: string,
  preparedAt: string,
  zoomMin = 11,
  zoomMax = 15
): OfflineBundle {
  return {
    slug: tour.slug,
    title: tour.title,
    description: tour.description,
    preparedAt,
    points: tour.points.map((p) => [p.lon, p.lat] as [number, number]),
    stats: tour.stats,
    zoomMin,
    zoomMax,
    tileCount: tiles.length,
    estSizeMb: Math.round((tiles.length * AVG_TILE_BYTES) / 100_000) / 10,
    tileCacheBase: `${origin}/api/tiles`,
    tiles,
  };
}

export const OPENFREEMAP_TILE_URL = TILE_URL;
