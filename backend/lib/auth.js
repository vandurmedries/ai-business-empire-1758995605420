import { timingSafeEqual } from "node:crypto";

export function safeEqual(left, right) {
  if (typeof left !== "string" || typeof right !== "string" || !left || !right) return false;
  const leftBuffer = Buffer.from(left, "utf8");
  const rightBuffer = Buffer.from(right, "utf8");
  if (leftBuffer.length !== rightBuffer.length) return false;
  return timingSafeEqual(leftBuffer, rightBuffer);
}

function bearerToken(req) {
  const value = req?.headers?.authorization;
  if (typeof value !== "string" || !value.startsWith("Bearer ")) return "";
  return value.slice(7);
}

export function checkRobloxAuth(req, env = process.env) {
  const configured = env.ROBLOX_SHARED_SECRET;
  if (!configured) return { ok: false, status: 503, error: "roblox_secret_not_configured" };
  const supplied = req?.headers?.["x-roblox-secret"];
  return safeEqual(supplied, configured)
    ? { ok: true }
    : { ok: false, status: 401, error: "unauthorized" };
}

export function checkAdminAuth(req, env = process.env) {
  const configured = env.ADMIN_API_KEY;
  if (!configured) return { ok: false, status: 503, error: "admin_key_not_configured" };
  const supplied = req?.headers?.["x-admin-key"] || bearerToken(req);
  return safeEqual(supplied, configured)
    ? { ok: true }
    : { ok: false, status: 401, error: "unauthorized" };
}

export function checkCronAuth(req, env = process.env) {
  const configured = env.CRON_SECRET;
  if (!configured) return { ok: false, status: 503, error: "cron_secret_not_configured" };
  return safeEqual(bearerToken(req), configured)
    ? { ok: true }
    : { ok: false, status: 401, error: "unauthorized" };
}
