-- The user's current routine (free text), captured in onboarding for experienced
-- lifters. Feeds the plan's split_critique — why their routine leaves weak points behind.
alter table profiles add column if not exists current_split text;
