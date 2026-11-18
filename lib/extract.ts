import * as cheerio from "cheerio";

export interface ExtractionResult {
  title: string | null;
  description: string | null;
  gpxUrls: string[];
  image: string | null;
}

function absolutize(base: string, href: string): string | null {
  try {
    return new URL(href, base).toString();
  } catch {
    return null;
  }
}

function collectJsonLd($: cheerio.CheerioAPI): Record<string, unknown>[] {
  const out: Record<string, unknown>[] = [];
  $('script[type="application/ld+json"]').each((_i, el) => {
    try {
      const parsed = JSON.parse($(el).contents().text());
      const arr = Array.isArray(parsed) ? parsed : [parsed];
      out.push(...arr);
    } catch {
      /* ignore malformed blocks */
    }
  });
  return out;
}

function fromJsonLd(nodes: Record<string, unknown>[]): { title: string | null; description: string | null; image: string | null } {
  let title: string | null = null;
  let description: string | null = null;
  let image: string | null = null;
  const types = new Set(["TouristTrip", "HikingRoute", "Route", "Place", "Article"]);
  for (const node of nodes) {
    const type = (node["@type"] as string) ?? "";
    if (!types.has(type)) continue;
    if (!title && typeof node["name"] === "string") title = node["name"];
    if (!description && typeof node["description"] === "string") description = node["description"];
    if (!image && typeof node["image"] === "string") image = node["image"];
    if (title && description && image) break;
  }
  return { title, description, image };
}

export async function extractFromHtml(html: string, baseUrl: string): Promise<ExtractionResult> {
  const $ = cheerio.load(html);
  const gpxUrls = new Set<string>();

  $('a[href]').each((_i, el) => {
    const href = $(el).attr("href");
    if (!href) return;
    const lower = href.toLowerCase().split("?")[0];
    if (lower.endsWith(".gpx") || lower.endsWith(".gpx.gz")) {
      const abs = absolutize(baseUrl, href);
      if (abs) gpxUrls.add(abs);
    }
  });

  const jsonLd = collectJsonLd($);
  const fromLd = fromJsonLd(jsonLd);

  const metaTitle = $('meta[property="og:title"]').attr("content") ?? $("title").text().trim() ?? null;
  const metaDescription =
    $('meta[property="og:description"]').attr("content") ??
    $('meta[name="description"]').attr("content") ??
    null;
  const ogImage = $('meta[property="og:image"]').attr("content") ?? null;

  let articleText: string | null = null;
  const container = $("article").length
    ? $("article")
    : $('div[itemprop="description"], .tour-description, #description').first();
  if (container.length) {
    articleText = container.text().replace(/\s+/g, " ").trim();
  }

  return {
    title: fromLd.title ?? (metaTitle || null),
    description: fromLd.description ?? metaDescription ?? (articleText || null),
    gpxUrls: [...gpxUrls],
    image: fromLd.image ?? ogImage,
  };
}

export async function fetchText(url: string, timeoutMs = 15000): Promise<string> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(url, {
      signal: controller.signal,
      headers: {
        "user-agent": "Mozilla/5.0 (compatible; OpenactiveBot/0.1; +https://github.com/NooFlo/Openactive)",
        accept: "text/html,application/gpx+xml,application/xml,text/plain,*/*",
      },
    });
    if (!res.ok) throw new Error(`Fetch failed: ${res.status} ${res.statusText}`);
    return await res.text();
  } finally {
    clearTimeout(timer);
  }
}
