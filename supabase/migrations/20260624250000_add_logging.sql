-- Retention: workout + meal logging. Drives the streak and the daily nutrition view.
-- Photos are never stored — meal scans persist only the derived numbers.

-- workout_logs already exists as a stub (initial schema). Extend it to hold the
-- full logged session: which day, and the per-set weight/reps the user entered.
alter table workout_logs add column if not exists log_date  date  not null default current_date;
alter table workout_logs add column if not exists day_label text;
alter table workout_logs add column if not exists exercises jsonb not null default '[]'::jsonb;
create index if not exists workout_logs_user_date_idx on workout_logs (user_id, log_date desc);

-- meal_logs is new.
create table if not exists meal_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  log_date date not null default current_date,
  name text not null,
  calories numeric not null default 0,
  protein_g numeric not null default 0,
  carbs_g numeric not null default 0,
  fat_g numeric not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists meal_logs_user_date_idx on meal_logs (user_id, log_date desc);

alter table meal_logs enable row level security;
drop policy if exists "own meal_logs" on meal_logs;
create policy "own meal_logs" on meal_logs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
