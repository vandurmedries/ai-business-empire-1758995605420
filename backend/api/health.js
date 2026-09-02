import { requestId, sendJson } from "../lib/http.js";
import { storageConfigured } from "../lib/storage.js";

export default async function handler(req, res) {
  const id = requestId(req);
  sendJson(res, 200, {
    ok: true,
    service: "ai-founder-empire-backend",
    version: "0.1.0",
    timestamp: new Date().toISOString(),
    capabilities: {
      robloxAuthConfigured: Boolean(process.env.ROBLOX_SHARED_SECRET),
      adminAuthConfigured: Boolean(process.env.ADMIN_API_KEY),
      cronAuthConfigured: Boolean(process.env.CRON_SECRET),
      storageConfigured: storageConfigured(),
      openAIConfigured: Boolean(process.env.OPENAI_API_KEY),
      safeAutoExperimentsEnabled: process.env.AUTO_APPLY_SAFE_EXPERIMENTS === "true",
    },
  }, id);
}
