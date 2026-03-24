<script>
  import { supabase } from '$lib/supabase'
  import { page } from '$app/stores'
  import { goto } from '$app/navigation'
  import { onMount } from 'svelte'

  let groupId = $derived($page.params.id)
  let upcomingEvents = $state([])
  let pastEvents = $state([])
  let loading = $state(true)
  let currentUserRole = $state(null)
  let showPast = $state(false)

  onMount(async () => {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) { goto('/auth/login'); return }

    const { data: membership } = await supabase
      .from('group_members')
      .select('role')
      .eq('group_id', groupId)
      .eq('user_id', user.id)
      .single()

    currentUserRole = membership?.role ?? null

    const now = new Date().toISOString()

    const { data: upcoming } = await supabase
      .from('events')
      .select('id, title, event_date, location, status, cover_photo_url, host_user_id, users(display_name)')
      .eq('group_id', groupId)
      .in('status', ['confirmed', 'pending_date'])
      .gte('event_date', now)
      .order('event_date', { ascending: true })

    upcomingEvents = upcoming ?? []

    const { data: past } = await supabase
      .from('events')
      .select('id, title, event_date, location, status, host_user_id, users(display_name)')
      .eq('group_id', groupId)
      .lt('event_date', now)
      .order('event_date', { ascending: false })
      .limit(10)

    pastEvents = past ?? []
    loading = false
  })

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

  let isAdmin = $derived(currentUserRole === 'admin' || currentUserRole === 'co_admin')
</script>

<div class="max-w-2xl mx-auto px-4 py-6">

  <div class="flex items-center justify-between mb-6">
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

  {#if loading}
    <div class="flex flex-col gap-3">
      {#each [1,2] as _}
        <div class="rounded-xl border border-border p-4 animate-pulse">
          <div class="h-3 bg-muted rounded w-1/4 mb-3"></div>
          <div class="h-4 bg-muted rounded w-2/3 mb-2"></div>
          <div class="h-3 bg-muted rounded w-1/3"></div>
        </div>
      {/each}
    </div>

  {:else}

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
      <div class="flex flex-col gap-3 mb-6">
        {#each upcomingEvents as event}
          <button
            onclick={() => goto(`/groups/${groupId}/events/${event.id}`)}
            class="flex items-center gap-4 rounded-xl bg-background p-4 text-left hover:bg-muted/30 transition-colors w-full"
          >
            <!-- Photo or date block -->
            <div class="w-11 h-11 rounded-full shrink-0 overflow-hidden" style="background: {event.status === 'pending_date' ? 'hsl(35 100% 95%)' : 'hsl(220 14% 93%)'}">
              {#if event.cover_photo_url}
                <img src={event.cover_photo_url} alt={event.title} class="w-full h-full object-cover" />
              {:else if event.status === 'pending_date'}
                <div class="w-full h-full flex items-center justify-center">
                  <span class="text-lg font-bold leading-none" style="color: hsl(35 80% 50%)">?</span>
                </div>
              {:else}
                <div class="w-full h-full flex flex-col items-center justify-center gap-0 select-none">
                  <span class="font-semibold uppercase tracking-widest leading-none" style="font-size: 8px; color: hsl(220 9% 65%)">{new Date(event.event_date).toLocaleDateString('en-US', { month: 'short' })}</span>
                  <span class="font-bold leading-none mt-0.5" style="font-size: 1.25rem; color: hsl(220 9% 50%)">{new Date(event.event_date).getDate()}</span>
                </div>
              {/if}
            </div>

            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2 mb-0.5">
                <p class="text-sm font-semibold text-foreground truncate">{event.title}</p>
                {#if event.status === 'pending_date'}
                  <span class="text-xs px-2 py-0.5 rounded-full shrink-0" style="background: hsl(35 100% 97%); color: hsl(35 80% 40%)">Vote on date</span>
                {/if}
              </div>
              {#if event.status !== 'pending_date'}
                <p class="text-xs text-muted-foreground mt-0.5">{formatDate(event.event_date)} · {formatTime(event.event_date)}</p>
              {/if}
              {#if event.location}
                <div class="flex items-center gap-1.5 mt-0.5">
                  <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="hsl(234 12% 80%)" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/>
                  </svg>
                  <span class="text-xs text-muted-foreground truncate">{event.location}</span>
                </div>
              {/if}
              {#if event.users?.display_name}
                <div class="flex items-center gap-1.5 mt-0.5">
                  <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="hsl(234 12% 80%)" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/>
                  </svg>
                  <span class="text-xs text-muted-foreground">{event.users.display_name}</span>
                </div>
              {/if}
            </div>

            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="hsl(234 12% 52%)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="shrink-0">
              <polyline points="9 18 15 12 9 6"/>
            </svg>
          </button>
        {/each}
      </div>
    {/if}

    <!-- Past events -->
    {#if pastEvents.length > 0}
      <button
        onclick={() => showPast = !showPast}
        class="flex items-center gap-2 text-sm font-medium mb-3"
        style="color: hsl(234 12% 52%)"
      >
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"
          style="transform: rotate({showPast ? 90 : 0}deg); transition: transform 0.2s">
          <polyline points="9 18 15 12 9 6"/>
        </svg>
        Past events ({pastEvents.length})
      </button>

      {#if showPast}
        <div class="flex flex-col gap-2">
          {#each pastEvents as event}
            <button
              onclick={() => goto(`/groups/${groupId}/events/${event.id}`)}
              class="flex items-center gap-4 rounded-xl bg-background p-4 text-left hover:bg-muted/30 transition-colors w-full opacity-60"
            >
              <div class="flex flex-col items-center justify-center w-12 h-12 rounded-lg bg-muted shrink-0">
                <span class="text-xs font-medium text-muted-foreground">{new Date(event.event_date).toLocaleDateString('en-US', { month: 'short' })}</span>
                <span class="text-lg font-bold leading-none text-muted-foreground">{new Date(event.event_date).getDate()}</span>
              </div>
              <div class="flex-1 min-w-0">
                <p class="text-sm font-semibold text-foreground truncate">{event.title}</p>
                <p class="text-xs text-muted-foreground">{formatDate(event.event_date)}</p>
              </div>
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="hsl(234 12% 52%)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="shrink-0">
                <polyline points="9 18 15 12 9 6"/>
              </svg>
            </button>
          {/each}
        </div>
      {/if}
    {/if}

  {/if}
</div>