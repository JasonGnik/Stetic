-- "What brought you here?" — the user's motivation/why (collected in onboarding,
-- useful for funnel priming + marketing segmentation). Multiselect → text[].
alter table profiles add column if not exists motivation text[] default '{}';
