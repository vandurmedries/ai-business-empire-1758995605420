# Launch checklist

## Code and backend

- [ ] `cd backend; npm ci; npm run verify` passes.
- [ ] GitHub CI passes the Luau syntax compile and Rojo build.
- [ ] `/api/health` returns HTTP 200.
- [ ] Roblox-authenticated mission and config requests work with the experience secret.
- [ ] Invalid and missing secrets are rejected.
- [ ] Admin and cron keys are independent from the Roblox shared secret.
- [ ] No secret or service-role key exists in the repository or a client script.

## Gameplay

- [ ] A new player receives the default company state.
- [ ] The first company cycle awards server-calculated cash, customers, XP, and reputation.
- [ ] Cooldowns and remote-action rate limits cannot be bypassed from the client.
- [ ] All three departments upgrade at the correct cost.
- [ ] Player data survives leave and rejoin.
- [ ] Two-player Studio testing shows isolated player state.
- [ ] Curated missions progress, complete, reward once, and expire correctly.
- [ ] Backend outage still permits local missions and default configuration.

## Purchases

- [ ] All product, pass, and subscription IDs point to this experience's intended assets.
- [ ] The store never displays a made-up price.
- [ ] A developer-product test is granted exactly once through `ProcessReceipt`.
- [ ] The same receipt remains idempotent after server retry/rejoin.
- [ ] Game-pass entitlement is checked on the server and refreshes after purchase.
- [ ] Subscription status is checked on the server and refreshes after the prompt.
- [ ] No off-platform purchase route exists.
- [ ] No paid randomized reward exists.

## Analytics and operator

- [ ] Roblox onboarding, economy, and custom events appear in the intended dashboards.
- [ ] Custom backend events contain no user ID, username, email, chat text, or IP field.
- [ ] Creator Hub remains the source of truth for booked Robux and payouts.
- [ ] Event freshness and sample sizes are visible before an experiment is chosen.
- [ ] Only one experiment can be active.
- [ ] Every experiment has a primary metric, guardrail, sample threshold, duration, and stop condition.
- [ ] Price changes, publishing, advertising, public claims, and financial actions still require human approval.

## Release

- [ ] The experience name and description do not imply affiliation with Cofounder or Roblox.
- [ ] Age suitability, content maturity, privacy disclosures, and platform policy checks are complete.
- [ ] Mobile, tablet, desktop, and gamepad UI have been manually tested.
- [ ] A rollback build and configuration are available.
- [ ] Human publish approval has been recorded.
