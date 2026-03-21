<script>
  import { supabase } from '$lib/supabase'
  import { onMount } from 'svelte'
  import { goto } from '$app/navigation'

 let loading = $state(true)
let feedItems = $state([])
let upcomingEvents = $state([])
let userName = $state('')

  onMount(async () => {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return

    // Get user display name
    const { data: profile } = await supabase
      .from('users')
      .select('display_name')
      .eq('id', user.id)
      .single()

    userName = profile?.display_name?.split(' ')[0] ?? 'there'

    // Get groups the user belongs to
    const { data: memberships } = await supabase
      .from('group_members')
      .select('group_id')
      .eq('user_id', user.id)

    const groupIds = memberships?.map(m => m.group_id) ?? []

    if (groupIds.length === 0) {
      loading = false
      return
    }

    // Get upcoming events (next 30 days)
    const now = new Date().toISOString()
    const in30 = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString()

    const { data: events } = await supabase
      .from('events')
      .select('id, title, event_date, location, group_id, groups(name)')
      .in('group_id', groupIds)
      .eq('status', 'confirmed')
      .gte('event_date', now)
      .lte('event_date', in30)
      .order('event_date', { ascending: true })
      .limit(3)

    upcomingEvents = events ?? []

    // Get recent posts (last 7 days)
    const weekAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString()

    const { data: posts } = await supabase
      .from('posts')
      .select('id, body, created_at, group_id, is_deleted, groups(name), users(display_name, avatar_url)')
      .in('group_id', groupIds)
      .eq('is_deleted', false)
      .is('parent_id', null)
      .gte('created_at', weekAgo)
      .order('created_at', { ascending: false })
      .limit(5)

    // Get recent new members (last 7 days)
    const { data: newMembers } = await supabase
      .from('group_members')
      .select('joined_at, group_id, groups(name), users(display_name, avatar_url)')
      .in('group_id', groupIds)
      .gte('joined_at', weekAgo)
      .neq('user_id', user.id)
      .order('joined_at', { ascending: false })
      .limit(5)

    // Combine and sort feed
    const postItems = (posts ?? []).map(p => ({
      type: 'post',
      id: p.id,
      groupName: p.groups?.name,
      groupId: p.group_id,
      author: p.users?.display_name,
      authorAvatar: p.users?.avatar_url ?? null,
      body: p.body,
      time: p.created_at,
    }))

    const memberItems = (newMembers ?? []).map(m => ({
      type: 'member',
      id: m.joined_at + m.group_id,
      groupName: m.groups?.name,
      groupId: m.group_id,
      author: m.users?.display_name,
      authorAvatar: m.users?.avatar_url ?? null,
      time: m.joined_at,
    }))

    feedItems = [...postItems, ...memberItems].sort(
      (a, b) => new Date(b.time) - new Date(a.time)
    )

    loading = false
  })

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

  function formatEventDate(dateStr) {
    const d = new Date(dateStr)
    return d.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' })
  }

  function formatEventTime(dateStr) {
    const d = new Date(dateStr)
    return d.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })
  }

  function truncate(str, n = 120) {
    if (!str) return ''
    return str.length > n ? str.slice(0, n) + '…' : str
  }
</script>

<div class="max-w-2xl mx-auto px-4 py-6">

  <!-- Header -->
  <div class="mb-6">
    <h1 class="text-xl font-semibold text-foreground">Hey {userName} 👋</h1>
    <p class="text-sm text-muted-foreground mt-0.5">Here's what's happening in your groups.</p>
  </div>

  {#if loading}
    <!-- Loading skeleton -->
    <div class="flex flex-col gap-3">
      {#each [1,2,3] as _}
        <div class="rounded-xl border border-border p-4 animate-pulse">
          <div class="h-3 bg-muted rounded w-1/3 mb-3"></div>
          <div class="h-4 bg-muted rounded w-2/3 mb-2"></div>
          <div class="h-3 bg-muted rounded w-1/2"></div>
        </div>
      {/each}
    </div>

  {:else if upcomingEvents.length === 0 && feedItems.length === 0}
    <!-- Empty state -->
    <div class="flex flex-col items-center justify-center text-center py-16 px-4">
      <div class="w-16 h-16 rounded-2xl flex items-center justify-center mb-4" style="background: hsl(234 40% 97%)">
        <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="hsl(234 26% 41%)" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
          <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
          <circle cx="9" cy="7" r="4"/>
          <path d="M23 21v-2a4 4 0 0 0-3-3.87"/>
          <path d="M16 3.13a4 4 0 0 1 0 7.75"/>
        </svg>
      </div>
      <h2 class="text-base font-semibold text-foreground mb-1">No activity yet</h2>
      <p class="text-sm text-muted-foreground mb-6 max-w-xs">Create your first group and invite your people to get started.</p>
      <button
        onclick={() => goto('/groups/new')}
        class="px-5 py-2.5 rounded-xl text-sm font-semibold text-white"
        style="background: hsl(234 26% 41%)"
      >
        Create a group
      </button>
    </div>

  {:else}
    <!-- Upcoming events strip -->
    {#if upcomingEvents.length > 0}
      <div class="mb-6">
        <h2 class="text-xs font-semibold uppercase tracking-wider text-muted-foreground mb-3">Coming up</h2>
        <div class="flex flex-col gap-2">
          {#each upcomingEvents as event}
            <a href="/groups/{event.group_id}/events/{event.id}" class="flex items-center gap-4 rounded-xl border border-border bg-background p-4 hover:bg-muted/30 transition-colors">
              <!-- Date block -->
              <div class="flex flex-col items-center justify-center w-12 h-12 rounded-lg shrink-0" style="background: hsl(234 40% 97%)">
                <span class="text-xs font-medium" style="color: hsl(234 26% 41%)">{new Date(event.event_date).toLocaleDateString('en-US', { month: 'short' })}</span>
                <span class="text-lg font-bold leading-none" style="color: hsl(234 26% 41%)">{new Date(event.event_date).getDate()}</span>
              </div>
              <!-- Details -->
              <div class="flex-1 min-w-0">
                <p class="text-sm font-semibold text-foreground truncate">{event.title}</p>
                <p class="text-xs text-muted-foreground mt-0.5">{event.groups?.name} · {formatEventTime(event.event_date)}</p>
                {#if event.location}
                  <p class="text-xs text-muted-foreground truncate">{event.location}</p>
                {/if}
              </div>
              <!-- Arrow -->
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="hsl(234 12% 52%)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <polyline points="9 18 15 12 9 6"/>
              </svg>
            </a>
          {/each}
        </div>
      </div>
    {/if}

    <!-- Activity feed -->
    {#if feedItems.length > 0}
      <div>
        <h2 class="text-xs font-semibold uppercase tracking-wider text-muted-foreground mb-3">Recent activity</h2>
        <div class="flex flex-col gap-2">
          {#each feedItems as item}
            <a
              href={item.type === 'post' ? `/groups/${item.groupId}/board` : `/groups/${item.groupId}/members`}
              class="rounded-xl border border-border bg-background p-4 block hover:bg-muted/30 transition-colors"
            >

              <!-- Group badge + time -->
              <div class="flex items-center justify-between mb-2">
                <span class="text-xs font-medium px-2 py-0.5 rounded-full" style="background: hsl(234 40% 97%); color: hsl(234 26% 41%)">
                  {item.groupName}
                </span>
                <span class="text-xs text-muted-foreground">{timeAgo(item.time)}</span>
              </div>

              <div class="flex items-center gap-2 mb-1">
                {#if item.authorAvatar}
                  <img src={item.authorAvatar} alt={item.author} class="w-6 h-6 rounded-full object-cover shrink-0" />
                {:else}
                  <div class="w-6 h-6 rounded-full flex items-center justify-center text-white shrink-0" style="background: hsl(234 26% 41%); font-size: 9px; font-weight: 700">
                    {item.author?.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2) ?? '?'}
                  </div>
                {/if}
                <span class="text-sm font-medium text-foreground">{item.author}</span>
              </div>
              {#if item.type === 'post'}
                <p class="text-sm text-muted-foreground">{truncate(item.body)}</p>
              {:else if item.type === 'member'}
                <p class="text-sm text-muted-foreground">joined the group</p>
              {/if}

            </a>
          {/each}
        </div>
      </div>
    {/if}

  {/if}
</div>