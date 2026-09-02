import { randomUUID } from "node:crypto";

export function requestId(req) {
  const incoming = req?.headers?.["x-request-id"];
  return typeof incoming === "string" && incoming.length <= 100 ? incoming : randomUUID();
}

export function setCommonHeaders(res, id) {
  res.setHeader("content-type", "application/json; charset=utf-8");
  res.setHeader("cache-control", "no-store");
  res.setHeader("x-content-type-options", "nosniff");
  res.setHeader("x-frame-options", "DENY");
  res.setHeader("referrer-policy", "no-referrer");
  res.setHeader("x-request-id", id);
}

export function sendJson(res, status, body, id = randomUUID()) {
  setCommonHeaders(res, id);
  res.statusCode = status;
  res.end(JSON.stringify({ ...body, requestId: id }));
}

export function methodNotAllowed(res, allowed, id) {
  res.setHeader("allow", allowed.join(", "));
  sendJson(res, 405, { ok: false, error: "method_not_allowed" }, id);
}

export async function readJson(req, maxBytes = 64_000) {
  if (req.body && typeof req.body === "object" && !Buffer.isBuffer(req.body)) {
    return req.body;
  }
  if (typeof req.body === "string") {
    if (Buffer.byteLength(req.body, "utf8") > maxBytes) throw new Error("body_too_large");
    return JSON.parse(req.body || "{}");
  }

  const chunks = [];
  let size = 0;
  for await (const chunk of req) {
    const buffer = Buffer.from(chunk);
    size += buffer.length;
    if (size > maxBytes) throw new Error("body_too_large");
    chunks.push(buffer);
  }
  const text = Buffer.concat(chunks).toString("utf8");
  return JSON.parse(text || "{}");
}

export function parseInteger(value, fallback, min, max) {
  const parsed = Number.parseInt(String(value ?? ""), 10);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.min(max, Math.max(min, parsed));
}
