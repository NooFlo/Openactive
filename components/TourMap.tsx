"use client";

import { useEffect, useRef, useState } from "react";
import maplibregl, { type Map as MlMap } from "maplibre-gl";
import type { Tour } from "@/lib/gpx";

const STYLE_URL = "https://tiles.openfreemap.org/styles/liberty";
const DEM_TILES = ["https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png"];

export default function TourMap({ tour }: { tour: Tour | null }) {
  const containerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<MlMap | null>(null);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    if (!containerRef.current || mapRef.current) return;
    const map = new maplibregl.Map({
      container: containerRef.current,
      style: STYLE_URL,
      center: [11.4, 47.27],
      zoom: 12,
      pitch: 65,
      hash: true,
    });
    map.addControl(new maplibregl.NavigationControl({ visualizePitch: true }), "top-right");
    map.addControl(new maplibregl.ScaleControl());
    map.addControl(
      new maplibregl.TerrainControl({
        source: "openactive-dem",
        exaggeration: 1.2,
      })
    );
    map.on("style.load", () => {
      map.addSource("openactive-dem", {
        type: "raster-dem",
        tiles: DEM_TILES,
        encoding: "terrarium",
        tileSize: 256,
        maxzoom: 15,
      });
      setTerrain(map, true);
      setReady(true);
    });
    mapRef.current = map;
    return () => {
      map.remove();
      mapRef.current = null;
    };
  }, []);

  useEffect(() => {
    const map = mapRef.current;
    if (!map || !ready || !tour) return;
    const coords = tour.points.map((p) => [p.lon, p.lat] as [number, number]);
    const onMap = () => {
      const srcId = "tour-line";
      if (map.getSource(srcId)) {
        (map.getSource(srcId) as maplibregl.GeoJSONSource).setData(lineGeoJson(coords));
      } else {
        map.addSource(srcId, { type: "geojson", data: lineGeoJson(coords) });
        map.addLayer({
          id: "tour-casing",
          type: "line",
          source: srcId,
          layout: { "line-join": "round", "line-cap": "round" },
          paint: { "line-color": "#111", "line-width": 7 },
        });
        map.addLayer({
          id: "tour-line",
          type: "line",
          source: srcId,
          layout: { "line-join": "round", "line-cap": "round" },
          paint: { "line-color": "#e0312f", "line-width": 4 },
        });
      }
      const bounds = coords.reduce(
        (b, c) => b.extend(c),
        new maplibregl.LngLatBounds(coords[0], coords[0])
      );
      map.fitBounds(bounds, { padding: 80, pitch: 60, duration: 800 });
    };
    if (map.isStyleLoaded() && map.getSource("openactive-dem")) onMap();
    else map.once("idle", () => setReady(true)), map.on("load", onMap);
    return () => {
      for (const id of ["tour-line", "tour-casing"]) {
        if (map.getLayer(id)) map.removeLayer(id);
      }
      if (map.getSource("tour-line")) map.removeSource("tour-line");
    };
  }, [tour, ready]);

  return <div ref={containerRef} style={{ width: "100%", height: "100%" }} />;
}

function lineGeoJson(coords: [number, number][]) {
  return {
    type: "Feature",
    properties: {},
    geometry: { type: "LineString", coordinates: coords },
  } as GeoJSON.Feature;
}

function setTerrain(map: MlMap, enabled: boolean) {
  try {
    map.setTerrain(enabled ? { source: "openactive-dem", exaggeration: 1.2 } : null);
  } catch {
    /* style may not support terrain yet */
  }
}
