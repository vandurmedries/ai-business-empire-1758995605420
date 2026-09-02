import test from "node:test";
import assert from "node:assert/strict";
import healthHandler from "../api/health.js";
import configHandler from "../api/v1/config.js";
import eventsHandler from "../api/v1/events.js";
import missionHandler from "../api/v1/mission.js";

function responseMock() {
  return {
    statusCode: 0,
    headers: {},
    body: "",
    setHeader(name, value) {
      this.headers[String(name).toLowerCase()] = value;
    },
    end(value = "") {
      this.body = String(value);
    },
  };
}

async function call(handler, req) {
  const res = responseMock();
  await handler(req, res);
  return { status: res.statusCode, headers: res.headers, body: JSON.parse(res.body) };
}

test("health endpoint exposes readiness booleans without secrets", async () => {
  const result = await call(healthHandler, { method: "GET", headers: {} });
  assert.equal(result.status, 200);
  assert.equal(result.body.ok, true);
  assert.equal(JSON.stringify(result.body).includes("ROBLOX_SHARED_SECRET"), false);
});

test("Roblox endpoints reject unauthenticated requests", async () => {
  const old = process.env.ROBLOX_SHARED_SECRET;
  process.env.ROBLOX_SHARED_SECRET = "test-roblox-secret";
  try {
    const result = await call(missionHandler, { method: "POST", headers: {}, body: {} });
    assert.equal(result.status, 401);
    assert.equal(result.body.error, "unauthorized");
  } finally {
    if (old === undefined) delete process.env.ROBLOX_SHARED_SECRET;
    else process.env.ROBLOX_SHARED_SECRET = old;
  }
});

test("mission and config endpoints work with deterministic degradation", async () => {
  const previous = {
    roblox: process.env.ROBLOX_SHARED_SECRET,
    openai: process.env.OPENAI_API_KEY,
    supabase: process.env.SUPABASE_URL,
    service: process.env.SUPABASE_SERVICE_ROLE_KEY,
  };
  process.env.ROBLOX_SHARED_SECRET = "test-roblox-secret";
  delete process.env.OPENAI_API_KEY;
  delete process.env.SUPABASE_URL;
  delete process.env.SUPABASE_SERVICE_ROLE_KEY;
  try {
    const headers = { "x-roblox-secret": "test-roblox-secret" };
    const mission = await call(missionHandler, {
      method: "POST",
      headers,
      body: { company: { level: 3, reputation: 50, completedMissions: 0 }, context: {} },
    });
    assert.equal(mission.status, 200);
    assert.equal(mission.body.mission.templateId, "cycle_streak");

    const config = await call(configHandler, { method: "GET", headers });
    assert.equal(config.status, 200);
    assert.equal(config.body.config.variant, "control");
    assert.equal(config.body.hardPolicy.allowAutonomousPriceChanges, false);
  } finally {
    if (previous.roblox === undefined) delete process.env.ROBLOX_SHARED_SECRET;
    else process.env.ROBLOX_SHARED_SECRET = previous.roblox;
    if (previous.openai === undefined) delete process.env.OPENAI_API_KEY;
    else process.env.OPENAI_API_KEY = previous.openai;
    if (previous.supabase === undefined) delete process.env.SUPABASE_URL;
    else process.env.SUPABASE_URL = previous.supabase;
    if (previous.service === undefined) delete process.env.SUPABASE_SERVICE_ROLE_KEY;
    else process.env.SUPABASE_SERVICE_ROLE_KEY = previous.service;
  }
});

test("event endpoint accepts a bounded private batch when storage is optional", async () => {
  const oldSecret = process.env.ROBLOX_SHARED_SECRET;
  const oldUrl = process.env.SUPABASE_URL;
  const oldKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  process.env.ROBLOX_SHARED_SECRET = "test-roblox-secret";
  delete process.env.SUPABASE_URL;
  delete process.env.SUPABASE_SERVICE_ROLE_KEY;
  try {
    const result = await call(eventsHandler, {
      method: "POST",
      headers: { "x-roblox-secret": "test-roblox-secret" },
      body: {
        events: [
          {
            sessionId: "session-12345678",
            event: "PlayerSessionStarted",
            value: 1,
            occurredAt: Math.floor(Date.now() / 1000),
            context: { gameVersion: "0.1.0" },
          },
        ],
      },
    });
    assert.equal(result.status, 202);
    assert.equal(result.body.accepted, 1);
    assert.equal(result.body.persisted, false);
  } finally {
    if (oldSecret === undefined) delete process.env.ROBLOX_SHARED_SECRET;
    else process.env.ROBLOX_SHARED_SECRET = oldSecret;
    if (oldUrl === undefined) delete process.env.SUPABASE_URL;
    else process.env.SUPABASE_URL = oldUrl;
    if (oldKey === undefined) delete process.env.SUPABASE_SERVICE_ROLE_KEY;
    else process.env.SUPABASE_SERVICE_ROLE_KEY = oldKey;
  }
});
