import { recommendExperiment } from "./experiments.js";
import { aggregateEvents } from "./metrics.js";
import {
  claimOperatorRun,
  createExperiment,
  deactivateActiveExperiments,
  fetchEvents,
  getActiveExperiment,
  storageConfigured,
  updateOperatorRun,
} from "./storage.js";

export async function runDailyOperator(env = process.env) {
  if (!storageConfigured(env)) {
    return { ok: true, skipped: "storage_not_configured", activated: false };
  }

  const runDate = new Date().toISOString().slice(0, 10);
  const run = await claimOperatorRun(runDate, env);
  if (!run) return { ok: true, skipped: "already_ran_today", activated: false };

  try {
    const events = await fetchEvents(168, env);
    const summary = aggregateEvents(events, 168);
    const activeExperiment = await getActiveExperiment(env);
    const recommendation = await recommendExperiment(summary, activeExperiment, env);
    const minimumSessions = Math.min(
      1_000_000,
      Math.max(30, Number.parseInt(env.MIN_OPERATOR_SESSIONS || "50", 10) || 50),
    );
    const autoApply = env.AUTO_APPLY_SAFE_EXPERIMENTS === "true";
    const eligible = autoApply && !activeExperiment && summary.uniqueSessions >= minimumSessions;

    let activatedExperiment = null;
    if (eligible) {
      await deactivateActiveExperiments(env);
      activatedExperiment = await createExperiment(recommendation, env);
    }

    await updateOperatorRun(
      run.id,
      {
        status: "completed",
        summary,
        recommendation,
        action: activatedExperiment ? "activated_safe_experiment" : "recommendation_only",
        experiment_id: activatedExperiment?.id ?? null,
      },
      env,
    );

    return {
      ok: true,
      skipped: null,
      activated: Boolean(activatedExperiment),
      activeExperiment: activatedExperiment ?? activeExperiment,
      recommendation,
      summary,
      policy: {
        priceChanges: false,
        publishing: false,
        adSpend: false,
        offPlatformCheckout: false,
        paidRandomRewards: false,
      },
    };
  } catch (error) {
    await updateOperatorRun(
      run.id,
      {
        status: "failed",
        error: error instanceof Error ? error.message.slice(0, 500) : String(error).slice(0, 500),
      },
      env,
    ).catch(() => {});
    throw error;
  }
}
