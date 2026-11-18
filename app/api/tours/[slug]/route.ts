import { NextResponse } from "next/server";
import fs from "node:fs/promises";
import path from "node:path";
import { currentUser, unauthorized } from "@/lib/auth";

export async function GET(
  _request: Request,
  { params }: { params: Promise<{ slug: string }> }
) {
  const user = await currentUser();
  if (!user) return unauthorized();
  const { slug } = await params;
  const file = path.join(process.cwd(), "data", "tours", `${slug}.json`);
  try {
    const content = await fs.readFile(file, "utf8");
    return NextResponse.json({ tour: JSON.parse(content) });
  } catch {
    return NextResponse.json({ error: "Tour not found" }, { status: 404 });
  }
}
