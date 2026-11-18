"use client";

import { useState } from "react";

interface TourSummary {
  slug: string;
  title: string;
  stats: {
    distanceKm: number;
    ascentM: number;
    descentM: number;
    minEleM: number | null;
    maxEleM: number | null;
    points: number;
  };
}

export default function IngestPanel({ onIngested }: { onIngested: (slug: string) => void }) {
  const [url, setUrl] = useState("");
  const [gpx, setGpx] = useState("");
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [mode, setMode] = useState<"url" | "paste">("url");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [lastTour, setLastTour] = useState<TourSummary | null>(null);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    setLastTour(null);
    try {
      const res = await fetch("/api/tours", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(
          mode === "url"
            ? { url }
            : { gpx, title, description, sourceUrl: url || null }
        ),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error ?? `Request failed (${res.status})`);
      setLastTour(data.tour);
      setUrl("");
      setGpx("");
      setTitle("");
      setDescription("");
      onIngested(data.tour.slug);
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <form onSubmit={submit} className="panel">
      <h2>Ingest a tour</h2>
      <div className="tabs">
        <button type="button" className={mode === "url" ? "active" : ""} onClick={() => setMode("url")}>
          From URL
        </button>
        <button type="button" className={mode === "paste" ? "active" : ""} onClick={() => setMode("paste")}>
          Paste GPX
        </button>
      </div>

      {mode === "url" ? (
        <label>
          Tourism page, tour detail page, or direct .gpx URL
          <input
            type="url"
            required
            placeholder="https://www.tourismusverband.at/tour/hike-example"
            value={url}
            onChange={(e) => setUrl(e.target.value)}
          />
        </label>
      ) : (
        <>
          <label>
            Title
            <input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="Tour title" />
          </label>
          <label>
            Description (optional)
            <textarea
              rows={3}
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              placeholder="Short description"
            />
          </label>
          <label>
            GPX XML
            <textarea
              rows={6}
              required
              value={gpx}
              onChange={(e) => setGpx(e.target.value)}
              placeholder={"<?xml version=\"1.0\"?><gpx …>"}
            />
          </label>
        </>
      )}

      <button type="submit" disabled={busy}>
        {busy ? "Ingesting…" : "Ingest tour"}
      </button>

      {error && <p className="error">{error}</p>}
      {lastTour && (
        <p className="success">
          ✓ {lastTour.title} — {lastTour.stats.distanceKm} km, ↑{lastTour.stats.ascentM} m
        </p>
      )}
    </form>
  );
}
