# AI Founder Empire — Roblox + autonomous revenue operator

AI Founder Empire is a Roblox tycoon MVP in which each player grows a small AI-run company. A server-authoritative Roblox economy is connected to an external backend that generates safe player missions, collects privacy-minimised analytics, and can run a daily revenue-optimization loop.

The operator is designed to maximize **sustainable creator revenue over a 90-day horizon**, not to pressure players into purchases. It may autonomously activate low-risk experiments such as tutorial hints, value demonstrations, mission wording, shop ordering, starter rewards, and content pacing. It cannot autonomously change prices, publish a Roblox build, spend advertising money, direct players to off-platform checkout, or create randomized paid rewards.

This repository contains:

- a Rojo-compatible Roblox project written in Luau;
- server-authoritative progression, upgrades, persistence, receipts, passes, and subscription entitlement checks;
- a responsive in-game founder dashboard built without external assets;
- an authenticated backend for AI missions, event ingestion, live configuration, summaries, and the daily operator;
- optional OpenAI Responses API integration with deterministic fallbacks;
- optional Supabase persistence and SQL migrations;
- a ready-to-paste Cofounder custom-agent contract and routines;
- tests and a GitHub Actions workflow for the backend.

## Repository layout

```text
src/                         Roblox source, synchronized with Rojo
backend/                     Vercel-compatible Node.js API
backend/supabase/migrations  Optional analytics/experiment database
cofounder/                   Revenue Operator agent contract and routines
docs/                        Setup, architecture, monetization, and launch checks
```

## Fast start

1. Install Roblox Studio and Rojo.
2. Create or open a Roblox experience.
3. In this repository, run `rojo serve` and connect the Rojo Studio plugin.
4. Set the IDs in `src/shared/Config.lua` after creating the products, passes, and subscription in Creator Hub.
5. Deploy `backend/` to Vercel and configure the environment variables from `backend/.env.example`.
6. Put the same `ROBLOX_SHARED_SECRET` value in the Roblox experience secret named `AI_BUSINESS_BACKEND_SECRET`.
7. Set `BackendBaseUrl` in `src/shared/Config.lua` to the deployed HTTPS origin.
8. Enable HTTP requests and Studio access to API services in Experience Settings for testing.
9. Apply the Supabase migration if persistent analytics and autonomous experiments are required.
10. Paste `cofounder/revenue-operator.md` into a Cofounder custom agent and connect GitHub, Vercel, and Supabase.

Detailed instructions are in [`docs/setup-roblox.md`](docs/setup-roblox.md) and [`docs/launch-checklist.md`](docs/launch-checklist.md).

## Backend tests

```bash
cd backend
npm test
```

## Important scope

The project supplies a tested engineering foundation; it does not create a Roblox place, monetization asset IDs, an OpenAI API balance, a Supabase project, or guaranteed income by itself. Revenue starts only after the experience is completed, published, discoverable, and used by paying players. All purchases remain inside Roblox's official monetization systems.
