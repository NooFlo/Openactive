import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Openactive — outdoor planning & navigation",
  description:
    "Open source planning web app for hiking and mountain biking: 3D terrain maps, GPX ingestion from tourism sites, and tour planning.",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
