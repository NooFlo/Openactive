"use client";

import { useCallback, useEffect, useState } from "react";
import IngestPanel from "@/components/IngestPanel";
import TourMap from "@/components/TourMap";
import type { Tour } from "@/lib/gpx";

export default function Home() {
  const [tours, setTours] = useState<Pick<Tour, "preparedAt" | "slug" | "title">[]>([]);
  const [selected, setSelected] = useState<Tour | null>(null);
  const [prepareMsg, setPrepareMsg] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const refresh = useCallback(async () => {
    const res = await fetch("/api/tours");
    if (res.status === 401) {
      window.location.href = "/login";
      return;
    }
    if (!res.ok) return;
    const { tours } = (await res.json()) as {
      tours: Pick<Tour, "preparedAt" | "slug" | "title">[];
    };
    setTours(tours);
  }, []);

  useEffect(() => {
    refresh();
  }, [refresh]);

  async function select(slug: string) {
    const res = await fetch(`/api/tours/${slug}`);
    if (res.status === 401) {
      window.location.href = "/login";
      return;
    }
    if (!res.ok) return;
    const { tour } = (await res.json()) as { tour: Tour };
    setSelected(tour);
    setPrepareMsg(null);
  }

  async function prepare() {
    if (!selected) return;
    setBusy(true);
    setPrepareMsg(null);
    try {
      const res = await fetch(`/api/tours/${selected.slug}/prepare`, { method: "POST" });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error ?? "Prepare failed");
      setPrepareMsg(
        `✓ ${data.bundle.tileCount} map tiles (~${data.bundle.estSizeMb} MB) — mobile can now download this trip offline.`
      );
      refresh();
    } catch (err) {
      setPrepareMsg(`✗ ${(err as Error).message}`);
    } finally {
      setBusy(false);
    }
  }

  return (
    <main style={{ display: "flex", height: "100vh" }}>
      <aside style={{ width: 380, padding: 16, overflowY: "auto", borderRight: "1px solid #2d333b" }}>
        <h1>⛰ Openactive</h1>
        <p className="muted">Open source planning for hiking &amp; mountain biking.</p>
        <IngestPanel onIngested={refresh} />
        {selected?.preparedAt && (
          <p className="success">Trip prepared — ready for “Download prepared trip” on mobile.</p>
        )}
        <section>
          <h2>Tours</h2>
          {tours.length === 0 && <p className="muted">No tours yet. Ingest one above.</p>}
          <ul className="tour-list">
            {tours.map((t) => (
              <li key={t.slug}>
                <button onClick={() => select(t.slug)}>
                  {t.title}
                  {t.preparedAt ? " ✅" : ""}
                </button>
              </li>
            ))}
          </ul>
        </section>
        {selected && (
          <section className="selected-tour">
            <h2>{selected.title}</h2>
            <p className="muted">
              {selected.stats.distanceKm} km · ↑ {selected.stats.ascentM} m · ↓ {selected.stats.descentM} m ·{" "}
              {selected.stats.maxEleM ? `max ${selected.stats.maxEleM} m` : "no elevation data"}
            </p>
            {selected.description && <p>{selected.description}</p>}
            {selected.sourceUrl && (
              <>
                <a href={selected.sourceUrl} target="_blank" rel="noreferrer">
                  Source
                </a>{" "}
              </>
            )}
            <br />
            <button className="prepare-btn" onClick={prepare} disabled={busy}>
              {busy
                ? "Preparing…"
                : selected.preparedAt
                  ? "Re-prepare trip"
                  : "Prepare trip for mobile"}
            </button>
            {prepareMsg && <p className="muted">{prepareMsg}</p>}
          </section>
        )}
        <button
          className="logout"
          onClick={async () => {
            await fetch("/api/auth/login", { method: "DELETE" });
            window.location.href = "/login";
          }}
        >
          Sign out
        </button>
      </aside>
      <div style={{ flex: 1 }}>
        <TourMap tour={selected} />
      </div>
    </main>
  );
}
