-- Group the day's food like MyFitnessPal: breakfast / lunch / dinner / snacks.
alter table meal_logs add column if not exists meal_type text not null default 'other';
