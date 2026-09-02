import { randomUUID } from "node:crypto";

export const ALLOWED_EVENTS = new Set([
  "OnboardingStep",
  "EconomySource",
  "EconomySink",
  "PlayerSessionStarted",
  "CompanyCycleCompleted",
  "CompanyLevelUp",
  "DepartmentUpgraded",
  "MissionStarted",
  "MissionCompleted",
  "MissionExpired",
  "OfferPrompted",
  "PurchaseGranted",
  "PassConfirmed",
  "SubscriptionStatusRefreshed",
]);

const ALLOWED_CONTEXT_KEYS = new Set([
  "step",
  "stepName",
  "transactionType",
  "itemSku",
  "endingBalance",
  "context",
  "gameVersion",
  "customers",
  "level",
  "boosted",
  "department",
  "cost",
  "templateId",
  "reward",
  "source",
  "targetMetric",
  "offerKey",
  "offerKind",
  "gamePassIdConfigured",
]);

function cleanString(value, maxLength) {
  return String(value ?? "").replace(/[\u0000-\u001f\u007f]/g, " ").slice(0, maxLength);
}

function cleanContext(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  const output = {};
  for (const [rawKey, rawValue] of Object.entries(value)) {
    if (Object.keys(output).length >= 10) break;
    const key = cleanString(rawKey, 40);
    if (!ALLOWED_CONTEXT_KEYS.has(key)) continue;
    if (typeof rawValue === "string") output[key] = cleanString(rawValue, 80);
    else if (typeof rawValue === "boolean") output[key] = rawValue;
    else if (typeof rawValue === "number" && Number.isFinite(rawValue)) {
      output[key] = Math.min(1e9, Math.max(-1e9, rawValue));
    }
  }
  return output;
}

export function validateEvent(raw, nowSeconds = Math.floor(Date.now() / 1000)) {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return null;
  const event = cleanString(raw.event, 60);
  if (!ALLOWED_EVENTS.has(event)) return null;
  const sessionId = cleanString(raw.sessionId, 80);
  if (!/^[a-zA-Z0-9-]{8,80}$/.test(sessionId)) return null;
  const occurredAt = Number.parseInt(String(raw.occurredAt), 10);
  if (!Number.isFinite(occurredAt) || occurredAt < nowSeconds - 7 * 86_400 || occurredAt > nowSeconds + 3_600) return null;
  const value = Number(raw.value ?? 1);
  if (!Number.isFinite(value)) return null;

  return {
    event_id: randomUUID(),
    session_id: sessionId,
    event_name: event,
    event_value: Math.min(1e9, Math.max(-1e9, value)),
    occurred_at: new Date(occurredAt * 1000).toISOString(),
    context: cleanContext(raw.context),
    game_version: cleanString(raw.gameVersion, 30),
    place_id: Number.isFinite(Number(raw.placeId)) ? String(raw.placeId) : "",
    universe_id: Number.isFinite(Number(raw.universeId)) ? String(raw.universeId) : "",
  };
}

export function validateEventBatch(payload, maxEvents = 50) {
  if (!payload || typeof payload !== "object" || !Array.isArray(payload.events)) {
    return { valid: [], rejected: 0, error: "events_array_required" };
  }
  const rawEvents = payload.events.slice(0, maxEvents);
  const valid = rawEvents.map((event) => validateEvent(event)).filter(Boolean);
  const overflow = Math.max(0, payload.events.length - maxEvents);
  return { valid, rejected: rawEvents.length - valid.length + overflow, error: null };
}
