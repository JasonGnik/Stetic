-- Plan lifecycle: a plan is an ~8-week block the user runs, then finishes and
-- re-scans to build the next one. status drives the active plan + history.
alter table plans add column if not exists status      text not null default 'active'; -- active | archived | finished
alter table plans add column if not exists started_at  timestamptz default now();
alter table plans add column if not exists length_weeks int default 8;
alter table plans add column if not exists finished_at  timestamptz;

create index if not exists plans_user_status_idx on plans (user_id, status, created_at desc);
