import test from "node:test";
import assert from "node:assert/strict";
import { validateEvent, validateEventBatch } from "../lib/events.js";

const now = Math.floor(Date.now() / 1000);

test("valid events retain only approved privacy-minimized context", () => {
  const event = validateEvent(
    {
      sessionId: "12345678-abcd",
      event: "CompanyCycleCompleted",
      value: 120,
      occurredAt: now,
      context: {
        customers: 4,
        level: 2,
        username: "must-not-survive",
        email: "must-not-survive@example.com",
      },
      gameVersion: "0.1.0",
      placeId: 123,
      universeId: 456,
    },
    now,
  );
  assert.ok(event);
  assert.equal(event.context.customers, 4);
  assert.equal(event.context.level, 2);
  assert.equal(event.context.username, undefined);
  assert.equal(event.context.email, undefined);
});

test("invalid events and overflow are rejected", () => {
  const raw = Array.from({ length: 55 }, (_, index) => ({
    sessionId: `session-${index}-abcd`,
    event: index === 0 ? "UnknownEvent" : "PlayerSessionStarted",
    value: 1,
    occurredAt: now,
    context: {},
  }));
  const batch = validateEventBatch({ events: raw }, 50);
  assert.equal(batch.valid.length, 49);
  assert.equal(batch.rejected, 6);
});
