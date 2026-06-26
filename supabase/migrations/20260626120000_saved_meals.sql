-- Saved meals: a named combo of foods the user can re-log in one tap.
create table if not exists saved_meals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  items jsonb not null default '[]'::jsonb,
  calories numeric not null default 0,
  protein_g numeric not null default 0,
  carbs_g numeric not null default 0,
  fat_g numeric not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists saved_meals_user_idx on saved_meals (user_id, created_at desc);

alter table saved_meals enable row level security;
drop policy if exists "own saved_meals" on saved_meals;
create policy "own saved_meals" on saved_meals
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
