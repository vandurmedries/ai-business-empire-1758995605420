import { checkRobloxAuth } from "../../lib/auth.js";
import { methodNotAllowed, readJson, requestId, sendJson } from "../../lib/http.js";
import { selectMission } from "../../lib/mission.js";

function cleanCompany(raw) {
  const company = raw && typeof raw === "object" ? raw : {};
  const number = (value, fallback, min, max) => {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? Math.min(max, Math.max(min, parsed)) : fallback;
  };
  return {
    level: Math.floor(number(company.level, 1, 1, 1000)),
    cash: Math.floor(number(company.cash, 0, 0, 1e12)),
    lifetimeRevenue: Math.floor(number(company.lifetimeRevenue, 0, 0, 1e15)),
    customers: Math.floor(number(company.customers, 0, 0, 1e12)),
    reputation: Math.floor(number(company.reputation, 50, 0, 100)),
    completedMissions: Math.floor(number(company.completedMissions, 0, 0, 1e9)),
    departments: {
      Product: Math.floor(number(company.departments?.Product, 1, 1, 100)),
      Marketing: Math.floor(number(company.departments?.Marketing, 1, 1, 100)),
      Sales: Math.floor(number(company.departments?.Sales, 1, 1, 100)),
    },
  };
}

function cleanContext(raw) {
  const context = raw && typeof raw === "object" ? raw : {};
  return {
    experimentId: String(context.experimentId || "control").slice(0, 80),
    variant: String(context.variant || "control").slice(0, 40),
    missionPromptVariant: String(context.missionPromptVariant || "progress_first").slice(0, 40),
  };
}

export default async function handler(req, res) {
  const id = requestId(req);
  if (req.method !== "POST") return methodNotAllowed(res, ["POST"], id);
  const auth = checkRobloxAuth(req);
  if (!auth.ok) return sendJson(res, auth.status, { ok: false, error: auth.error }, id);

  try {
    const payload = await readJson(req, 32_000);
    const mission = await selectMission({
      company: cleanCompany(payload.company),
      context: cleanContext(payload.context),
    });
    return sendJson(res, 200, { ok: true, mission }, id);
  } catch (error) {
    const code = error instanceof SyntaxError ? "invalid_json" : error?.message === "body_too_large" ? "body_too_large" : "mission_generation_failed";
    return sendJson(res, code === "mission_generation_failed" ? 500 : 400, { ok: false, error: code }, id);
  }
}
