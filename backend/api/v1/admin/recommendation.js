import { checkAdminAuth } from "../../../lib/auth.js";
import { recommendExperiment } from "../../../lib/experiments.js";
import { methodNotAllowed, requestId, sendJson } from "../../../lib/http.js";
import { aggregateEvents } from "../../../lib/metrics.js";
import { fetchEvents, getActiveExperiment, storageConfigured } from "../../../lib/storage.js";

export default async function handler(req, res) {
  const id = requestId(req);
  if (req.method !== "POST") return methodNotAllowed(res, ["POST"], id);
  const auth = checkAdminAuth(req);
  if (!auth.ok) return sendJson(res, auth.status, { ok: false, error: auth.error }, id);
  if (!storageConfigured()) return sendJson(res, 503, { ok: false, error: "storage_not_configured" }, id);

  try {
    const events = await fetchEvents(168);
    const summary = aggregateEvents(events, 168);
    const activeExperiment = await getActiveExperiment();
    const recommendation = await recommendExperiment(summary, activeExperiment);
    return sendJson(res, 200, {
      ok: true,
      recommendation,
      summary,
      activated: false,
      note: "This endpoint recommends only. The daily operator can activate a safe experiment when explicitly enabled.",
    }, id);
  } catch {
    return sendJson(res, 500, { ok: false, error: "recommendation_failed" }, id);
  }
}
