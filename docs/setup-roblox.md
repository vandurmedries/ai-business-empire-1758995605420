# Roblox setup

## 1. Get the source

PowerShell:

```powershell
git clone https://github.com/vandurmedries/ai-business-empire-1758995605420.git
cd ai-business-empire-1758995605420
```

Install Rojo 7.7.0 or a compatible newer release and install the Rojo Studio plugin. From the project directory:

```powershell
rojo serve
```

Open Roblox Studio, create or open an experience, open the Rojo plugin, and connect to `localhost:34872`.

A file build can also be produced with:

```powershell
rojo build default.project.json --output AI-Founder-Empire.rbxlx
```

## 2. Enable required Studio settings

In **Game Settings / Security** for the test experience:

- enable HTTP requests;
- enable Studio access to API services when testing DataStore behavior in Studio.

Use a private test place until persistence, purchases, and multiplayer behavior have passed the launch checklist.

## 3. Deploy the backend

Deploy the `backend` directory as the Vercel project root. Configure the values in `backend/.env.example`.

Generate three independent random secrets. In PowerShell:

```powershell
$bytes = New-Object byte[] 48
[Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
[Convert]::ToBase64String($bytes)
```

Use different generated values for:

- `ROBLOX_SHARED_SECRET`;
- `ADMIN_API_KEY`;
- `CRON_SECRET`.

Set `OPENAI_API_KEY` only when AI-assisted selection is wanted. The game remains functional without it because mission and experiment selection have deterministic fallbacks.

Set `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` only after applying `backend/supabase/migrations/001_ai_founder_empire.sql`. Without Supabase, custom events are accepted but not persisted and the daily operator skips safely.

## 4. Connect Roblox securely

In Creator Hub, create an experience secret named:

```text
AI_BUSINESS_BACKEND_SECRET
```

Give it the exact `ROBLOX_SHARED_SECRET` value. Never put this value directly in a `LocalScript`, ModuleScript, repository, attribute, or UI.

In `src/shared/Config.lua`, replace:

```lua
BackendBaseUrl = "https://YOUR-VERCEL-PROJECT.vercel.app"
```

with the deployed HTTPS origin, without a trailing slash.

For Studio tests, configure the same secret in Studio's supported secret-management flow for the experience. When no secret is available, the game intentionally falls back to local missions and default live configuration.

## 5. Create Roblox monetization assets

Create these in Creator Hub and copy their IDs into `src/shared/Config.lua`:

- developer products: `StarterCapital`, `FocusBoost`, `RevenueSprint`;
- game passes: `AutomationPro`, `ExecutiveDashboard`;
- subscription: `FounderClub`.

Zero or empty IDs keep an offer disabled, and the UI shows `SETUP REQUIRED` rather than opening checkout.

Do not grant developer products from purchase-prompt completion events. The included code grants them only from `ProcessReceipt` after durable receipt handling.

## 6. Test

Use **Test / Start** with at least two players. Complete every item in `docs/launch-checklist.md`. Publish only after a real test purchase in the private experience has been granted once, persisted, and survived a rejoin.
