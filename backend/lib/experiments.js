import { createStructuredResponse } from "./openai.js";

export const SAFE_EXPERIMENT_TYPES = Object.freeze({
  tutorial_hint: ["step_by_step", "benefit_first", "goal_first"],
  mission_prompt: ["progress_first", "reward_first", "challenge_first"],
  value_demo: ["enabled", "disabled"],
  cycle_reward: ["control", "plus_5_percent", "minus_5_percent"],
  cycle_pacing: ["control", "faster_10_percent", "slower_10_percent"],
  shop_order: ["subscription_first", "automation_first", "consumables_first"],
});

const TYPES = Object.keys(SAFE_EXPERIMENT_TYPES);

export function validateExperiment(candidate) {
  if (!candidate || typeof candidate !== "object") return null;
  const type = String(candidate.type || "");
  const variant = String(candidate.variant || "");
  if (!SAFE_EXPERIMENT_TYPES[type]?.includes(variant)) return null;

  const durationDays = Math.min(21, Math.max(3, Number.parseInt(String(candidate.durationDays), 10) || 7));
  const minSessions = Math.min(100_000, Math.max(30, Number.parseInt(String(candidate.minSessions), 10) || 100));
  return {
    type,
    variant,
    title: String(candidate.title || `${type}: ${variant}`).slice(0, 120),
    hypothesis: String(candidate.hypothesis || "This safe presentation change can improve player comprehension.").slice(0, 500),
    primaryMetric: String(candidate.primaryMetric || "coreLoopActivation").slice(0, 80),
    guardrailMetric: String(candidate.guardrailMetric || "missionCompletion").slice(0, 80),
    durationDays,
    minSessions,
  };
}

export function deterministicRecommendation(summary) {
  const sessions = summary?.uniqueSessions ?? 0;
  const rates = summary?.rates ?? {};
  if (sessions < 30) {
    return validateExperiment({
      type: "tutorial_hint",
      variant: "goal_first",
      title: "Clarify the first-session goal",
      hypothesis: "A concise goal-first hint can increase first-cycle completion without changing monetization.",
      primaryMetric: "coreLoopActivation",
      guardrailMetric: "missionCompletion",
      durationDays: 7,
      minSessions: 50,
    });
  }
  if ((rates.coreLoopActivation ?? 0) < 0.6) {
    return validateExperiment({
      type: "tutorial_hint",
      variant: "benefit_first",
      title: "Explain the value of the core loop",
      hypothesis: "Showing what a cycle produces before the action can improve core-loop activation.",
      primaryMetric: "coreLoopActivation",
      guardrailMetric: "offerEngagement",
      durationDays: 7,
      minSessions: 100,
    });
  }
  if ((rates.missionCompletion ?? 0) < 0.45) {
    return validateExperiment({
      type: "mission_prompt",
      variant: "progress_first",
      title: "Make mission progress clearer",
      hypothesis: "Progress-first mission framing can improve mission completion and return intent.",
      primaryMetric: "missionCompletion",
      guardrailMetric: "coreLoopActivation",
      durationDays: 7,
      minSessions: 100,
    });
  }
  if ((rates.offerEngagement ?? 0) < 0.15) {
    return validateExperiment({
      type: "value_demo",
      variant: "enabled",
      title: "Demonstrate upgrade value before checkout",
      hypothesis: "A clear value demonstration can improve informed offer engagement without urgency or price changes.",
      primaryMetric: "offerEngagement",
      guardrailMetric: "missionCompletion",
      durationDays: 10,
      minSessions: 150,
    });
  }
  return validateExperiment({
    type: "shop_order",
    variant: "automation_first",
    title: "Lead with the durable automation benefit",
    hypothesis: "Leading with a permanent utility benefit can improve qualified offer engagement.",
    primaryMetric: "offerToConfirmedPurchase",
    guardrailMetric: "coreLoopActivation",
    durationDays: 10,
    minSessions: 200,
  });
}

const schema = {
  type: "object",
  additionalProperties: false,
  required: ["type", "variant", "title", "hypothesis", "primaryMetric", "guardrailMetric", "durationDays", "minSessions"],
  properties: {
    type: { type: "string", enum: TYPES },
    variant: { type: "string" },
    title: { type: "string" },
    hypothesis: { type: "string" },
    primaryMetric: { type: "string" },
    guardrailMetric: { type: "string" },
    durationDays: { type: "integer" },
    minSessions: { type: "integer" },
  },
};

export async function recommendExperiment(summary, activeExperiment, env = process.env) {
  const fallback = deterministicRecommendation(summary);
  try {
    const candidate = await createStructuredResponse({
      name: "roblox_safe_revenue_experiment",
      schema,
      env,
      instructions: [
        "Select one experiment only from SAFE_EXPERIMENT_TYPES and its exact allowed variants.",
        "Optimize sustainable 90-day creator revenue through comprehension, retention, and informed conversion.",
        "Never recommend pricing changes, off-platform checkout, paid randomness, manipulative urgency, ad spend, publishing, financial transfers, or targeting based on sensitive or personal data.",
        "Confirmed purchase events are signals, not booked revenue; do not claim revenue amounts.",
      ].join(" "),
      input: { summary, activeExperiment, safeOptions: SAFE_EXPERIMENT_TYPES, fallback },
    });
    return validateExperiment(candidate) ?? fallback;
  } catch (error) {
    console.warn("Experiment AI fallback:", error instanceof Error ? error.message : String(error));
    return fallback;
  }
}

export function experimentToLiveConfig(experiment) {
  const config = {
    experimentId: experiment?.id || "control",
    variant: experiment?.variant || "control",
    tutorialHintVariant: "step_by_step",
    missionPromptVariant: "progress_first",
    valueDemoEnabled: true,
    cycleRewardMultiplier: 1,
    cyclePacingMultiplier: 1,
    shopOrder: [
      "FounderClub",
      "AutomationPro",
      "ExecutiveDashboard",
      "StarterCapital",
      "FocusBoost",
      "RevenueSprint",
    ],
  };
  if (!experiment) return config;

  if (experiment.type === "tutorial_hint") config.tutorialHintVariant = experiment.variant;
  if (experiment.type === "mission_prompt") config.missionPromptVariant = experiment.variant;
  if (experiment.type === "value_demo") config.valueDemoEnabled = experiment.variant !== "disabled";
  if (experiment.type === "cycle_reward") {
    config.cycleRewardMultiplier = experiment.variant === "plus_5_percent" ? 1.05 : experiment.variant === "minus_5_percent" ? 0.95 : 1;
  }
  if (experiment.type === "cycle_pacing") {
    config.cyclePacingMultiplier = experiment.variant === "faster_10_percent" ? 0.9 : experiment.variant === "slower_10_percent" ? 1.1 : 1;
  }
  if (experiment.type === "shop_order" && experiment.variant === "automation_first") {
    config.shopOrder = ["AutomationPro", "FounderClub", "ExecutiveDashboard", "StarterCapital", "FocusBoost", "RevenueSprint"];
  }
  if (experiment.type === "shop_order" && experiment.variant === "consumables_first") {
    config.shopOrder = ["StarterCapital", "FocusBoost", "RevenueSprint", "AutomationPro", "ExecutiveDashboard", "FounderClub"];
  }
  return config;
}
