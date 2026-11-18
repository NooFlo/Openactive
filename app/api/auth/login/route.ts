import { NextResponse } from "next/server";
import { cookies } from "next/headers";
import { getUsers, sessionToken, SESSION_COOKIE, verifyPassword } from "@/lib/auth";

export async function POST(request: Request) {
  let body: { username?: string; password?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: "Invalid JSON body" }, { status: 400 });
  }
  const username = body.username?.trim() ?? "";
  const password = body.password ?? "";
  if (!username || !password) {
    return NextResponse.json({ error: "Username and password required" }, { status: 400 });
  }
  const users = await getUsers();
  const user = users.find((u) => u.username === username);
  if (!user || !verifyPassword(user, password)) {
    return NextResponse.json({ error: "Invalid credentials" }, { status: 401 });
  }
  const store = await cookies();
  store.set(SESSION_COOKIE, sessionToken(user.username), {
    httpOnly: true,
    sameSite: "lax",
    path: "/",
    maxAge: 30 * 24 * 3600,
  });
  return NextResponse.json({ user: { username: user.username, displayName: user.displayName } });
}

export async function DELETE() {
  const store = await cookies();
  store.delete(SESSION_COOKIE);
  return NextResponse.json({ ok: true });
}
