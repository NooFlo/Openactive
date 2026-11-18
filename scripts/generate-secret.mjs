import { randomBytes } from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const file = path.join(process.cwd(), "data", ".secret");
fs.mkdirSync(path.dirname(file), { recursive: true });
try {
  fs.accessSync(file);
  console.log("Secret already exists:", file);
} catch {
  const secret = randomBytes(48).toString("base64url");
  fs.writeFileSync(file, secret, { mode: 0o600 });
  fs.writeFileSync(`${file}.example`, "keep this file secret; it is gitignored\n", { mode: 0o600 });
  console.log("Generated:", file);
}
