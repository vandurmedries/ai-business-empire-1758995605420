import { checkCronAuth } from "../../lib/auth.js";
import { methodNotAllowed, requestId, sendJson } from "../../lib/http.js";
import { runDailyOperator } from "../../lib/operator.js";

export default async function handler(req, res) {
  const id = requestId(req);
  if (req.method !== "GET" && req.method !== "POST") return methodNotAllowed(res, ["GET", "POST"], id);
  const auth = checkCronAuth(req);
  if (!auth.ok) return sendJson(res, auth.status, { ok: false, error: auth.error }, id);

  try {
    const result = await runDailyOperator();
    return sendJson(res, 200, result, id);
  } catch {
    return sendJson(res, 500, { ok: false, error: "operator_failed" }, id);
  }
}
