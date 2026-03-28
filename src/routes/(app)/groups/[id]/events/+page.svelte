<script>
  import { supabase } from '$lib/supabase'
  import { page } from '$app/stores'
  import { goto } from '$app/navigation'
  import { onMount } from 'svelte'
  import EventCard from '$lib/components/EventCard.svelte'

  let groupId = $derived($page.params.id)
  let upcomingEvents = $state([])
  let pastEvents = $state([])
  let drafts = $state([])
  let loading = $state(true)
  let currentUserRole = $state(null)
  let activeFilter = $state('upcoming')
  let userId = $state(null)

  let isAdmin = $derived(currentUserRole === 'admin' || currentUserRole === 'co_admin')

  onMount(async () => {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) { goto('/auth/login'); return }
    userId = user.id

    const { data: membership } = await supabase
      .from('group_members')
      .select('role')
      .eq('group_id', groupId)
      .eq('user_id', user.id)
      .single()

    currentUserRole = membership?.role ?? null

    const now = new Date().toISOString()

    const [upcomingRes, pastRes, draftsRes] = await Promise.all([
      supabase
        .from('events')
        .select('id, title, event_date, location, status, cover_photo_url, host_user_id, users(display_name)')
        .eq('group_id', groupId)
        .in('status', ['confirmed', 'pending_date'])
        .gte('event_date', now)
        .order('event_date', { ascending: true }),

      supabase
        .from('events')
        .select('id, title, event_date, location, status, cover_photo_url, host_user_id, users(display_name)')
        .eq('group_id', groupId)
        .neq('status', 'draft')
        .neq('status', 'cancelled')
        .lt('event_date', now)
        .order('event_date', { ascending: false })
        .limit(10),

      // Only fetch drafts — they'll only be shown to admins
      supabase
        .from('events')
        .select('id, title, created_at, datetime_mode, location_mode, bring_list_mode')
        .eq('group_id', groupId)
        .eq('status', 'draft')
        .order('created_at', { ascending: false }),
    ])

    if (upcomingRes.data?.length > 0) {
      const ids = upcomingRes.data.map(e => e.id)
      const { data: myRsvps } = await supabase
        .from('event_rsvps').select('event_id, rsvp')
        .eq('user_id', user.id).in('event_id', ids)
      const rsvpMap = Object.fromEntries((myRsvps ?? []).map(r => [r.event_id, r.rsvp]))
      upcomingEvents = upcomingRes.data.map(e => ({ ...e, myRsvp: rsvpMap[e.id] ?? null, rsvps: [] }))
    } else {
      upcomingEvents = []
    }
    pastEvents = pastRes.data?.map(e => ({ ...e, myRsvp: null, rsvps: [] })) ?? []
    drafts = draftsRes.data ?? []
    loading = false
  })

  async function setRsvp(eventId, value) {
    upcomingEvents = upcomingEvents.map(e => e.id === eventId ? { ...e, myRsvp: value || null } : e)
    if (value) {
      await supabase.from('event_rsvps').upsert({ event_id: eventId, user_id: (await supabase.auth.getUser()).data.user.id, rsvp: value }, { onConflict: 'event_id,user_id' })
    } else {
      const uid = (await supabase.auth.getUser()).data.user.id
      await supabase.from('event_rsvps').delete().eq('event_id', eventId).eq('user_id', uid)
    }
  }

  function formatDate(dateStr) {
    return new Date(dateStr).toLocaleDateString('en-US', {
      weekday: 'short', month: 'short', day: 'numeric'
    })
  }

  function formatTime(dateStr) {
    return new Date(dateStr).toLocaleTimeString('en-US', {
      hour: 'numeric', minute: '2-digit'
    })
  }

  function timeAgo(dateStr) {
    const diff = Date.now() - new Date(dateStr).getTime()
    const mins = Math.floor(diff / 60000)
    const hours = Math.floor(mins / 60)
    const days = Math.floor(hours / 24)
    if (mins < 1) return 'just now'
    if (mins < 60) return `${mins}m ago`
    if (hours < 24) return `${hours}h ago`
    return `${days}d ago`
  }

  function isDraftIncomplete(draft) {
    return !draft.datetime_mode || !draft.location_mode
  }
</script>

<div class="max-w-2xl mx-auto px-4 py-6">

  <div class="flex items-center justify-between mb-4">
    <h2 class="text-base font-semibold text-foreground">Events</h2>
    {#if isAdmin}
      <a
        href="/groups/{groupId}/events/new"
        class="px-4 py-2 rounded-xl text-sm font-semibold text-white"
        style="background: hsl(234 26% 41%)"
      >
        + New event
      </a>
    {/if}
  </div>

  <!-- Pill filters -->
  <div class="flex gap-2 mb-6">
    {#each ['upcoming', 'past'] as filter}
      <button
        onclick={() => activeFilter = filter}
        class="px-3.5 py-1.5 rounded-full text-xs font-medium transition-all flex items-center gap-1"
        style={activeFilter === filter
          ? 'background: white; border: 1.5px solid hsl(234 20% 78%); color: hsl(234 26% 41%)'
          : 'background: white; border: 1.5px solid transparent; color: hsl(234 20% 65%)'}
      >
        {filter === 'upcoming' ? 'Upcoming' : 'Past'}
        <span class="opacity-75 text-[10px]">({filter === 'upcoming' ? upcomingEvents.length : pastEvents.length})</span>
      </button>
    {/each}
    {#if isAdmin}
      <button
        onclick={() => activeFilter = 'drafts'}
        class="px-3.5 py-1.5 rounded-full text-xs font-medium transition-all flex items-center gap-1"
        style={activeFilter === 'drafts'
          ? 'background: white; border: 1.5px solid hsl(234 20% 78%); color: hsl(234 26% 41%)'
          : 'background: white; border: 1.5px solid transparent; color: hsl(234 20% 65%)'}
      >
        Drafts
        <span class="opacity-75 text-[10px]">({drafts.length})</span>
      </button>
    {/if}
  </div>

  {#if loading}
    <div class="flex flex-col gap-3">
      {#each [1,2] as _}
        <div class="rounded-xl bg-white p-4 animate-pulse">
          <div class="h-3 bg-muted rounded w-1/4 mb-3"></div>
          <div class="h-4 bg-muted rounded w-2/3 mb-2"></div>
          <div class="h-3 bg-muted rounded w-1/3"></div>
        </div>
      {/each}
    </div>

  {:else if activeFilter === 'upcoming'}

    {#if upcomingEvents.length === 0}
      <div class="text-center py-12 rounded-xl bg-white">
        <p class="text-sm text-muted-foreground mb-1">No upcoming events</p>
        {#if isAdmin}
          <a
            href="/groups/{groupId}/events/new"
            class="text-sm font-medium"
            style="color: hsl(234 26% 41%)"
          >
            Create the first one
          </a>
        {/if}
      </div>
    {:else}
      <div class="flex flex-col gap-3">
        {#each upcomingEvents as event}
          <EventCard {event} context="group" onRsvp={setRsvp} />
        {/each}
      </div>
    {/if}

  {:else if activeFilter === 'past'}

    {#if pastEvents.length === 0}
      <div class="text-center py-12 rounded-xl bg-white">
        <p class="text-sm text-muted-foreground">No past events</p>
      </div>
    {:else}
      <div class="flex flex-col gap-2">
        {#each pastEvents as event}
          <EventCard {event} context="group" onRsvp={() => {}} />
        {/each}
      </div>
    {/if}

  {:else if activeFilter === 'drafts'}

    {#if drafts.length === 0}
      <div class="text-center py-12 rounded-xl bg-white">
        <p class="text-sm text-muted-foreground mb-1">No drafts</p>
        <a
          href="/groups/{groupId}/events/new"
          class="text-sm font-medium"
          style="color: hsl(234 26% 41%)"
        >
          Create an event
        </a>
      </div>
    {:else}
      <div class="flex flex-col gap-3">
        {#each drafts as draft}
          <button
            onclick={() => goto(`/groups/${groupId}/events/new?draft=${draft.id}`)}
            class="flex items-center gap-4 rounded-xl bg-white p-4 text-left hover:bg-gray-50 transition-colors w-full"
          >
            <div class="flex flex-col items-center justify-center w-12 h-12 rounded-lg shrink-0" style="background: hsl(234 40% 97%)">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="hsl(234 26% 41%)" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/>
                <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/>
              </svg>
            </div>

            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2 mb-0.5">
                <p class="text-sm font-semibold text-foreground truncate">{draft.title || 'Untitled'}</p>
                {#if isDraftIncomplete(draft)}
                  <span class="text-xs px-2 py-0.5 rounded-full shrink-0" style="background: hsl(35 100% 97%); color: hsl(35 80% 40%)">Incomplete</span>
                {/if}
              </div>
              <p class="text-xs text-muted-foreground">Created {timeAgo(draft.created_at)}</p>
            </div>

            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="hsl(234 12% 52%)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="shrink-0">
              <polyline points="9 18 15 12 9 6"/>
            </svg>
          </button>
        {/each}
      </div>
    {/if}

  {/if}
</div>
