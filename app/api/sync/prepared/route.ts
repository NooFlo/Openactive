import { NextResponse } from "next/server";
import fs from "node:fs/promises";
import path from "node:path";
import { currentUser, unauthorized } from "@/lib/auth";
import type { Tour } from "@/lib/gpx";

const DATA_DIR = path.join(process.cwd(), "data", "tours");

export async function GET() {
  const user = await currentUser();
  if (!user) return unauthorized();
  const files = await fs.readdir(DATA_DIR).catch(() => [] as string[]);
  const prepared: Tour[] = [];
  for (const f of files.filter((f) => f.endsWith(".json"))) {
    const tour = JSON.parse(await fs.readFile(path.join(DATA_DIR, f), "utf8")) as Tour;
    if (tour.preparedAt) prepared.push(tour);
  }
  prepared.sort((a, b) => (b.preparedAt ?? "").localeCompare(a.preparedAt ?? ""));
  return NextResponse.json({
    trips: prepared.map((t) => ({
      slug: t.slug,
      title: t.title,
      stats: t.stats,
      preparedAt: t.preparedAt,
      bundleUrl: `/api/tours/${t.slug}/bundle`,
    })),
  });
}
