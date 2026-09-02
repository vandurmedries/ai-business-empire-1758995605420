# AI Founder Empire — Roblox-native AI revenue operator

AI Founder Empire is a Roblox business-tycoon MVP in which each player grows a small AI-run company. The current runtime uses Roblox's native `TextGenerator`, `AnalyticsService`, `DataStoreService`, and `MarketplaceService`, so **Render, Railway, Vercel, Supabase, and an external AI API key are not required to run the game**.

The in-game operator is designed to maximize **sustainable creator revenue over a 90-day horizon** by improving fun, retention, comprehension, trust, and voluntary purchase value. It can autonomously select only bounded, reversible experiments such as tutorial presentation, mission framing, value demonstrations, shop ordering, and modest pacing changes.

It cannot autonomously:

- change Robux prices;
- publish or update the Roblox experience;
- spend advertising money;
- send players to off-platform checkout;
- create paid randomized rewards;
- use deceptive scarcity or pressure aimed at minors;
- claim that players will earn real money.

## Included

- Rojo-compatible Roblox project written in Luau;
- responsive in-game founder dashboard without external assets;
- server-authoritative company cycles, upgrades, rewards, and mission progress;
- DataStore persistence and idempotent developer-product receipt handling;
- game-pass and subscription entitlement checks;
- Roblox-native AI mission selection with a deterministic safe fallback;
- a Roblox-native revenue operator with an allowlisted experiment system;
- Roblox Analytics events and privacy-minimized local optimization signals;
- persistent visible disclosure that missions are AI-selected;
- Cofounder-style company context, operator contract, and routines;
- optional external backend source for a future cross-server analytics layer;
- automated backend tests, Luau compilation, and Rojo place builds.

## Repository layout

```text
src/                         Active Roblox-native game runtime
cofounder/                   External Cofounder agent context and routines
docs/                        Setup, monetization, architecture, and launch checks
backend/                     Optional future cross-server analytics backend
.github/workflows/ci.yml     Tests, Luau compilation, and place build
```

## Fast start — no hosting required

1. Download the latest `AI-Founder-Empire-place` artifact from GitHub Actions, or install Rojo and run `rojo build default.project.json --output AI-Founder-Empire.rbxlx`.
2. Open `AI-Founder-Empire.rbxlx` in Roblox Studio.
3. Publish it as an experience owned by your Roblox account or group.
4. Create the developer products, passes, and subscription in Creator Hub.
5. Put their IDs in `src/shared/Config.lua`, rebuild, and republish.
6. Enable Studio access to API services while testing DataStore persistence.
7. Complete the experience's content-maturity questionnaire and disclose its generative-AI component.
8. Test each purchase route in a private or controlled test environment before making the experience public.

`BackendEnabled` can remain disabled. No HTTP secret or hosting URL is needed in native mode.

## Cofounder.co role

Cofounder.co is not embedded as an unrestricted browser inside Roblox. The game contains a Cofounder-style AI founder and revenue operator, while the files under `cofounder/` can be pasted into a Cofounder custom agent for external product, marketing, and operations work. Any external agent should remain unable to change prices, spend money, or publish builds without account-owner authorization.

## Verification

The GitHub workflow runs:

```bash
cd backend
npm ci
npm run verify
```

It also compiles every Luau source file and builds a `.rbxlx` place using Rojo.

## Revenue scope

The project supplies a functioning, tested monetization foundation. It does **not** guarantee revenue. Actual income begins only after the experience is published, discoverable, used, and chosen by paying players. All player purchases remain inside Roblox's official checkout systems, and Robux prices are configured in Creator Hub rather than by the AI.
