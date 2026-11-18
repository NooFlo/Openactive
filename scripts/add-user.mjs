import { scryptSync, randomBytes } from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const [, , username, password, displayName] = process.argv;
if (!username || !password) {
  console.error("Usage: node scripts/add-user.mjs <username> <password> [displayName]");
  process.exit(1);
}

const file = path.join(process.cwd(), "data", "users.json");
let users = [];
try {
  users = JSON.parse(fs.readFileSync(file, "utf8"));
} catch {
  /* first user */
}
if (users.some((u) => u.username === username)) {
  console.error(`User "${username}" already exists`);
  process.exit(1);
}
const salt = randomBytes(16).toString("hex");
users.push({
  username,
  displayName: displayName || username,
  passwordHash: scryptSync(password, salt, 64).toString("hex"),
  salt,
  createdAt: new Date().toISOString(),
});
fs.mkdirSync(path.dirname(file), { recursive: true });
fs.writeFileSync(file, JSON.stringify(users, null, 2));
console.log(`Added household user "${username}" (${file})`);
