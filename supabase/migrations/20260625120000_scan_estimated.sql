-- A scan can be estimated from onboarding answers (no photo) instead of a real
-- physique scan. The app marks these and nudges the user to scan for a true score.
alter table scans add column if not exists estimated boolean not null default false;
