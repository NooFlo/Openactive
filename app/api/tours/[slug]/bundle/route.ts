import { NextResponse } from "next/server";
import fs from "node:fs/promises";
import path from "node:path";
import { currentUser, unauthorized } from "@/lib/auth";
import { buildBundle, computeTilesForTrack } from "@/lib/bundle";
import type { Tour } from "@/lib/gpx";

const DATA_DIR = path.join(process.cwd(), "data", "tours");

export async function GET(
  request: Request,
  { params }: { params: Promise<{ slug: string }> }
) {
  const user = await currentUser();
  if (!user) return unauthorized();
  const { slug } = await params;
  let tour: Tour;
  try {
    tour = JSON.parse(await fs.readFile(path.join(DATA_DIR, `${slug}.json`), "utf8"));
  } catch {
    return NextResponse.json({ error: "Tour not found" }, { status: 404 });
  }
  if (!tour.preparedAt) {
    return NextResponse.json({ error: "Trip is not prepared yet" }, { status: 409 });
  }
  const track = tour.points.map((p) => [p.lon, p.lat] as [number, number]);
  const { tiles } = computeTilesForTrack(track);
  const origin = new URL(request.url).origin;
  const bundle = buildBundle(tour, tiles, origin, tour.preparedAt);
  return NextResponse.json({ bundle });
}
