import { createHmac, randomBytes, scryptSync, timingSafeEqual } from "node:crypto";
import { cookies } from "next/headers";
import fs from "node:fs/promises";
import path from "node:path";

const DATA_DIR = path.join(process.cwd(), "data");
const USERS_FILE = path.join(DATA_DIR, "users.json");

export interface HouseholdUser {
  username: string;
  displayName: string;
  passwordHash: string;
  salt: string;
  createdAt: string;
}

const SECRET = process.env.OPENACTIVE_SECRET ?? "";

if (!SECRET) {
  throw new Error("OPENACTIVE_SECRET is not set (regenerate with: node scripts/generate-secret.mjs)");
}

export function sign(payload: string): string {
  return createHmac("sha256", SECRET).update(payload).digest("base64url");
}

export function verify(value: string): string | null {
  const [payload, mac] = value.split(".");
  if (!payload || !mac) return null;
  const expected = sign(payload);
  const a = Buffer.from(mac);
  const b = Buffer.from(expected);
  if (a.length !== b.length || !timingSafeEqual(a, b)) return null;
  const [username, expiresAt] = payload.split("|");
  if (!username || !expiresAt) return null;
  if (Date.now() > Number(expiresAt)) return null;
  return username;
}

export function sessionToken(username: string, days = 30): string {
  const expiresAt = Date.now() + days * 24 * 3600 * 1000;
  const payload = `${username}|${expiresAt}`;
  return `${payload}.${sign(payload)}`;
}

export const SESSION_COOKIE = "oa_session";

export async function getUsers(): Promise<HouseholdUser[]> {
  try {
    const raw = await fs.readFile(USERS_FILE, "utf8");
    return JSON.parse(raw);
  } catch {
    return [];
  }
}

export function hashPassword(password: string, salt?: string): { passwordHash: string; salt: string } {
  const s = salt ?? randomBytes(16).toString("hex");
  return { passwordHash: scryptSync(password, s, 64).toString("hex"), salt: s };
}

export function verifyPassword(user: HouseholdUser, password: string): boolean {
  const candidate = scryptSync(password, user.salt, 64).toString("hex");
  const a = Buffer.from(candidate);
  const b = Buffer.from(user.passwordHash);
  return a.length === b.length && timingSafeEqual(a, b);
}

export async function currentUser(): Promise<HouseholdUser | null> {
  const store = await cookies();
  const token = store.get(SESSION_COOKIE)?.value;
  if (!token) return null;
  const username = verify(token);
  if (!username) return null;
  const users = await getUsers();
  return users.find((u) => u.username === username) ?? null;
}

export function unauthorized(): Response {
  return Response.json({ error: "Login required" }, { status: 401 });
}
