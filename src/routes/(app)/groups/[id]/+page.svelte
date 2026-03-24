<script>
  import { supabase } from '$lib/supabase'
  import { page } from '$app/stores'
  import { goto } from '$app/navigation'
  import { onMount } from 'svelte'

  let groupId = $derived($page.params.id)
  let group = $state(null)
  let members = $state([])
  let nextEvent = $state(null)
  let pinnedPosts = $state([])
  let recentPosts = $state([])
  let currentUserId = $state(null)
  let currentUserRole = $state(null)
  let loading = $state(true)
  let error = $state('')

  onMount(async () => {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) { goto('/auth/login'); return }
    currentUserId = user.id
  })

  $effect(() => {
    if (!groupId || !currentUserId) return
    loading = true
    error = ''
    ;(async () => {
      // Load group
      const { data: groupData, error: groupError } = await supabase
        .from('groups')
        .select('*')
        .eq('id', groupId)
        .single()

      if (groupError || !groupData) { error = 'Group not found.'; loading = false; return }
      group = groupData

      // Load members
      const { data: memberData } = await supabase
        .from('group_members')
        .select('user_id, role, joined_at, users(display_name, avatar_url)')
        .eq('group_id', groupId)
        .order('joined_at', { ascending: true })

      members = memberData ?? []
      const me = members.find(m => m.user_id === currentUserId)
      currentUserRole = me?.role ?? null

      // Load next event
      const { data: eventData } = await supabase
        .from('events')
        .select('id, title, event_date, location, status')
        .eq('group_id', groupId)
        .eq('status', 'confirmed')
        .gte('event_date', new Date().toISOString())
        .order('event_date', { ascending: true })
        .limit(1)

      nextEvent = eventData?.[0] ?? null

      // Load pinned posts
      const { data: pinned } = await supabase
        .from('posts')
        .select('id, body, created_at, users(display_name, avatar_url)')
        .eq('group_id', groupId)
        .eq('is_announcement', true)
        .eq('is_deleted', false)
        .order('created_at', { ascending: false })
        .limit(3)

      pinnedPosts = pinned ?? []

      // Load recent board posts
      const { data: posts } = await supabase
        .from('posts')
        .select('id, body, created_at, is_edited, users(display_name, avatar_url)')
        .eq('group_id', groupId)
        .eq('is_deleted', false)
        .is('parent_id', null)
        .order('created_at', { ascending: false })
        .limit(10)

      recentPosts = posts ?? []
      loading = false
    })()
  })

  function formatEventDate(dateStr) {
    const d = new Date(dateStr)
    return d.toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' })
  }

  function formatEventTime(dateStr) {
    return new Date(dateStr).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })
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

  function initials(name) {
    if (!name) return '?'
    return name.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2)
  }

  let isAdmin = $derived(currentUserRole === 'admin' || currentUserRole === 'co_admin')
</script>

<div class="max-w-2xl mx-auto px-4 py-6">

  {#if loading}
    <div class="flex flex-col gap-4">
      {#each [1,2,3] as _}
        <div class="rounded-xl bg-white p-4 animate-pulse">
          <div class="h-3 bg-muted rounded w-1/3 mb-3"></div>
          <div class="h-4 bg-muted rounded w-2/3"></div>
        </div>
      {/each}
    </div>

  {:else if error}
    <div class="text-center py-16">
      <p class="text-sm text-destructive">{error}</p>
      <button onclick={() => goto('/groups')} class="mt-4 text-sm underline" style="color: hsl(234 26% 41%)">Back to groups</button>
    </div>

  {:else}

    <!-- Next event -->
    {#if nextEvent}
      <div class="rounded-xl p-4 mb-4" style="background: hsl(234 20% 91%)">
        <div class="flex items-start justify-between">
          <div>
            <p class="text-xs font-semibold uppercase tracking-wider mb-1" style="color: hsl(234 26% 41%)">Next event</p>
            <p class="text-lg font-bold text-foreground">{nextEvent.title}</p>
            <p class="text-sm text-muted-foreground mt-0.5">{formatEventDate(nextEvent.event_date)} at {formatEventTime(nextEvent.event_date)}</p>
            {#if nextEvent.location}
              <p class="text-sm text-muted-foreground">{nextEvent.location}</p>
            {/if}
          </div>
          <a href="/groups/{groupId}/events/{nextEvent.id}" class="shrink-0 ml-3">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="hsl(234 26% 41%)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <polyline points="9 18 15 12 9 6"/>
            </svg>
          </a>
        </div>
      </div>
    {:else}
      <div class="rounded-xl bg-white p-4 mb-4 flex items-center justify-between">
        <div>
          <p class="text-sm font-medium text-foreground">No upcoming events</p>
          <p class="text-xs text-muted-foreground mt-0.5">Create the first one for your group.</p>
        </div>
        {#if isAdmin}
          <a
            href="/groups/{groupId}/events/new"
            class="px-3 py-1.5 rounded-lg text-xs font-semibold text-white shrink-0 ml-3"
            style="background: hsl(234 26% 41%)"
          >
            Add event
          </a>
        {/if}
      </div>
    {/if}

    <!-- Pinned posts -->
    {#if pinnedPosts.length > 0}
      <div class="rounded-xl bg-white p-4 mb-4">
        <div class="flex items-center gap-2 mb-3">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="hsl(234 26% 41%)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <line x1="12" y1="17" x2="12" y2="22"/><path d="M5 17h14v-1.76a2 2 0 0 0-1.11-1.79l-1.78-.9A2 2 0 0 1 15 10.76V6h1a2 2 0 0 0 0-4H8a2 2 0 0 0 0 4h1v4.76a2 2 0 0 1-1.11 1.79l-1.78.9A2 2 0 0 0 5 15.24Z"/>
          </svg>
          <span class="text-xs font-semibold uppercase tracking-wider" style="color: hsl(234 26% 41%)">Pinned</span>
        </div>
        {#each pinnedPosts as post, i}
          <div class="py-2 {i < pinnedPosts.length - 1 ? 'border-b border-border' : ''}">
            <p class="text-sm text-foreground">{post.body}</p>
            <p class="text-xs text-muted-foreground mt-1">{post.users?.display_name} · {timeAgo(post.created_at)}</p>
          </div>
        {/each}
      </div>
    {/if}

    <!-- Message board -->
    <div class="flex items-center justify-between mb-3">
      <h2 class="text-sm font-semibold text-foreground">Board</h2>
      <a href="/groups/{groupId}/post/new" class="text-xs font-medium" style="color: hsl(234 26% 41%)">
        + New post
      </a>
    </div>

    {#if recentPosts.length === 0}
      <div class="rounded-xl bg-white p-6 text-center">
        <p class="text-sm text-muted-foreground">No posts yet. Be the first to post!</p>
        <a
          href="/groups/{groupId}/post/new"
          class="inline-block mt-3 px-4 py-2 rounded-xl text-sm font-semibold text-white"
          style="background: hsl(234 26% 41%)"
        >
          Write a post
        </a>
      </div>
    {:else}
      <div class="flex flex-col gap-2">
        {#each recentPosts as post}
          <div class="rounded-xl bg-white p-4 hover:bg-gray-50 transition-colors cursor-pointer" onclick={() => goto(`/groups/${groupId}/posts/${post.id}`)}>
            <div class="flex items-center justify-between mb-1.5">
              <div class="flex items-center gap-2">
                <span class="text-sm font-medium text-foreground">{post.users?.display_name}</span>
              </div>
              <span class="text-xs text-muted-foreground">{timeAgo(post.created_at)}</span>
            </div>
            <p class="text-sm text-foreground line-clamp-2">{post.body}</p>
            {#if post.is_edited}
              <p class="text-xs text-muted-foreground mt-1">Edited</p>
            {/if}
          </div>
        {/each}
      </div>
    {/if}

  {/if}
</div>