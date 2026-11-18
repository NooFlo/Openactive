import { XMLParser } from "fast-xml-parser";

export interface TrackPoint {
  lat: number;
  lon: number;
  ele: number | null;
  time: string | null;
}

export interface TourStats {
  distanceKm: number;
  ascentM: number;
  descentM: number;
  minEleM: number | null;
  maxEleM: number | null;
  points: number;
}

export interface Tour {
  slug: string;
  title: string;
  description: string;
  sourceUrl: string | null;
  createdAt: string;
  points: TrackPoint[];
  stats: TourStats;
}

const R_EARTH = 6371000;

function haversine(a: TrackPoint, b: TrackPoint): number {
  const rad = Math.PI / 180;
  const dLat = (b.lat - a.lat) * rad;
  const dLon = (b.lon - a.lon) * rad;
  const la1 = a.lat * rad;
  const la2 = b.lat * rad;
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.sin(dLon / 2) ** 2 * Math.cos(la1) * Math.cos(la2);
  return 2 * R_EARTH * Math.asin(Math.sqrt(h));
}

export function parseGpx(xml: string): TrackPoint[] {
  const parser = new XMLParser({
    ignoreAttributes: false,
    attributeNamePrefix: "@_",
    parseTagValue: true,
  });
  const doc = parser.parse(xml) as Record<string, unknown>;
  const gpx = (doc.gpx ?? {}) as Record<string, unknown>;

  const toPoints = (v: unknown): TrackPoint[] => {
    if (!v) return [];
    const arr = Array.isArray(v) ? v : [v];
    return (arr as Record<string, unknown>[])
      .map((t) => {
        const lat = Number(t["@_lat"]);
        const lon = Number(t["@_lon"]);
        if (!Number.isFinite(lat) || !Number.isFinite(lon)) return null;
        const ele = t["ele"] != null ? Number(t["ele"]) : null;
        return {
          lat,
          lon,
          ele: Number.isFinite(ele as number) ? (ele as number) : null,
          time: typeof t["time"] === "string" ? t["time"] : null,
        } as TrackPoint;
      })
      .filter((p): p is TrackPoint => p !== null);
  };

  const trk = gpx["trk"] as Record<string, unknown> | Record<string, unknown>[] | undefined;
  const trkArr = trk ? (Array.isArray(trk) ? trk : [trk]) : [];
  const points: TrackPoint[] = [];
  for (const t of trkArr as Record<string, unknown>[]) {
    const segs = t["trkseg"] as Record<string, unknown> | Record<string, unknown>[] | undefined;
    const segArr = segs ? (Array.isArray(segs) ? segs : [segs]) : [];
    for (const s of segArr as Record<string, unknown>[]) {
      points.push(...toPoints(s["trkpt"]));
    }
  }
  const wpts = toPoints(gpx["wpt"]);
  return points.length > 0 ? points : wpts;
}

export function computeStats(points: TrackPoint[]): TourStats {
  let distance = 0;
  let ascent = 0;
  let descent = 0;
  let minEle: number | null = null;
  let maxEle: number | null = null;

  for (let i = 0; i < points.length; i++) {
    const p = points[i];
    if (p.ele == null) continue;
    minEle = minEle == null ? p.ele : Math.min(minEle, p.ele);
    maxEle = maxEle == null ? p.ele : Math.max(maxEle, p.ele);
    if (i > 0) distance += haversine(points[i - 1], p);
    if (i > 0 && points[i - 1].ele != null) {
      const d = p.ele - (points[i - 1].ele as number);
      if (d > 0) ascent += d;
      else descent -= d;
    }
  }

  return {
    distanceKm: Math.round((distance / 1000) * 100) / 100,
    ascentM: Math.round(ascent),
    descentM: Math.round(descent),
    minEleM: minEle,
    maxEleM: maxEle,
    points: points.length,
  };
}

export function slugify(input: string): string {
  return input
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 64) || `tour-${Date.now()}`;
}
