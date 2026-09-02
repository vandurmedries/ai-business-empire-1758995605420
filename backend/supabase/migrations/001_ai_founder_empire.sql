create table if not exists public.roblox_events (
  event_id uuid primary key,
  session_id text not null check (char_length(session_id) between 8 and 80),
  event_name text not null check (char_length(event_name) between 1 and 60),
  event_value double precision not null default 1,
  occurred_at timestamptz not null,
  context jsonb not null default '{}'::jsonb,
  game_version text not null default '',
  place_id text not null default '',
  universe_id text not null default '',
  ingested_at timestamptz not null default now()
);

create index if not exists roblox_events_occurred_at_idx on public.roblox_events (occurred_at desc);
create index if not exists roblox_events_name_time_idx on public.roblox_events (event_name, occurred_at desc);
create index if not exists roblox_events_session_idx on public.roblox_events (session_id);

create table if not exists public.roblox_experiments (
  id uuid primary key,
  type text not null,
  variant text not null,
  title text not null,
  hypothesis text not null,
  primary_metric text not null,
  guardrail_metric text not null,
  minimum_sessions integer not null check (minimum_sessions >= 30),
  status text not null check (status in ('active', 'completed', 'stopped')),
  created_by text not null default 'revenue_operator',
  started_at timestamptz not null,
  ends_at timestamptz not null,
  ended_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists roblox_experiments_status_idx on public.roblox_experiments (status, started_at desc);

create table if not exists public.roblox_operator_runs (
  id uuid primary key,
  run_date date not null unique,
  status text not null check (status in ('running', 'completed', 'failed')),
  action text,
  experiment_id uuid references public.roblox_experiments(id) on delete set null,
  summary jsonb,
  recommendation jsonb,
  error text,
  started_at timestamptz not null default now(),
  finished_at timestamptz
);

alter table public.roblox_events enable row level security;
alter table public.roblox_experiments enable row level security;
alter table public.roblox_operator_runs enable row level security;

-- No anon/authenticated policies are created. The backend uses the service-role key,
-- which must remain server-side and must never be placed in Roblox or a LocalScript.
