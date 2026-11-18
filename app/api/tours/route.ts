import { NextResponse } from "next/server";
import fs from "node:fs/promises";
import path from "node:path";
import { computeStats, parseGpx, slugify, type Tour } from "@/lib/gpx";
import { extractFromHtml, fetchText } from "@/lib/extract";

const DATA_DIR = path.join(process.cwd(), "data", "tours");

async function saveTour(tour: Tour): Promise<Tour> {
  await fs.mkdir(DATA_DIR, { recursive: true });
  let slug = tour.slug;
  let filePath = path.join(DATA_DIR, `${slug}.json`);
  let n = 2;
  while (true) {
    try {
      await fs.access(filePath);
      slug = `${tour.slug}-${n++}`;
      filePath = path.join(DATA_DIR, `${slug}.json`);
    } catch {
      break;
    }
  }
  tour.slug = slug;
  await fs.writeFile(filePath, JSON.stringify(tour, null, 2), "utf8");
  return tour;
}

export async function GET() {
  const files = await fs.readdir(DATA_DIR).catch(() => [] as string[]);
  const tours = await Promise.all(
    files
      .filter((f) => f.endsWith(".json"))
      .map(async (f) => JSON.parse(await fs.readFile(path.join(DATA_DIR, f), "utf8")) as Tour)
  );
  return NextResponse.json({ tours });
}

export async function POST(request: Request) {
  let body: {
    url?: string;
    gpx?: string;
    title?: string;
    description?: string;
    sourceUrl?: string;
  };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: "Invalid JSON body" }, { status: 400 });
  }

  let gpxXml = body.gpx?.trim() ?? "";
  let title = body.title?.trim() ?? "";
  let description = body.description?.trim() ?? "";
  let sourceUrl = body.sourceUrl?.trim() ?? null;

  if (body.url) {
    const url = body.url.trim();
    const isDirectGpx = url.toLowerCase().split("?")[0].endsWith(".gpx");
    try {
      if (isDirectGpx) {
        gpxXml = gpxXml || (await fetchText(url));
        sourceUrl = sourceUrl ?? url;
      } else {
        const html = await fetchText(url);
        const extracted = await extractFromHtml(html, url);
        if (!gpxXml && extracted.gpxUrls.length > 0) {
          gpxXml = await fetchText(extracted.gpxUrls[0]);
          sourceUrl = sourceUrl ?? url;
        }
        if (!title) title = extracted.title ?? "";
        if (!description) description = extracted.description ?? "";
      }
    } catch (err) {
      return NextResponse.json(
        { error: `Failed to fetch or extract: ${(err as Error).message}` },
        { status: 422 }
      );
    }
  }

  if (!gpxXml) {
    return NextResponse.json(
      { error: "No GPX found. Provide a direct GPX URL, a page containing a .gpx link, or paste GPX XML." },
      { status: 400 }
    );
  }

  const points = parseGpx(gpxXml);
  if (points.length === 0) {
    return NextResponse.json({ error: "Could not parse any track points from the GPX data." }, { status: 422 });
  }

  const stats = computeStats(points);
  const gpxName = /<name>([^<]+)<\/name>/.exec(gpxXml)?.[1]?.trim();
  const fallbackSlugTitle = title || gpxName || "Untitled tour";

  const tour: Tour = {
    slug: slugify(fallbackSlugTitle),
    title: fallbackSlugTitle,
    description,
    sourceUrl,
    createdAt: new Date().toISOString(),
    points,
    stats,
  };

  const saved = await saveTour(tour);
  return NextResponse.json({ tour: saved }, { status: 201 });
}
