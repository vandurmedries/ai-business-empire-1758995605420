# Security

Do not report credentials in public issues. Revoke and rotate a credential immediately if it is committed, logged, or shared in plaintext.

The following values must remain server-side:

- `ROBLOX_SHARED_SECRET`;
- `ADMIN_API_KEY`;
- `CRON_SECRET`;
- `OPENAI_API_KEY`;
- `SUPABASE_SERVICE_ROLE_KEY`.

The Roblox shared secret must be stored as an experience secret and sent only from server scripts. The OpenAI and Supabase keys belong only in the backend deployment environment.
