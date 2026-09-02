# Test plan

## Automated backend tests

`npm run verify` checks JavaScript syntax and covers authentication, event privacy and validation, mission fallback/allowlisting, experiment allowlisting, metric aggregation, and API behavior.

## Roblox Studio tests

Run a local two-player server and verify:

1. Both players load independent state.
2. Repeated client calls inside the cooldown are rejected.
3. A client-side cash value modification does not affect the server state.
4. Each department upgrade charges the correct server-calculated cost.
5. Leaving and rejoining restores the saved state.
6. A mission from the backend resolves to local curated text.
7. Invalid backend fields are rejected and replaced by defaults.
8. Disabling the backend still leaves the core game playable.
9. A product receipt grants once even when Roblox retries it.
10. Pass and subscription benefits do not activate from client-only signals.

## Pre-production purchase test

Use Roblox's supported private testing flow. Record the test account, asset ID, receipt behavior, server log, persisted state before and after rejoin, and Creator Hub result. Do not infer successful revenue merely from a purchase prompt closing.
