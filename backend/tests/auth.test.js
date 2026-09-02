import test from "node:test";
import assert from "node:assert/strict";
import { checkAdminAuth, checkCronAuth, checkRobloxAuth, safeEqual } from "../lib/auth.js";

test("constant-time comparison helper handles ordinary edge cases", () => {
  assert.equal(safeEqual("same-secret", "same-secret"), true);
  assert.equal(safeEqual("same-secret", "wrong-secret"), false);
  assert.equal(safeEqual("", ""), false);
});

test("each endpoint uses an independent configured secret", () => {
  const env = { ROBLOX_SHARED_SECRET: "roblox-key", ADMIN_API_KEY: "admin-key", CRON_SECRET: "cron-key" };
  assert.equal(checkRobloxAuth({ headers: { "x-roblox-secret": "roblox-key" } }, env).ok, true);
  assert.equal(checkAdminAuth({ headers: { authorization: "Bearer admin-key" } }, env).ok, true);
  assert.equal(checkCronAuth({ headers: { authorization: "Bearer cron-key" } }, env).ok, true);
  assert.equal(checkCronAuth({ headers: { authorization: "Bearer admin-key" } }, env).ok, false);
});
