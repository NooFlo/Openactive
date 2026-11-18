import { NextResponse } from "next/server";
import fs from "node:fs/promises";
import path from "node:path";

export async function GET(
  _request: Request,
  { params }: { params: Promise<{ slug: string }> }
) {
  const { slug } = await params;
  const file = path.join(process.cwd(), "data", "tours", `${slug}.json`);
  try {
    const content = await fs.readFile(file, "utf8");
    return NextResponse.json({ tour: JSON.parse(content) });
  } catch {
    return NextResponse.json({ error: "Tour not found" }, { status: 404 });
  }
}
