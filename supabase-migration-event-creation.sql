-- =============================================================
-- Buzz Me In — Event Creation Flow: Schema Migration
-- =============================================================

-- 1. Drop any partially-created tables from failed previous runs
drop table if exists event_location_votes cascade;
drop table if exists event_location_options cascade;
drop table if exists event_datetime_votes cascade;
drop table if exists event_datetime_options cascade;
drop table if exists event_series cascade;

-- Create event_series table (must exist before FK on events)
create table event_series (
  id uuid primary key default gen_random_uuid(),
  cadence text not null,  -- 'weekly' | 'biweekly' | 'monthly' | 'every_6_weeks' | 'custom'
  custom_interval_days integer,
  created_by uuid,        -- auth.users id (no FK — Supabase restricts cross-schema FKs)
  created_at timestamptz default now()
);

-- 2. Alter events table — add new columns
alter table events
  add column if not exists datetime_mode text,          -- 'set' | 'poll_host' | 'poll_open' | null
  add column if not exists location_mode text,          -- 'set' | 'virtual' | 'poll_host' | 'poll_open' | null
  add column if not exists capacity integer,            -- null = unlimited
  add column if not exists bring_list_mode text,        -- 'prefill' | 'open' | 'none'
  add column if not exists series_id uuid references event_series(id);

-- Status column is plain text, so 'draft' and 'cancelled' are already valid.
-- No ALTER TYPE needed.

-- 3. Drop old date options tables
drop table if exists event_date_responses cascade;
drop table if exists event_date_options cascade;

-- 4. Create event_datetime_options
create table event_datetime_options (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references events(id) on delete cascade,
  candidate_datetime timestamptz not null,
  suggested_by uuid,          -- auth.users id; null for host-defined options
  voting_deadline timestamptz,
  suggestions_deadline timestamptz,  -- null for poll_host mode
  created_at timestamptz default now()
);

-- 5. Create event_datetime_votes
create table event_datetime_votes (
  id uuid primary key default gen_random_uuid(),
  option_id uuid not null references event_datetime_options(id) on delete cascade,
  user_id uuid not null,      -- auth.users id
  voted_at timestamptz default now(),
  unique (option_id, user_id)
);

-- 6. Create event_location_options
create table event_location_options (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references events(id) on delete cascade,
  location_text text not null,
  suggested_by uuid,          -- auth.users id; null for host-defined options
  voting_deadline timestamptz,
  suggestions_deadline timestamptz,  -- null for poll_host mode
  created_at timestamptz default now()
);

-- 7. Create event_location_votes
create table event_location_votes (
  id uuid primary key default gen_random_uuid(),
  option_id uuid not null references event_location_options(id) on delete cascade,
  user_id uuid not null,      -- auth.users id
  voted_at timestamptz default now(),
  unique (option_id, user_id)
);

-- 8. Enable RLS on new tables
alter table event_series enable row level security;
alter table event_datetime_options enable row level security;
alter table event_datetime_votes enable row level security;
alter table event_location_options enable row level security;
alter table event_location_votes enable row level security;

-- 9. RLS policies — event_series
create policy "Members can view series for their groups"
  on event_series for select
  using (
    exists (
      select 1 from events e
      join group_members gm on gm.group_id = e.group_id
      where e.series_id = event_series.id
        and gm.user_id = auth.uid()
    )
  );

create policy "Admins can insert series"
  on event_series for insert
  with check (created_by = auth.uid());

-- 10. RLS policies — event_datetime_options
create policy "Members can view datetime options"
  on event_datetime_options for select
  using (
    exists (
      select 1 from events e
      join group_members gm on gm.group_id = e.group_id
      where e.id = event_datetime_options.event_id
        and gm.user_id = auth.uid()
    )
  );

create policy "Admins can insert datetime options"
  on event_datetime_options for insert
  with check (
    exists (
      select 1 from events e
      join group_members gm on gm.group_id = e.group_id
      where e.id = event_datetime_options.event_id
        and gm.user_id = auth.uid()
        and gm.role in ('admin', 'co_admin')
    )
  );

create policy "Members can suggest datetime options"
  on event_datetime_options for insert
  with check (
    suggested_by = auth.uid()
    and exists (
      select 1 from events e
      join group_members gm on gm.group_id = e.group_id
      where e.id = event_datetime_options.event_id
        and gm.user_id = auth.uid()
        and e.datetime_mode = 'poll_open'
    )
  );

-- 11. RLS policies — event_datetime_votes
create policy "Members can view datetime votes"
  on event_datetime_votes for select
  using (
    exists (
      select 1 from event_datetime_options o
      join events e on e.id = o.event_id
      join group_members gm on gm.group_id = e.group_id
      where o.id = event_datetime_votes.option_id
        and gm.user_id = auth.uid()
    )
  );

create policy "Members can vote on datetime options"
  on event_datetime_votes for insert
  with check (user_id = auth.uid());

create policy "Members can remove their datetime votes"
  on event_datetime_votes for delete
  using (user_id = auth.uid());

-- 12. RLS policies — event_location_options (mirrors datetime)
create policy "Members can view location options"
  on event_location_options for select
  using (
    exists (
      select 1 from events e
      join group_members gm on gm.group_id = e.group_id
      where e.id = event_location_options.event_id
        and gm.user_id = auth.uid()
    )
  );

create policy "Admins can insert location options"
  on event_location_options for insert
  with check (
    exists (
      select 1 from events e
      join group_members gm on gm.group_id = e.group_id
      where e.id = event_location_options.event_id
        and gm.user_id = auth.uid()
        and gm.role in ('admin', 'co_admin')
    )
  );

create policy "Members can suggest location options"
  on event_location_options for insert
  with check (
    suggested_by = auth.uid()
    and exists (
      select 1 from events e
      join group_members gm on gm.group_id = e.group_id
      where e.id = event_location_options.event_id
        and gm.user_id = auth.uid()
        and e.location_mode = 'poll_open'
    )
  );

-- 13. RLS policies — event_location_votes (mirrors datetime)
create policy "Members can view location votes"
  on event_location_votes for select
  using (
    exists (
      select 1 from event_location_options o
      join events e on e.id = o.event_id
      join group_members gm on gm.group_id = e.group_id
      where o.id = event_location_votes.option_id
        and gm.user_id = auth.uid()
    )
  );

create policy "Members can vote on location options"
  on event_location_votes for insert
  with check (user_id = auth.uid());

create policy "Members can remove their location votes"
  on event_location_votes for delete
  using (user_id = auth.uid());
