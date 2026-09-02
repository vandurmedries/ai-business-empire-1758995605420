import { checkRobloxAuth } from "../../lib/auth.js";
import { experimentToLiveConfig } from "../../lib/experiments.js";
import { methodNotAllowed, requestId, sendJson } from "../../lib/http.js";
import { getActiveExperiment } from "../../lib/storage.js";

export default async function handler(req, res) {
  const id = requestId(req);
  if (req.method !== "GET") return methodNotAllowed(res, ["GET"], id);
  const auth = checkRobloxAuth(req);
  if (!auth.ok) return sendJson(res, auth.status, { ok: false, error: auth.error }, id);

  try {
    const experiment = await getActiveExperiment();
    return sendJson(res, 200, {
      ok: true,
      config: experimentToLiveConfig(experiment),
      hardPolicy: {
        allowExternalPurchaseLinks: false,
        allowPaidRandomRewards: false,
        allowAutonomousPriceChanges: false,
        allowAutonomousPublishing: false,
        allowAutonomousAdSpend: false,
      },
    }, id);
  } catch {
    return sendJson(res, 200, {
      ok: true,
      config: experimentToLiveConfig(null),
      degraded: true,
      hardPolicy: {
        allowExternalPurchaseLinks: false,
        allowPaidRandomRewards: false,
        allowAutonomousPriceChanges: false,
        allowAutonomousPublishing: false,
        allowAutonomousAdSpend: false,
      },
    }, id);
  }
}
