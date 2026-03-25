-- =============================================================
-- Buzz Me In — RLS Security Migration
-- Run in Supabase SQL Editor
-- =============================================================
-- Fixes:
--   1. Enables RLS on all 21 public tables missing it
--   2. Adds least-privilege policies for each table
--   3. Replaces the overly-permissive waitlist INSERT policy
--
-- Follows Supabase best practices:
--   - (SELECT auth.uid()) instead of auth.uid() — evaluated once per
--     query rather than per row, improving performance on large tables
--   - TO authenticated scoped on all policies (anon is never granted
--     access except the explicit waitlist INSERT below)
--   - Explicit USING (false) DELETE block on users to prevent
--     accidental row deletion via the API
-- =============================================================


-- ─────────────────────────────────────────────────────────────
-- ENABLE RLS ON ALL TABLES
-- ─────────────────────────────────────────────────────────────
alter table public.users                     enable row level security;
alter table public.groups                    enable row level security;
alter table public.group_members             enable row level security;
alter table public.join_requests             enable row level security;
alter table public.events                    enable row level security;
alter table public.event_rsvps               enable row level security;
alter table public.event_memory              enable row level security;
alter table public.guest_passes              enable row level security;
alter table public.posts                     enable row level security;
alter table public.post_reactions            enable row level security;
alter table public.polls                     enable row level security;
alter table public.poll_options              enable row level security;
alter table public.poll_votes                enable row level security;
alter table public.bring_list_items          enable row level security;
alter table public.bring_list_claims         enable row level security;
alter table public.group_lists               enable row level security;
alter table public.list_items                enable row level security;
alter table public.list_item_upvotes         enable row level security;
alter table public.notifications             enable row level security;
alter table public.notification_preferences  enable row level security;
alter table public.direct_messages           enable row level security;
alter table public.waitlist                  enable row level security;


-- ─────────────────────────────────────────────────────────────
-- users
-- ─────────────────────────────────────────────────────────────
create policy "Users can view their own profile"
  on public.users for select
  to authenticated
  using (id = (select auth.uid()));

create policy "Users can view co-members"
  on public.users for select
  to authenticated
  using (
    exists (
      select 1 from public.group_members gm1
      join public.group_members gm2 on gm2.group_id = gm1.group_id
      where gm1.user_id = (select auth.uid())
        and gm2.user_id = public.users.id
    )
  );

create policy "Users can update their own profile"
  on public.users for update
  to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- Explicitly block API-level deletes; account deletion goes through
-- a server-side function with service_role.
create policy "Users cannot delete profiles via API"
  on public.users for delete
  to authenticated
  using (false);


-- ─────────────────────────────────────────────────────────────
-- groups
-- ─────────────────────────────────────────────────────────────
create policy "Members can view their groups"
  on public.groups for select
  to authenticated
  using (
    exists (
      select 1 from public.group_members gm
      where gm.group_id = public.groups.id
        and gm.user_id = (select auth.uid())
    )
  );

-- groups has no created_by column by design — ownership is tracked via
-- group_members.role. WITH CHECK (true) is intentional here; the
-- TO authenticated role restriction is the real gate.
create policy "Authenticated users can create groups"
  on public.groups for insert
  to authenticated
  with check (true);

create policy "Group admins can update their group"
  on public.groups for update
  to authenticated
  using (
    exists (
      select 1 from public.group_members gm
      where gm.group_id = public.groups.id
        and gm.user_id = (select auth.uid())
        and gm.role in ('admin', 'co_admin')
    )
  )
  with check (
    exists (
      select 1 from public.group_members gm
      where gm.group_id = public.groups.id
        and gm.user_id = (select auth.uid())
        and gm.role in ('admin', 'co_admin')
    )
  );

create policy "Group admins can delete their group"
  on public.groups for delete
  to authenticated
  using (
    exists (
      select 1 from public.group_members gm
      where gm.group_id = public.groups.id
        and gm.user_id = (select auth.uid())
        and gm.role = 'admin'
    )
  );


-- ─────────────────────────────────────────────────────────────
-- group_members
-- ─────────────────────────────────────────────────────────────
create policy "Members can view their group's membership"
  on public.group_members for select
  to authenticated
  using (
    exists (
      select 1 from public.group_members gm
      where gm.group_id = public.group_members.group_id
        and gm.user_id = (select auth.uid())
    )
  );

create policy "Group admins can add members"
  on public.group_members for insert
  to authenticated
  with check (
    exists (
      select 1 from public.group_members gm
      where gm.group_id = public.group_members.group_id
        and gm.user_id = (select auth.uid())
        and gm.role in ('admin', 'co_admin')
    )
  );

create policy "Admins can update member roles"
  on public.group_members for update
  to authenticated
  using (
    exists (
      select 1 from public.group_members gm
      where gm.group_id = public.group_members.group_id
        and gm.user_id = (select auth.uid())
        and gm.role in ('admin', 'co_admin')
    )
  );

create policy "Admins can remove members, members can remove themselves"
  on public.group_members for delete
  to authenticated
  using (
    user_id = (select auth.uid())
    or exists (
      select 1 from public.group_members gm
      where gm.group_id = public.group_members.group_id
        and gm.user_id = (select auth.uid())
        and gm.role in ('admin', 'co_admin')
    )
  );


-- ─────────────────────────────────────────────────────────────
-- join_requests
-- ─────────────────────────────────────────────────────────────
create policy "Users can view their own join requests"
  on public.join_requests for select
  to authenticated
  using (user_id = (select auth.uid()));

create policy "Group admins can view join requests for their groups"
  on public.join_requests for select
  to authenticated
  using (
    exists (
      select 1 from public.group_members gm
      where gm.group_id = public.join_requests.group_id
        and gm.user_id = (select auth.uid())
        and gm.role in ('admin', 'co_admin')
    )
  );

create policy "Authenticated users can request to join a group"
  on public.join_requests for insert
  to authenticated
  with check (user_id = (select auth.uid()));

create policy "Group admins can update join requests"
  on public.join_requests for update
  to authenticated
  using (
    exists (
      select 1 from public.group_members gm
      where gm.group_id = public.join_requests.group_id
        and gm.user_id = (select auth.uid())
        and gm.role in ('admin', 'co_admin')
    )
  );

create policy "Users can cancel their own join requests"
  on public.join_requests for delete
  to authenticated
  using (user_id = (select auth.uid()));


-- ─────────────────────────────────────────────────────────────
-- events
-- ─────────────────────────────────────────────────────────────
create policy "Members can view events in their groups"
  on public.events for select
  to authenticated
  using (
    exists (
      select 1 from public.group_members gm
      where gm.group_id = public.events.group_id
        and gm.user_id = (select auth.uid())
    )
  );

create policy "Group admins can create events"
  on public.events for insert
  to authenticated
  with check (
    exists (
      select 1 from public.group_members gm
      where gm.group_id = public.events.group_id
        and gm.user_id = (select auth.uid())
        and gm.role in ('admin', 'co_admin')
    )
  );

create policy "Group admins can update events"
  on public.events for update
  to authenticated
  using (
    exists (
      select 1 from public.group_members gm
      where gm.group_id = public.events.group_id
        and gm.user_id = (select auth.uid())
        and gm.role in ('admin', 'co_admin')
    )
  );

create policy "Group admins can delete events"
  on public.events for delete
  to authenticated
  using (
    exists (
      select 1 from public.group_members gm
      where gm.group_id = public.events.group_id
        and gm.user_id = (select auth.uid())
        and gm.role in ('admin', 'co_admin')
    )
  );


-- ─────────────────────────────────────────────────────────────
-- event_rsvps
-- ─────────────────────────────────────────────────────────────
create policy "Members can view RSVPs for their events"
  on public.event_rsvps for select
  to authenticated
  using (
    exists (
      select 1 from public.events e
      join public.group_members gm on gm.group_id = e.group_id
      where e.id = public.event_rsvps.event_id
        and gm.user_id = (select auth.uid())
    )
  );

create policy "Members can RSVP to their events"
  on public.event_rsvps for insert
  to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1 from public.events e
      join public.group_members gm on gm.group_id = e.group_id
      where e.id = public.event_rsvps.event_id
        and gm.user_id = (select auth.uid())
    )
  );

create policy "Members can update their own RSVP"
  on public.event_rsvps for update
  to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy "Members can delete their own RSVP"
  on public.event_rsvps for delete
  to authenticated
  using (user_id = (select auth.uid()));


-- ─────────────────────────────────────────────────────────────
-- event_memory
-- ─────────────────────────────────────────────────────────────
create policy "Members can view event memory for their groups"
  on public.event_memory for select
  to authenticated
  using (
    exists (
      select 1 from public.events e
      join public.group_members gm on gm.group_id = e.group_id
      where e.id = public.event_memory.event_id
        and gm.user_id = (select auth.uid())
    )
  );

create policy "Group admins can insert event memory"
  on public.event_memory for insert
  to authenticated
  with check (
    exists (
      select 1 from public.events e
      join public.group_members gm on gm.group_id = e.group_id
      where e.id = public.event_memory.event_id
        and gm.user_id = (select auth.uid())
        and gm.role in ('admin', 'co_admin')
    )
  );

create policy "Group admins can update event memory"
  on public.event_memory for update
  to authenticated
  using (
    exists (
      select 1 from public.events e
      join public.group_members gm on gm.group_id = e.group_id
      where e.id = public.event_memory.event_id
        and gm.user_id = (select auth.uid())
        and gm.role in ('admin', 'co_admin')
    )
  );


-- ─────────────────────────────────────────────────────────────
-- guest_passes  (contains sensitive 'token' column)
-- ─────────────────────────────────────────────────────────────
-- Only group admins can create/view/manage guest passes.
-- Tokens must never be exposed to regular members.
create policy "Group admins can view guest passes"
  on public.guest_passes for select
  to authenticated
  using (
    exists (
      select 1 from public.events e
      join public.group_members gm on gm.group_id = e.group_id
      where e.id = public.guest_passes.event_id
        and gm.user_id = (select auth.uid())
        and gm.role in ('admin', 'co_admin')
    )
  );

create policy "Group admins can create guest passes"
  on public.guest_passes for insert
  to authenticated
  with check (
    exists (
      select 1 from public.events e
      join public.group_members gm on gm.group_id = e.group_id
      where e.id = public.guest_passes.event_id
        and gm.user_id = (select auth.uid())
        and gm.role in ('admin', 'co_admin')
    )
  );

create policy "Group admins can update guest passes"
  on public.guest_passes for update
  to authenticated
  using (
    exists (
      select 1 from public.events e
      join public.group_members gm on gm.group_id = e.group_id
      where e.id = public.guest_passes.event_id
        and gm.user_id = (select auth.uid())
        and gm.role in ('admin', 'co_admin')
    )
  );

create policy "Group admins can delete guest passes"
  on public.guest_passes for delete
  to authenticated
  using (
    exists (
      select 1 from public.events e
      join public.group_members gm on gm.group_id = e.group_id
      where e.id = public.guest_passes.event_id
        and gm.user_id = (select auth.uid())
        and gm.role in ('admin', 'co_admin')
    )
  );


-- ─────────────────────────────────────────────────────────────
-- posts
-- ─────────────────────────────────────────────────────────────
create policy "Members can view posts in their groups"
  on public.posts for select
  to authenticated
  using (
    exists (
      select 1 from public.group_members gm
      where gm.group_id = public.posts.group_id
        and gm.user_id = (select auth.uid())
    )
  );

create policy "Members can create posts"
  on public.posts for insert
  to authenticated
  with check (
    author_id = (select auth.uid())
    and exists (
      select 1 from public.group_members gm
      where gm.group_id = public.posts.group_id
        and gm.user_id = (select auth.uid())
    )
  );

create policy "Authors and admins can update posts"
  on public.posts for update
  to authenticated
  using (
    author_id = (select auth.uid())
    or exists (
      select 1 from public.group_members gm
      where gm.group_id = public.posts.group_id
        and gm.user_id = (select auth.uid())
        and gm.role in ('admin', 'co_admin')
    )
  );

create policy "Authors and admins can delete posts"
  on public.posts for delete
  to authenticated
  using (
    author_id = (select auth.uid())
    or exists (
      select 1 from public.group_members gm
      where gm.group_id = public.posts.group_id
        and gm.user_id = (select auth.uid())
        and gm.role in ('admin', 'co_admin')
    )
  );


-- ─────────────────────────────────────────────────────────────
-- post_reactions
-- ─────────────────────────────────────────────────────────────
create policy "Members can view reactions"
  on public.post_reactions for select
  to authenticated
  using (
    exists (
      select 1 from public.posts p
      join public.group_members gm on gm.group_id = p.group_id
      where p.id = public.post_reactions.post_id
        and gm.user_id = (select auth.uid())
    )
  );

create policy "Members can add reactions"
  on public.post_reactions for insert
  to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1 from public.posts p
      join public.group_members gm on gm.group_id = p.group_id
      where p.id = public.post_reactions.post_id
        and gm.user_id = (select auth.uid())
    )
  );

create policy "Users can remove their own reactions"
  on public.post_reactions for delete
  to authenticated
  using (user_id = (select auth.uid()));


-- ─────────────────────────────────────────────────────────────
-- polls
-- ─────────────────────────────────────────────────────────────
create policy "Members can view polls in their groups"
  on public.polls for select
  to authenticated
  using (
    exists (
      select 1 from public.group_members gm
      where gm.group_id = public.polls.group_id
        and gm.user_id = (select auth.uid())
    )
  );

create policy "Group admins can create polls"
  on public.polls for insert
  to authenticated
  with check (
    created_by = (select auth.uid())
    and exists (
      select 1 from public.group_members gm
      where gm.group_id = public.polls.group_id
        and gm.user_id = (select auth.uid())
        and gm.role in ('admin', 'co_admin')
    )
  );

create policy "Group admins can update polls"
  on public.polls for update
  to authenticated
  using (
    exists (
      select 1 from public.group_members gm
      where gm.group_id = public.polls.group_id
        and gm.user_id = (select auth.uid())
        and gm.role in ('admin', 'co_admin')
    )
  );

create policy "Group admins can delete polls"
  on public.polls for delete
  to authenticated
  using (
    exists (
      select 1 from public.group_members gm
      where gm.group_id = public.polls.group_id
        and gm.user_id = (select auth.uid())
        and gm.role in ('admin', 'co_admin')
    )
  );


-- ─────────────────────────────────────────────────────────────
-- poll_options
-- ─────────────────────────────────────────────────────────────
create policy "Members can view poll options"
  on public.poll_options for select
  to authenticated
  using (
    exists (
      select 1 from public.polls p
      join public.group_members gm on gm.group_id = p.group_id
      where p.id = public.poll_options.poll_id
        and gm.user_id = (select auth.uid())
    )
  );

create policy "Group admins can create poll options"
  on public.poll_options for insert
  to authenticated
  with check (
    exists (
      select 1 from public.polls p
      join public.group_members gm on gm.group_id = p.group_id
      where p.id = public.poll_options.poll_id
        and gm.user_id = (select auth.uid())
        and gm.role in ('admin', 'co_admin')
    )
  );

create policy "Group admins can delete poll options"
  on public.poll_options for delete
  to authenticated
  using (
    exists (
      select 1 from public.polls p
      join public.group_members gm on gm.group_id = p.group_id
      where p.id = public.poll_options.poll_id
        and gm.user_id = (select auth.uid())
        and gm.role in ('admin', 'co_admin')
    )
  );


-- ─────────────────────────────────────────────────────────────
-- poll_votes
-- ─────────────────────────────────────────────────────────────
create policy "Members can view poll votes"
  on public.poll_votes for select
  to authenticated
  using (
    exists (
      select 1 from public.poll_options po
      join public.polls p on p.id = po.poll_id
      join public.group_members gm on gm.group_id = p.group_id
      where po.id = public.poll_votes.poll_option_id
        and gm.user_id = (select auth.uid())
    )
  );

create policy "Members can vote in their group's polls"
  on public.poll_votes for insert
  to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1 from public.poll_options po
      join public.polls p on p.id = po.poll_id
      join public.group_members gm on gm.group_id = p.group_id
      where po.id = public.poll_votes.poll_option_id
        and gm.user_id = (select auth.uid())
    )
  );

create policy "Users can remove their own poll votes"
  on public.poll_votes for delete
  to authenticated
  using (user_id = (select auth.uid()));


-- ─────────────────────────────────────────────────────────────
-- bring_list_items
-- ─────────────────────────────────────────────────────────────
create policy "Members can view bring list items"
  on public.bring_list_items for select
  to authenticated
  using (
    exists (
      select 1 from public.events e
      join public.group_members gm on gm.group_id = e.group_id
      where e.id = public.bring_list_items.event_id
        and gm.user_id = (select auth.uid())
    )
  );

create policy "Group admins can add bring list items"
  on public.bring_list_items for insert
  to authenticated
  with check (
    exists (
      select 1 from public.events e
      join public.group_members gm on gm.group_id = e.group_id
      where e.id = public.bring_list_items.event_id
        and gm.user_id = (select auth.uid())
        and gm.role in ('admin', 'co_admin')
    )
  );

create policy "Group admins can delete bring list items"
  on public.bring_list_items for delete
  to authenticated
  using (
    exists (
      select 1 from public.events e
      join public.group_members gm on gm.group_id = e.group_id
      where e.id = public.bring_list_items.event_id
        and gm.user_id = (select auth.uid())
        and gm.role in ('admin', 'co_admin')
    )
  );


-- ─────────────────────────────────────────────────────────────
-- bring_list_claims
-- ─────────────────────────────────────────────────────────────
create policy "Members can view bring list claims"
  on public.bring_list_claims for select
  to authenticated
  using (
    exists (
      select 1 from public.bring_list_items bli
      join public.events e on e.id = bli.event_id
      join public.group_members gm on gm.group_id = e.group_id
      where bli.id = public.bring_list_claims.item_id
        and gm.user_id = (select auth.uid())
    )
  );

create policy "Members can claim items"
  on public.bring_list_claims for insert
  to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1 from public.bring_list_items bli
      join public.events e on e.id = bli.event_id
      join public.group_members gm on gm.group_id = e.group_id
      where bli.id = public.bring_list_claims.item_id
        and gm.user_id = (select auth.uid())
    )
  );

create policy "Members can unclaim their own items"
  on public.bring_list_claims for delete
  to authenticated
  using (user_id = (select auth.uid()));


-- ─────────────────────────────────────────────────────────────
-- group_lists
-- ─────────────────────────────────────────────────────────────
create policy "Members can view group lists"
  on public.group_lists for select
  to authenticated
  using (
    exists (
      select 1 from public.group_members gm
      where gm.group_id = public.group_lists.group_id
        and gm.user_id = (select auth.uid())
    )
  );

create policy "Group admins can create group lists"
  on public.group_lists for insert
  to authenticated
  with check (
    exists (
      select 1 from public.group_members gm
      where gm.group_id = public.group_lists.group_id
        and gm.user_id = (select auth.uid())
        and gm.role in ('admin', 'co_admin')
    )
  );

create policy "Group admins can update group lists"
  on public.group_lists for update
  to authenticated
  using (
    exists (
      select 1 from public.group_members gm
      where gm.group_id = public.group_lists.group_id
        and gm.user_id = (select auth.uid())
        and gm.role in ('admin', 'co_admin')
    )
  );

create policy "Group admins can delete group lists"
  on public.group_lists for delete
  to authenticated
  using (
    exists (
      select 1 from public.group_members gm
      where gm.group_id = public.group_lists.group_id
        and gm.user_id = (select auth.uid())
        and gm.role in ('admin', 'co_admin')
    )
  );


-- ─────────────────────────────────────────────────────────────
-- list_items
-- ─────────────────────────────────────────────────────────────
create policy "Members can view list items"
  on public.list_items for select
  to authenticated
  using (
    exists (
      select 1 from public.group_lists gl
      join public.group_members gm on gm.group_id = gl.group_id
      where gl.id = public.list_items.list_id
        and gm.user_id = (select auth.uid())
    )
  );

create policy "Members can add list items"
  on public.list_items for insert
  to authenticated
  with check (
    added_by = (select auth.uid())
    and exists (
      select 1 from public.group_lists gl
      join public.group_members gm on gm.group_id = gl.group_id
      where gl.id = public.list_items.list_id
        and gm.user_id = (select auth.uid())
    )
  );

create policy "Authors and admins can update list items"
  on public.list_items for update
  to authenticated
  using (
    added_by = (select auth.uid())
    or exists (
      select 1 from public.group_lists gl
      join public.group_members gm on gm.group_id = gl.group_id
      where gl.id = public.list_items.list_id
        and gm.user_id = (select auth.uid())
        and gm.role in ('admin', 'co_admin')
    )
  );

create policy "Authors and admins can delete list items"
  on public.list_items for delete
  to authenticated
  using (
    added_by = (select auth.uid())
    or exists (
      select 1 from public.group_lists gl
      join public.group_members gm on gm.group_id = gl.group_id
      where gl.id = public.list_items.list_id
        and gm.user_id = (select auth.uid())
        and gm.role in ('admin', 'co_admin')
    )
  );


-- ─────────────────────────────────────────────────────────────
-- list_item_upvotes
-- ─────────────────────────────────────────────────────────────
create policy "Members can view upvotes"
  on public.list_item_upvotes for select
  to authenticated
  using (
    exists (
      select 1 from public.list_items li
      join public.group_lists gl on gl.id = li.list_id
      join public.group_members gm on gm.group_id = gl.group_id
      where li.id = public.list_item_upvotes.item_id
        and gm.user_id = (select auth.uid())
    )
  );

create policy "Members can upvote items"
  on public.list_item_upvotes for insert
  to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1 from public.list_items li
      join public.group_lists gl on gl.id = li.list_id
      join public.group_members gm on gm.group_id = gl.group_id
      where li.id = public.list_item_upvotes.item_id
        and gm.user_id = (select auth.uid())
    )
  );

create policy "Users can remove their own upvotes"
  on public.list_item_upvotes for delete
  to authenticated
  using (user_id = (select auth.uid()));


-- ─────────────────────────────────────────────────────────────
-- notifications
-- ─────────────────────────────────────────────────────────────
create policy "Users can view their own notifications"
  on public.notifications for select
  to authenticated
  using (user_id = (select auth.uid()));

create policy "Users can mark their notifications as read"
  on public.notifications for update
  to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy "Users can delete their own notifications"
  on public.notifications for delete
  to authenticated
  using (user_id = (select auth.uid()));


-- ─────────────────────────────────────────────────────────────
-- notification_preferences
-- ─────────────────────────────────────────────────────────────
create policy "Users can view their own notification preferences"
  on public.notification_preferences for select
  to authenticated
  using (user_id = (select auth.uid()));

create policy "Users can insert their own notification preferences"
  on public.notification_preferences for insert
  to authenticated
  with check (user_id = (select auth.uid()));

create policy "Users can update their own notification preferences"
  on public.notification_preferences for update
  to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));


-- ─────────────────────────────────────────────────────────────
-- direct_messages
-- ─────────────────────────────────────────────────────────────
create policy "Users can view messages they sent or received"
  on public.direct_messages for select
  to authenticated
  using (
    sender_id = (select auth.uid())
    or recipient_id = (select auth.uid())
  );

create policy "Users can send messages as themselves"
  on public.direct_messages for insert
  to authenticated
  with check (sender_id = (select auth.uid()));

create policy "Users can delete their own sent messages"
  on public.direct_messages for delete
  to authenticated
  using (sender_id = (select auth.uid()));


-- ─────────────────────────────────────────────────────────────
-- waitlist  (fix: replace WITH CHECK (true) with explicit check)
-- ─────────────────────────────────────────────────────────────
-- Drop the existing overly-permissive policy.
drop policy if exists "Allow public to join waitlist" on public.waitlist;

-- Unauthenticated visitors may INSERT only — no SELECT exposure.
create policy "Anon can join waitlist"
  on public.waitlist for insert
  to anon
  with check (email is not null and email <> '');

create policy "Authenticated can join waitlist"
  on public.waitlist for insert
  to authenticated
  with check (email is not null and email <> '');

-- No SELECT policy for anon/authenticated; only service_role can read the list.
