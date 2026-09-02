import { createServer } from "node:http";

import healthHandler from "./api/health.js";
import operatorHandler from "./api/cron/operator.js";
import recommendationHandler from "./api/v1/admin/recommendation.js";
import summaryHandler from "./api/v1/admin/summary.js";
import configHandler from "./api/v1/config.js";
import eventsHandler from "./api/v1/events.js";
import missionHandler from "./api/v1/mission.js";
import { requestId, sendJson } from "./lib/http.js";

const routes = new Map([
  ["/api/health", healthHandler],
  ["/api/cron/operator", operatorHandler],
  ["/api/v1/admin/recommendation", recommendationHandler],
  ["/api/v1/admin/summary", summaryHandler],
  ["/api/v1/config", configHandler],
  ["/api/v1/events", eventsHandler],
  ["/api/v1/mission", missionHandler],
]);

function cleanPathname(pathname) {
  if (pathname === "/") return pathname;
  return pathname.replace(/\/+$/, "") || "/";
}

const server = createServer(async (req, res) => {
  const id = requestId(req);

  try {
    const base = `http://${req.headers.host || "localhost"}`;
    const url = new URL(req.url || "/", base);
    const pathname = cleanPathname(url.pathname);
    const handler = routes.get(pathname);

    req.query = Object.fromEntries(url.searchParams.entries());

    if (!handler) {
      return sendJson(res, 404, {
        ok: false,
        error: "not_found",
        available: [
          "GET /api/health",
          "POST /api/v1/mission",
          "GET /api/v1/config",
          "POST /api/v1/events",
          "GET /api/v1/admin/summary",
          "POST /api/v1/admin/recommendation",
          "GET|POST /api/cron/operator",
        ],
      }, id);
    }

    await handler(req, res);
  } catch (error) {
    console.error("request_failed", {
      requestId: id,
      method: req.method,
      url: req.url,
      error: error instanceof Error ? error.message : String(error),
    });

    if (!res.headersSent) {
      return sendJson(res, 500, { ok: false, error: "internal_server_error" }, id);
    }
    if (!res.writableEnded) res.end();
  }
});

const port = Number.parseInt(process.env.PORT || "3000", 10);
server.listen(port, "0.0.0.0", () => {
  console.log(`AI Founder Empire backend listening on port ${port}`);
});

function shutdown(signal) {
  console.log(`${signal} received; closing HTTP server`);
  server.close((error) => {
    if (error) {
      console.error("server_shutdown_failed", error);
      process.exitCode = 1;
    }
    process.exit();
  });
}

process.once("SIGTERM", () => shutdown("SIGTERM"));
process.once("SIGINT", () => shutdown("SIGINT"));
