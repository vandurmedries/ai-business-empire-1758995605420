import test from "node:test";
import assert from "node:assert/strict";
import { aggregateEvents } from "../lib/metrics.js";

test("metrics use unique sessions and label purchase signals honestly", () => {
  const events = [
    { session_id: "a", event_name: "PlayerSessionStarted" },
    { session_id: "b", event_name: "PlayerSessionStarted" },
    { session_id: "a", event_name: "CompanyCycleCompleted" },
    { session_id: "a", event_name: "CompanyCycleCompleted" },
    { session_id: "a", event_name: "MissionStarted" },
    { session_id: "a", event_name: "MissionCompleted" },
    { session_id: "a", event_name: "OfferPrompted" },
    { session_id: "a", event_name: "PurchaseGranted" },
  ];
  const summary = aggregateEvents(events, 24);
  assert.equal(summary.uniqueSessions, 2);
  assert.equal(summary.rates.coreLoopActivation, 0.5);
  assert.equal(summary.rates.missionCompletion, 1);
  assert.equal(summary.confirmedPurchaseSignals.total, 1);
  assert.match(summary.confirmedPurchaseSignals.caveat, /not booked Robux revenue/i);
});
