import test from "node:test";
import assert from "node:assert/strict";
import {
  deterministicRecommendation,
  experimentToLiveConfig,
  validateExperiment,
} from "../lib/experiments.js";

test("unsafe and unknown experiment types are rejected", () => {
  assert.equal(validateExperiment({ type: "price_change", variant: "raise_20_percent" }), null);
  assert.equal(validateExperiment({ type: "tutorial_hint", variant: "buy_now" }), null);
});

test("safe recommendation stays within the allowlist", () => {
  const recommendation = deterministicRecommendation({ uniqueSessions: 10, rates: {} });
  assert.equal(recommendation.type, "tutorial_hint");
  assert.equal(recommendation.variant, "goal_first");
  assert.ok(recommendation.minSessions >= 30);
});

test("experiment mapping changes only bounded live configuration", () => {
  const rewardConfig = experimentToLiveConfig({ id: "exp-1", type: "cycle_reward", variant: "plus_5_percent" });
  assert.equal(rewardConfig.cycleRewardMultiplier, 1.05);
  assert.equal(rewardConfig.cyclePacingMultiplier, 1);

  const orderConfig = experimentToLiveConfig({ id: "exp-2", type: "shop_order", variant: "automation_first" });
  assert.equal(orderConfig.shopOrder[0], "AutomationPro");
  assert.equal(orderConfig.shopOrder.length, 6);
});
