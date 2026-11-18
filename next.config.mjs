import fs from "node:fs";
import path from "node:path";
import { randomBytes } from "node:crypto";

const secretFile = path.join(process.cwd(), "data", ".secret");
let secret;
try {
  secret = fs.readFileSync(secretFile, "utf8").trim();
} catch {
  fs.mkdirSync(path.dirname(secretFile), { recursive: true });
  secret = randomBytes(48).toString("base64url");
  fs.writeFileSync(secretFile, secret, { mode: 0o600 });
}

/** @type {import('next').NextConfig} */
const nextConfig = {
  env: { OPENACTIVE_SECRET: secret },
};

export default nextConfig;
