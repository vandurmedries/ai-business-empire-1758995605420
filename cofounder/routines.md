# Cofounder routines

## Daily — Product and revenue health

Run each morning after the backend cron has completed.

1. Check backend health and the most recent operator run.
2. Check event freshness and unique session count.
3. Check Roblox Analytics and Creator Hub reports when connected or supplied.
4. Distinguish actual booked Robux from custom conversion signals.
5. Review the active experiment and its guardrail.
6. Produce one decision using the format in `revenue-operator.md`.
7. Open or update one GitHub issue only when action is supported by evidence.

## Weekly — Evidence review

1. Use the previous seven and 28 days as separate comparison windows.
2. Review reliability, onboarding, activation, retention, missions, offers, subscriptions, and booked revenue.
3. Confirm whether metric definitions or instrumentation changed.
4. Close inconclusive experiments without overstating results.
5. Recommend the smallest next change with the highest expected player value.

## Release review — human approval required

Before a production release, provide:

- passing backend and Luau syntax checks;
- Roblox Studio multiplayer playtest results;
- DataStore save/rejoin result;
- a completed developer-product receipt test;
- game-pass and subscription entitlement test results;
- privacy and secret-leak checks;
- rollback instructions;
- an explicit publish approval request.
