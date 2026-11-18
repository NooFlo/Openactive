import { NextResponse } from "next/server";
import fs from "node:fs/promises";
import path from "node:path";
import { currentUser, unauthorized } from "@/lib/auth";
import { OPENFREEMAP_TILE_URL } from "@/lib/bundle";

const CACHE_DIR = path.join(process.cwd(), "data", "tile-cache");
const UPSTREAM = OPENFREEMAP_TILE_URL;

export async function GET(
  _request: Request,
  { params }: { params: Promise<{ path: string[] }> }
) {
  const user = await currentUser();
  if (!user) return unauthorized();
  const parts = (await params).path;
  if (parts.length !== 3) {
    return NextResponse.json({ error: "Expected /api/tiles/{z}/{x}/{y}.pbf" }, { status: 400 });
  }
  const [zRaw, xRaw, yRaw] = parts;
  if (!/^\d+\/\d+\/\d+\.pbf$/.test(parts.join("/"))) {
    return NextResponse.json({ error: "Invalid tile path" }, { status: 400 });
  }
  const cacheFile = path.join(CACHE_DIR, zRaw, xRaw, yRaw);
  try {
    const cached = await fs.readFile(cacheFile);
    return new NextResponse(new Uint8Array(cached), {
      headers: {
        "content-type": "application/vnd.mapbox-vector-tile",
        "cache-control": "public, max-age=31536000, immutable",
        "x-openactive-cache": "hit",
      },
    });
  } catch {
    const upstreamUrl = UPSTREAM.replace("{z}", zRaw).replace("{x}", xRaw).replace("{y}", yRaw);
    const upstream = await fetch(upstreamUrl, {
      headers: { "user-agent": "Openactive/0.1 (+home server tile cache)" },
    });
    if (!upstream.ok) {
      return NextResponse.json({ error: `Upstream tile fetch failed: ${upstream.status}` }, { status: 502 });
    }
    const data = Buffer.from(await upstream.arrayBuffer());
    await fs.mkdir(path.dirname(cacheFile), { recursive: true });
    await fs.writeFile(cacheFile, data);
    return new NextResponse(new Uint8Array(data), {
      headers: {
        "content-type": "application/vnd.mapbox-vector-tile",
        "cache-control": "public, max-age=31536000, immutable",
        "x-openactive-cache": "miss",
      },
    });
  }
}
