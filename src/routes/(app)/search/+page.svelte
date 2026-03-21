<script>
  import { supabase } from '$lib/supabase'
  import { page } from '$app/stores'
  import { goto } from '$app/navigation'
  import { onMount } from 'svelte'

  let userId = $state(null)
  let loading = $state(false)
  let groups = $state([])
  let events = $state([])
  let members = $state([])

  let query = $derived($page.url.searchParams.get('q') ?? '')

  onMount(async () => {
    const { data: { session } } = await supabase.auth.getSession()
    if (!session) { goto('/auth/login'); return }
    userId = session.user.id
  })

  $effect(() => {
    if (query && userId) runSearch(query)
  })

  async function runSearch(q) {
    if (!q.trim() || !userId) return
    loading = true
    groups = []
    events = []
    members = []

    // Get the user's group IDs
    const { data: memberData } = await supabase
      .from('group_members')
      .select('group_id')
      .eq('user_id', userId)

    const groupIds = (memberData ?? []).map(m => m.group_id)

    if (groupIds.length === 0) {
      loading = false
      return
    }

    // Run all searches in parallel
    const [groupsRes, eventsRes, groupMembersRes] = await Promise.all([
      supabase
        .from('groups')
        .select('id, name, avatar_url')
        .in('id', groupIds)
        .ilike('name', `%${q}%`)
        .limit(10),

      supabase
        .from('events')
        .select('id, title, event_date, group_id, groups(name)')
        .in('group_id', groupIds)
        .ilike('title', `%${q}%`)
        .order('event_date', { ascending: true })
        .limit(10),

      supabase
        .from('group_members')
        .select('user_id')
        .in('group_id', groupIds)
        .neq('user_id', userId),
    ])

    // Deduplicate member user IDs, then search users by display_name
    const memberUserIds = [...new Set((groupMembersRes.data ?? []).map(m => m.user_id))]
    let membersRes = { data: [] }
    if (memberUserIds.length > 0) {
      membersRes = await supabase
        .from('users')
        .select('id, display_name, avatar_url')
        .in('id', memberUserIds)
        .ilike('display_name', `%${q}%`)
        .limit(10)
    }

    groups = groupsRes.data ?? []
    events = eventsRes.data ?? []
    members = membersRes.data ?? []
    loading = false
  }

  function formatDate(dateStr) {
    if (!dateStr) return ''
    return new Date(dateStr).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
  }

  function initials(name) {
    if (!name) return '?'
    return name.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2)
  }

  let hasResults = $derived(groups.length > 0 || events.length > 0 || members.length > 0)
</script>

<div class="max-w-2xl mx-auto px-4 py-8">

  <h1 class="text-xl font-semibold text-foreground mb-1">
    {#if query}Search results for <span class="text-primary">"{query}"</span>{:else}Search{/if}
  </h1>

  {#if loading}
    <div class="mt-8 flex flex-col gap-3">
      {#each [1,2,3,4,5] as _}
        <div class="h-12 rounded-xl bg-muted animate-pulse"></div>
      {/each}
    </div>

  {:else if !query}
    <p class="text-muted-foreground mt-4 text-sm">Enter a search term in the header to find groups, events, and people.</p>

  {:else if !hasResults}
    <p class="text-muted-foreground mt-4 text-sm">No results found for "{query}".</p>

  {:else}

    <!-- Groups -->
    {#if groups.length > 0}
      <section class="mt-8">
        <h2 class="text-xs font-semibold uppercase tracking-wider text-muted-foreground mb-3">Groups</h2>
        <div class="flex flex-col gap-1">
          {#each groups as group}
            <a href="/groups/{group.id}"
              class="flex items-center gap-3 px-3 py-2.5 rounded-xl hover:bg-muted transition-colors">
              {#if group.avatar_url}
                <img src={group.avatar_url} alt={group.name} class="w-8 h-8 rounded-full object-cover shrink-0" />
              {:else}
                <div class="w-8 h-8 rounded-full flex items-center justify-center text-white text-xs font-bold shrink-0"
                  style="background: hsl(234 26% 41%)">
                  {initials(group.name)}
                </div>
              {/if}
              <span class="text-sm font-medium text-foreground">{group.name}</span>
            </a>
          {/each}
        </div>
      </section>
    {/if}

    <!-- Events -->
    {#if events.length > 0}
      <section class="mt-8">
        <h2 class="text-xs font-semibold uppercase tracking-wider text-muted-foreground mb-3">Events</h2>
        <div class="flex flex-col gap-1">
          {#each events as event}
            <a href="/groups/{event.group_id}/events/{event.id}"
              class="flex items-center gap-3 px-3 py-2.5 rounded-xl hover:bg-muted transition-colors">
              <div class="w-8 h-8 rounded-full flex items-center justify-center shrink-0"
                style="background: hsl(234 40% 97%)">
                <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="hsl(234 26% 41%)" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                  <rect x="3" y="4" width="18" height="18" rx="2" ry="2"/>
                  <line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/>
                  <line x1="3" y1="10" x2="21" y2="10"/>
                </svg>
              </div>
              <div class="min-w-0">
                <p class="text-sm font-medium text-foreground truncate">{event.title}</p>
                <p class="text-xs text-muted-foreground">{event.groups?.name} · {formatDate(event.event_date)}</p>
              </div>
            </a>
          {/each}
        </div>
      </section>
    {/if}

    <!-- People -->
    {#if members.length > 0}
      <section class="mt-8">
        <h2 class="text-xs font-semibold uppercase tracking-wider text-muted-foreground mb-3">People</h2>
        <div class="flex flex-col gap-1">
          {#each members as member}
            <div class="flex items-center gap-3 px-3 py-2.5 rounded-xl">
              {#if member.avatar_url}
                <img src={member.avatar_url} alt={member.display_name} class="w-8 h-8 rounded-full object-cover shrink-0" />
              {:else}
                <div class="w-8 h-8 rounded-full flex items-center justify-center text-white text-xs font-bold shrink-0"
                  style="background: hsl(235 22% 56%)">
                  {initials(member.display_name)}
                </div>
              {/if}
              <span class="text-sm font-medium text-foreground">{member.display_name}</span>
            </div>
          {/each}
        </div>
      </section>
    {/if}

  {/if}
</div>
