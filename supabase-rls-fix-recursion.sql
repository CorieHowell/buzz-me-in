-- =============================================================
-- Buzz Me In — RLS Recursion Fix
-- Run this in Supabase SQL Editor AFTER supabase-rls-migration.sql
-- =============================================================
-- Problem: the group_members SELECT policy queries group_members
-- from within itself, causing infinite recursion. Every other
-- table's policy joins to group_members, so all data disappeared.
--
-- Fix: a SECURITY DEFINER function that checks membership without
-- going through RLS, breaking the recursion.
-- =============================================================


-- ─────────────────────────────────────────────────────────────
-- Helper function: returns true if the current user is a member
-- of the given group. SECURITY DEFINER bypasses RLS on the
-- group_members table, so this never recurses.
-- ─────────────────────────────────────────────────────────────
create or replace function public.is_group_member(gid uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.group_members
    where group_id = gid
      and user_id = auth.uid()
  );
$$;

-- Revoke execute from public/anon; only authenticated users need it.
revoke execute on function public.is_group_member(uuid) from public, anon;
grant execute on function public.is_group_member(uuid) to authenticated;


-- ─────────────────────────────────────────────────────────────
-- Fix group_members SELECT policy (was self-referential)
-- ─────────────────────────────────────────────────────────────
drop policy if exists "Members can view their group's membership" on public.group_members;

create policy "Members can view their group's membership"
  on public.group_members for select
  to authenticated
  using (public.is_group_member(group_id));
