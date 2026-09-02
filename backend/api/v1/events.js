import { checkRobloxAuth } from "../../lib/auth.js";
import { validateEventBatch } from "../../lib/events.js";
import { methodNotAllowed, readJson, requestId, sendJson } from "../../lib/http.js";
import { insertEvents } from "../../lib/storage.js";

export default async function handler(req, res) {
  const id = requestId(req);
  if (req.method !== "POST") return methodNotAllowed(res, ["POST"], id);
  const auth = checkRobloxAuth(req);
  if (!auth.ok) return sendJson(res, auth.status, { ok: false, error: auth.error }, id);

  try {
    const payload = await readJson(req, 128_000);
    const batch = validateEventBatch(payload, 50);
    if (batch.error) return sendJson(res, 400, { ok: false, error: batch.error }, id);
    const persistence = await insertEvents(batch.valid);
    return sendJson(res, persistence.persisted ? 200 : 202, {
      ok: true,
      accepted: batch.valid.length,
      rejected: batch.rejected,
      persisted: persistence.persisted,
      persistenceReason: persistence.reason ?? null,
      privacy: "No Roblox user ID, username, email, chat text, or IP address is stored by this endpoint.",
    }, id);
  } catch (error) {
    const code = error instanceof SyntaxError ? "invalid_json" : error?.message === "body_too_large" ? "body_too_large" : "event_ingestion_failed";
    return sendJson(res, code === "event_ingestion_failed" ? 500 : 400, { ok: false, error: code }, id);
  }
}
