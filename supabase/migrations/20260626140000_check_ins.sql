-- Daily readiness check-in: mood, confidence in the goal, and readiness to train /
-- stick to the plan. Drives consistency nudges and "your own history" motivation.
create table if not exists check_ins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  log_date date not null default current_date,
  mood int not null default 3,        -- 1..5
  confidence int not null default 3,  -- 1..5 (toward goal)
  readiness int not null default 3,   -- 1..5 (feel like training / sticking to plan)
  training_day boolean not null default false,
  created_at timestamptz not null default now(),
  unique (user_id, log_date)
);
create index if not exists check_ins_user_date_idx on check_ins (user_id, log_date desc);

alter table check_ins enable row level security;
drop policy if exists "own check_ins" on check_ins;
create policy "own check_ins" on check_ins
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
