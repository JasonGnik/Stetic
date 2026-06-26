-- Logged meals carry the foods that make them up (so they read like "3 eggs · 220 cal"
-- and are editable per-food). Totals are the sum of the items.
alter table meal_logs add column if not exists items jsonb not null default '[]'::jsonb;
