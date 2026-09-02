# Cofounder setup

Cofounder operates outside Roblox. The game does not iframe or clone Cofounder's private web interface; instead, the project exposes the business data and repository workflow that a Cofounder agent can use.

1. Open the existing Cofounder organization.
2. Create a custom agent named **Roblox Revenue Operator**.
3. Paste `cofounder/revenue-operator.md` into its instructions.
4. Add `cofounder/company-context.md` as company context.
5. Configure the daily and weekly tasks from `cofounder/routines.md`.
6. Connect the GitHub repository and the backend deployment.
7. Provide Roblox Analytics and Creator Hub exports or a supported read-only integration when available.
8. Store the backend `ADMIN_API_KEY` as a protected integration secret; do not paste it into ordinary tasks or public issues.
9. Keep publishing, pricing, ad spend, public claims, and financial actions behind explicit human approval.

## Backend endpoints for the operator

```text
GET  /api/health
GET  /api/v1/admin/summary?hours=168
POST /api/v1/admin/recommendation
GET  /api/cron/operator
```

The two admin endpoints accept either `x-admin-key: <ADMIN_API_KEY>` or an Authorization bearer token. The cron endpoint accepts `Authorization: Bearer <CRON_SECRET>`.

## What is autonomous

With `AUTO_APPLY_SAFE_EXPERIMENTS=false`, the operator produces recommendations only. With it set to `true`, the daily backend job may activate one allowlisted, non-price experiment after the configured minimum-session threshold and only when no experiment is already active.
