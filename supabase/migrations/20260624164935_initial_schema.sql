-- Stetic initial schema
-- Photos are NEVER persisted. Only derived numbers are stored. RLS on every table.

-- ── enums ──────────────────────────────────────────────────────────────────
create type sex as enum ('male', 'female');
create type goal as enum ('lose_fat', 'gain_muscle', 'both');
create type experience as enum ('beginner', 'intermediate', 'advanced');
create type equipment as enum ('full_gym', 'home', 'dumbbells_only');
create type rank_tier as enum (
  'bronze', 'silver', 'gold', 'platinum', 'diamond', 'elite', 'mythic', 'greek_god'
);

-- ── profiles ───────────────────────────────────────────────────────────────
-- One row per auth user. Holds onboarding answers.
create table profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  sex          sex,
  age          int,
  height_cm    numeric(5,1),
  weight_kg    numeric(5,1),
  goal         goal,
  focus        text[]      default '{}',   -- multiselect: arms, shoulders, abs, chest, legs, back, lower_bf
  experience   experience,
  days_per_week int,
  equipment    equipment,
  diet         text,                       -- free-form / restriction tag
  attribution  text,                       -- how they heard about us
  created_at   timestamptz default now(),
  updated_at   timestamptz default now()
);

-- ── scans ──────────────────────────────────────────────────────────────────
-- Result of a physique scan. NO image stored. Scores displayed 0.0–10.0.
create table scans (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users (id) on delete cascade,
  sex             sex not null,
  aesthetic_score numeric(3,1) not null,   -- 0.0–10.0
  rank_tier       rank_tier not null,
  body_fat        numeric(4,1),            -- estimated %
  symmetry        numeric(3,1),            -- 0.0–10.0
  potential       numeric(3,1),            -- 0.0–10.0
  muscles         jsonb not null,          -- [{group,score,visible,note}] x6
  size_flag       text,                    -- e.g. 'extreme' (rare); null normally
  verdict         text,
  photo_count     int default 1,
  created_at      timestamptz default now()
);
create index scans_user_created_idx on scans (user_id, created_at desc);

-- ── plans ──────────────────────────────────────────────────────────────────
create table plans (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  scan_id     uuid references scans (id) on delete set null,
  workout     jsonb not null,
  macros      jsonb not null,
  version     int default 1,
  created_at  timestamptz default now()
);
create index plans_user_created_idx on plans (user_id, created_at desc);

-- ── workout_logs ───────────────────────────────────────────────────────────
-- One row per completed session (not per-exercise). Drives the streak.
create table workout_logs (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  session_ref  text,                       -- which session in the plan
  completed_at timestamptz default now()
);
create index workout_logs_user_idx on workout_logs (user_id, completed_at desc);

-- ── weight_logs ────────────────────────────────────────────────────────────
create table weight_logs (
  id        uuid primary key default gen_random_uuid(),
  user_id   uuid not null references auth.users (id) on delete cascade,
  weight_kg numeric(5,1) not null,
  logged_at timestamptz default now()
);
create index weight_logs_user_idx on weight_logs (user_id, logged_at desc);

-- ── meals ──────────────────────────────────────────────────────────────────
-- Meal photo -> calories/macros. NO image stored.
create table meals (
  id        uuid primary key default gen_random_uuid(),
  user_id   uuid not null references auth.users (id) on delete cascade,
  label     text,
  calories  int,
  protein_g int,
  carbs_g   int,
  fat_g     int,
  logged_at timestamptz default now()
);
create index meals_user_idx on meals (user_id, logged_at desc);

-- ── subscriptions ──────────────────────────────────────────────────────────
-- Mirror of RevenueCat entitlement. Written by service role (webhook), read by user.
create table subscriptions (
  user_id     uuid primary key references auth.users (id) on delete cascade,
  entitlement text,
  status      text,                        -- active, trialing, expired, ...
  expires_at  timestamptz,
  updated_at  timestamptz default now()
);

-- ── updated_at trigger for profiles ──────────────────────────────────────────
create or replace function set_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end; $$;
create trigger profiles_updated_at before update on profiles
  for each row execute function set_updated_at();

-- ── auto-create a profile row when a user signs up ───────────────────────────
create or replace function handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id) values (new.id) on conflict do nothing;
  return new;
end; $$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function handle_new_user();

-- ── RLS ──────────────────────────────────────────────────────────────────────
alter table profiles      enable row level security;
alter table scans         enable row level security;
alter table plans         enable row level security;
alter table workout_logs  enable row level security;
alter table weight_logs   enable row level security;
alter table meals         enable row level security;
alter table subscriptions enable row level security;

-- profiles: owner can read + update own row (insert handled by trigger)
create policy "own profile read"   on profiles for select using (auth.uid() = id);
create policy "own profile update" on profiles for update using (auth.uid() = id);

-- generic owner policies for user-owned tables
create policy "own scans"        on scans        for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own plans"        on plans        for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own workout_logs" on workout_logs for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own weight_logs"  on weight_logs  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own meals"        on meals        for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- subscriptions: user reads own; writes only via service role (which bypasses RLS)
create policy "own subscription read" on subscriptions for select using (auth.uid() = user_id);
