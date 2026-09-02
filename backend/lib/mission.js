import { createStructuredResponse } from "./openai.js";

export const MISSION_TEMPLATES = Object.freeze({
  cycle_streak: { metric: "RunCycles", min: 3, max: 12, baseReward: 90 },
  revenue_target: { metric: "EarnCash", min: 150, max: 5000, baseReward: 120 },
  customer_growth: { metric: "GainCustomers", min: 5, max: 250, baseReward: 110 },
  department_upgrade: { metric: "UpgradeDepartment", min: 1, max: 3, baseReward: 140 },
  reputation_lift: { metric: "ImproveReputation", min: 1, max: 10, baseReward: 100 },
});

const TEMPLATE_IDS = Object.keys(MISSION_TEMPLATES);

function clampInteger(value, min, max, fallback) {
  const parsed = Number.parseInt(String(value), 10);
  return Math.min(max, Math.max(min, Number.isFinite(parsed) ? parsed : fallback));
}

export function fallbackMission(company = {}) {
  const completed = clampInteger(company.completedMissions, 0, 1_000_000, 0);
  const level = clampInteger(company.level, 1, 1000, 1);
  let templateId = TEMPLATE_IDS[completed % TEMPLATE_IDS.length];
  if (templateId === "reputation_lift" && Number(company.reputation) >= 95) templateId = "cycle_streak";
  const template = MISSION_TEMPLATES[templateId];

  let targetValue = template.min;
  if (templateId === "cycle_streak") targetValue = 3 + Math.floor(level / 3);
  if (templateId === "revenue_target") targetValue = 150 + level * 75;
  if (templateId === "customer_growth") targetValue = 5 + level * 3;
  if (templateId === "department_upgrade") targetValue = 1 + Math.floor(level / 10);
  if (templateId === "reputation_lift") targetValue = 2 + Math.floor(level / 8);

  return {
    templateId,
    targetValue: clampInteger(targetValue, template.min, template.max, template.min),
    rewardCash: clampInteger(template.baseReward + level * 15, 25, 5000, template.baseReward),
    durationMinutes: 240,
    selectionSource: "deterministic_fallback",
  };
}

export function validateMissionSelection(candidate, company = {}) {
  if (!candidate || typeof candidate !== "object") return null;
  const template = MISSION_TEMPLATES[candidate.templateId];
  if (!template) return null;
  if (candidate.templateId === "reputation_lift" && Number(company.reputation) >= 99) return null;
  return {
    templateId: candidate.templateId,
    targetValue: clampInteger(candidate.targetValue, template.min, template.max, template.min),
    rewardCash: clampInteger(candidate.rewardCash, 25, 5000, template.baseReward),
    durationMinutes: clampInteger(candidate.durationMinutes, 10, 1440, 240),
    selectionSource: "openai_curated",
  };
}

const missionSchema = {
  type: "object",
  additionalProperties: false,
  required: ["templateId", "targetValue", "rewardCash", "durationMinutes"],
  properties: {
    templateId: { type: "string", enum: TEMPLATE_IDS },
    targetValue: { type: "integer" },
    rewardCash: { type: "integer" },
    durationMinutes: { type: "integer" },
  },
};

export async function selectMission({ company = {}, context = {}, env = process.env }) {
  const fallback = fallbackMission(company);
  try {
    const candidate = await createStructuredResponse({
      name: "roblox_curated_mission",
      schema: missionSchema,
      env,
      instructions: [
        "Choose exactly one mission from the supplied curated template IDs.",
        "Optimize long-term player comprehension, retention, and fair progression.",
        "Do not introduce purchases, pricing, urgency, chance rewards, external links, or user-generated text.",
        "Keep the target achievable within one ordinary play session unless the context clearly supports a longer goal.",
      ].join(" "),
      input: { company, context, templates: MISSION_TEMPLATES, fallback },
    });
    return validateMissionSelection(candidate, company) ?? fallback;
  } catch (error) {
    console.warn("Mission AI fallback:", error instanceof Error ? error.message : String(error));
    return fallback;
  }
}
