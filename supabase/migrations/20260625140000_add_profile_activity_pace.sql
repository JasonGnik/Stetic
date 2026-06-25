-- The 20260624221733_add_profile_macro_fields migration shipped EMPTY, so the
-- columns the client writes on profile save were never created. Onboarding fails
-- on the final step with: PGRST204 "could not find the 'activity_level' column".
-- Add the missing columns here (idempotent).
alter table profiles add column if not exists activity_level text;
alter table profiles add column if not exists pace          text;
