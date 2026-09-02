import { checkAdminAuth } from "../../../lib/auth.js";
import { methodNotAllowed, parseInteger, requestId, sendJson } from "../../../lib/http.js";
import { aggregateEvents } from "../../../lib/metrics.js";
import { fetchEvents, storageConfigured } from "../../../lib/storage.js";

export default async function handler(req, res) {
  const id = requestId(req);
  if (req.method !== "GET") return methodNotAllowed(res, ["GET"], id);
  const auth = checkAdminAuth(req);
  if (!auth.ok) return sendJson(res, auth.status, { ok: false, error: auth.error }, id);
  if (!storageConfigured()) return sendJson(res, 503, { ok: false, error: "storage_not_configured" }, id);

  try {
    const hours = parseInteger(req.query?.hours, 168, 1, 720);
    const events = await fetchEvents(hours);
    return sendJson(res, 200, { ok: true, summary: aggregateEvents(events, hours) }, id);
  } catch {
    return sendJson(res, 500, { ok: false, error: "summary_failed" }, id);
  }
}
