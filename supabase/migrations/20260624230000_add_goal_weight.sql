-- Optional target bodyweight, captured in onboarding to size the deficit/surplus
-- and the projection's weight trajectory.
alter table profiles add column if not exists goal_weight_kg numeric;
