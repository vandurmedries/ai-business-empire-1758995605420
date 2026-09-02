import { randomUUID } from "node:crypto";

export function storageConfigured(env = process.env) {
  return Boolean(env.SUPABASE_URL && env.SUPABASE_SERVICE_ROLE_KEY);
}

function storageHeaders(env, prefer) {
  const headers = {
    apikey: env.SUPABASE_SERVICE_ROLE_KEY,
    authorization: `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
    "content-type": "application/json",
  };
  if (prefer) headers.prefer = prefer;
  return headers;
}

async function supabase(path, { method = "GET", body, prefer, env = process.env } = {}) {
  if (!storageConfigured(env)) throw new Error("storage_not_configured");
  const base = env.SUPABASE_URL.replace(/\/$/, "");
  const response = await fetch(`${base}/rest/v1/${path}`, {
    method,
    headers: storageHeaders(env, prefer),
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  if (!response.ok) {
    const detail = (await response.text()).slice(0, 500);
    throw new Error(`supabase_http_${response.status}:${detail}`);
  }
  if (response.status === 204) return null;
  const text = await response.text();
  return text ? JSON.parse(text) : null;
}

export async function insertEvents(events, env = process.env) {
  if (!storageConfigured(env)) return { persisted: false, count: 0, reason: "storage_not_configured" };
  if (!events.length) return { persisted: true, count: 0 };
  await supabase("roblox_events", {
    method: "POST",
    body: events,
    prefer: "return=minimal",
    env,
  });
  return { persisted: true, count: events.length };
}

export async function fetchEvents(hours = 168, env = process.env) {
  const since = new Date(Date.now() - hours * 3_600_000).toISOString();
  const params = new URLSearchParams({
    select: "session_id,event_name,event_value,occurred_at,context",
    occurred_at: `gte.${since}`,
    order: "occurred_at.asc",
    limit: "10000",
  });
  return (await supabase(`roblox_events?${params.toString()}`, { env })) ?? [];
}

export async function getActiveExperiment(env = process.env) {
  if (!storageConfigured(env)) return null;
  const now = new Date().toISOString();
  const params = new URLSearchParams({
    select: "*",
    status: "eq.active",
    ends_at: `gt.${now}`,
    order: "started_at.desc",
    limit: "1",
  });
  const rows = (await supabase(`roblox_experiments?${params.toString()}`, { env })) ?? [];
  return rows[0] ?? null;
}

export async function deactivateActiveExperiments(env = process.env) {
  if (!storageConfigured(env)) return;
  const params = new URLSearchParams({ status: "eq.active" });
  await supabase(`roblox_experiments?${params.toString()}`, {
    method: "PATCH",
    body: { status: "completed", ended_at: new Date().toISOString() },
    prefer: "return=minimal",
    env,
  });
}

export async function createExperiment(recommendation, env = process.env) {
  const now = new Date();
  const endsAt = new Date(now.getTime() + recommendation.durationDays * 86_400_000);
  const row = {
    id: randomUUID(),
    type: recommendation.type,
    variant: recommendation.variant,
    title: recommendation.title,
    hypothesis: recommendation.hypothesis,
    primary_metric: recommendation.primaryMetric,
    guardrail_metric: recommendation.guardrailMetric,
    minimum_sessions: recommendation.minSessions,
    status: "active",
    started_at: now.toISOString(),
    ends_at: endsAt.toISOString(),
    created_by: "revenue_operator",
  };
  const rows = await supabase("roblox_experiments", {
    method: "POST",
    body: row,
    prefer: "return=representation",
    env,
  });
  return rows?.[0] ?? row;
}

export async function claimOperatorRun(runDate, env = process.env) {
  const row = {
    id: randomUUID(),
    run_date: runDate,
    status: "running",
    started_at: new Date().toISOString(),
  };
  const params = new URLSearchParams({ on_conflict: "run_date" });
  const rows = await supabase(`roblox_operator_runs?${params.toString()}`, {
    method: "POST",
    body: row,
    prefer: "resolution=ignore-duplicates,return=representation",
    env,
  });
  return rows?.[0] ?? null;
}

export async function updateOperatorRun(id, patch, env = process.env) {
  const params = new URLSearchParams({ id: `eq.${id}` });
  await supabase(`roblox_operator_runs?${params.toString()}`, {
    method: "PATCH",
    body: { ...patch, finished_at: new Date().toISOString() },
    prefer: "return=minimal",
    env,
  });
}
