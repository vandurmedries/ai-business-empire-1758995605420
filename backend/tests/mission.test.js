import test from "node:test";
import assert from "node:assert/strict";
import { fallbackMission, selectMission, validateMissionSelection } from "../lib/mission.js";

test("fallback mission is deterministic and bounded", () => {
  const first = fallbackMission({ level: 8, completedMissions: 2, reputation: 60 });
  const second = fallbackMission({ level: 8, completedMissions: 2, reputation: 60 });
  assert.deepEqual(first, second);
  assert.equal(first.templateId, "customer_growth");
  assert.ok(first.targetValue >= 5 && first.targetValue <= 250);
  assert.ok(first.rewardCash <= 5000);
});

test("mission validation rejects uncurated templates and clamps numbers", () => {
  assert.equal(validateMissionSelection({ templateId: "buy_now" }, {}), null);
  const valid = validateMissionSelection(
    { templateId: "cycle_streak", targetValue: 9999, rewardCash: -20, durationMinutes: 99999 },
    {},
  );
  assert.deepEqual(valid, {
    templateId: "cycle_streak",
    targetValue: 12,
    rewardCash: 25,
    durationMinutes: 1440,
    selectionSource: "openai_curated",
  });
});

test("mission selection works without an OpenAI key", async () => {
  const mission = await selectMission({
    company: { level: 2, completedMissions: 0, reputation: 50 },
    context: {},
    env: {},
  });
  assert.equal(mission.templateId, "cycle_streak");
  assert.equal(mission.selectionSource, "deterministic_fallback");
});
