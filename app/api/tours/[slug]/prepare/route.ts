import { NextResponse } from "next/server";
import fs from "node:fs/promises";
import path from "node:path";
import { currentUser, unauthorized } from "@/lib/auth";
import { buildBundle, computeTilesForTrack } from "@/lib/bundle";
import type { Tour } from "@/lib/gpx";

const DATA_DIR = path.join(process.cwd(), "data", "tours");

export async function POST(
  _request: Request,
  { params }: { params: Promise<{ slug: string }> }
) {
  const user = await currentUser();
  if (!user) return unauthorized();
  const { slug } = await params;
  const file = path.join(DATA_DIR, `${slug}.json`);
  let tour: Tour;
  try {
    tour = JSON.parse(await fs.readFile(file, "utf8"));
  } catch {
    return NextResponse.json({ error: "Tour not found" }, { status: 404 });
  }

  const track = tour.points.map((p) => [p.lon, p.lat] as [number, number]);
  const { tiles, truncated } = computeTilesForTrack(track);
  const preparedAt = new Date().toISOString();
  const origin = new URL(_request.url).origin;
  const bundle = buildBundle(tour, tiles, origin, preparedAt);

  tour.preparedAt = preparedAt;
  await fs.writeFile(file, JSON.stringify(tour, null, 2), "utf8");

  return NextResponse.json({ bundle, truncated });
}
