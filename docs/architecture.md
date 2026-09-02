# Architecture

```text
Roblox client
  └─ UI and purchase prompts only
       │ RemoteFunctions / RemoteEvents
       ▼
Roblox server
  ├─ authoritative economy and mission progress
  ├─ DataStore persistence
  ├─ ProcessReceipt grants
  ├─ pass/subscription entitlement checks
  ├─ Roblox Analytics events
  └─ authenticated HTTPS calls
       ▼
Vercel-compatible backend
  ├─ curated mission selector
  ├─ privacy-minimized event ingestion
  ├─ live experiment configuration
  ├─ admin summaries/recommendations
  └─ constrained daily operator
       │
       ├─ optional OpenAI Responses API
       └─ optional Supabase persistence

Cofounder
  └─ external business operator using connected evidence and GitHub workflows
```

## Trust boundaries

The client never awards cash, changes department levels, grants purchases, or selects experiment values. Every state-changing request is validated on the Roblox server and rate-limited.

Developer products are granted only through `MarketplaceService.ProcessReceipt`, and receipt IDs are persisted before Roblox is told the purchase was granted. Pass and subscription status is checked on the server.

The backend accepts Roblox traffic only with a shared secret stored as a Roblox experience secret. Admin and cron endpoints use independent credentials. The Supabase service-role key and OpenAI key remain backend-only.

## AI boundary

The model does not write free-form messages shown to players. It returns a template ID plus bounded numbers. Roblox resolves that ID to reviewed local text. Invalid or unavailable AI output falls back to a deterministic local mission.

The daily operator can select only allowlisted experiment types and exact variants. The live-config service validates every value again before applying it.

## Analytics boundary

The custom event stream uses a random per-server-session identifier. It intentionally excludes Roblox user IDs, usernames, email addresses, chat text, and IP-address fields. Roblox's own analytics APIs continue to supply platform metrics.
