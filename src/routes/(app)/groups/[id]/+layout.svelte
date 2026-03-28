<script>
  import { supabase } from '$lib/supabase'
  import { page } from '$app/stores'
  import { goto } from '$app/navigation'
  import { onMount, setContext } from 'svelte'

  let groupId = $derived($page.params.id)
  let group = $state(null)
  let currentUserRole = $state(null)
  let memberCount = $state(null)
  let loading = $state(true)
  let userId = $state(null)
  let newBoardPostCount = $state(0)

  onMount(async () => {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) { goto('/auth/login'); return }
    userId = user.id
  })

  $effect(() => {
    if (!groupId || !userId) return
    loading = true
    group = null
    ;(async () => {
      const { data: groupData } = await supabase
        .from('groups')
        .select('id, name, avatar_url')
        .eq('id', groupId)
        .single()

      group = groupData

      const { count } = await supabase
        .from('group_members')
        .select('*', { count: 'exact', head: true })
        .eq('group_id', groupId)
      memberCount = count

      const { data: membership } = await supabase
        .from('group_members')
        .select('role')
        .eq('group_id', groupId)
        .eq('user_id', userId)
        .single()

      currentUserRole = membership?.role ?? null
      loading = false

      // Check for new posts since last board visit
      const lastVisit = typeof localStorage !== 'undefined'
        ? localStorage.getItem(`board_last_visit_${groupId}`)
        : null
      if (lastVisit) {
        const { count: newCount } = await supabase
          .from('posts')
          .select('*', { count: 'exact', head: true })
          .eq('group_id', groupId)
          .is('parent_id', null)
          .eq('is_deleted', false)
          .gt('created_at', new Date(parseInt(lastVisit)).toISOString())
        newBoardPostCount = newCount ?? 0
      }
    })()
  })

  setContext('groupLayout', {
    clearBoardBadge: () => { newBoardPostCount = 0 }
  })

  let currentPath = $derived($page.url.pathname)

  function isTabActive(tab) {
    return currentPath.startsWith(`/groups/${groupId}/${tab}`)
  }

  function initials(name) {
    if (!name) return '?'
    return name.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2)
  }

  let tabs = $derived([
    { key: 'board',   label: 'Message Board', href: `/groups/${groupId}/board`,   count: newBoardPostCount },
    { key: 'events',  label: 'Events',         href: `/groups/${groupId}/events`,  count: 0 },
    { key: 'members', label: 'Members',        href: `/groups/${groupId}/members`, count: 0 },
    { key: 'lists',   label: 'Lists',          href: `/groups/${groupId}/lists`,   count: 0 },
  ])

</script>

{#if !loading && group}

  <!-- Desktop layout: secondary nav + content -->
  <div class="hidden md:flex h-full">

    <!-- Secondary nav (176px) -->
    <aside class="relative w-60 shrink-0 border-r flex flex-col overflow-hidden" style="background: var(--color-header); border-color: rgba(255,255,255,0.12)">

      <!-- Decorative blobs -->
      <div class="absolute top-0 right-0 w-48 h-48 rounded-full pointer-events-none"
        style="background: var(--color-accent); opacity: 0.10; filter: blur(70px); transform: translate(40%, -30%);"></div>
      <div class="absolute bottom-0 left-0 w-40 h-40 rounded-full pointer-events-none"
        style="background: var(--color-accent-soft); opacity: 0.10; filter: blur(60px);"></div>

      <!-- Group identity block -->
      <div class="relative z-10 px-5 pt-5 pb-4 border-b" style="border-color: rgba(255,255,255,0.12)">
        <p class="text-base font-extrabold leading-snug truncate" style="color: white">{group.name}</p>
        {#if memberCount !== null}
          <p class="text-xs mt-0.5" style="color: rgba(255,255,255,0.45)">{memberCount} {memberCount === 1 ? 'member' : 'members'}</p>
        {/if}
      </div>

      <!-- Nav items -->
      <nav class="relative z-10 flex flex-col gap-1 pt-4 pb-2 flex-1">
        {#each tabs as tab}
          {@const active = isTabActive(tab.key)}
          <a
            href={tab.href}
            class="group flex items-center gap-2.5 mx-5 pr-2 py-2 rounded-xl text-sm transition-all"
            style={active ? 'color: white' : 'color: rgba(255,255,255,0.65)'}
          >
            <span class="w-1 rounded-full self-stretch shrink-0 my-0.5 transition-all {active ? 'bg-white' : 'bg-transparent group-hover:bg-white/30'}"></span>
            <span class="{active ? 'font-semibold' : 'font-medium'} transition-all">{tab.label}</span>
            {#if tab.count > 0}
              <span class="ml-auto text-xs font-semibold rounded-full px-1.5 py-0.5 leading-none"
                style="background: rgba(255,255,255,0.18); color: white; min-width: 1.25rem; text-align: center">
                {tab.count}
              </span>
            {/if}
          </a>
        {/each}
      </nav>

      <!-- Footer: Settings -->
      <div class="relative z-10 border-t py-2 flex flex-col gap-0.5" style="border-color: rgba(255,255,255,0.12)">
        {#if currentUserRole === 'admin' || currentUserRole === 'co_admin'}
          <a
            href="/groups/{groupId}/settings"
            class="flex items-center gap-2.5 mx-5 px-2 py-2 rounded-xl text-sm font-medium transition-colors hover:bg-white/10"
            style={currentPath.startsWith(`/groups/${groupId}/settings`)
              ? 'background: rgba(255,255,255,0.22); color: white'
              : 'color: rgba(255,255,255,0.70)'}
          >
            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
              <circle cx="12" cy="12" r="3"/>
              <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/>
            </svg>
            Settings
          </a>
        {/if}
      </div>
    </aside>

    <!-- Content area -->
    <div class="flex-1 overflow-y-auto min-w-0" style="background: hsl(234 20% 96%)">
      <slot />
    </div>

  </div>

  <!-- Mobile layout: group header + tab strip + content -->
  <div class="md:hidden flex flex-col h-full">

    <!-- Group header bar -->
    <div class="border-b border-border bg-background px-4 pt-4 pb-0 shrink-0">

      <!-- Header: back | centered name | overflow -->
      <div class="relative flex items-center mb-3 h-9">
        <button
          onclick={() => goto('/groups')}
          class="p-1.5 rounded-lg hover:bg-muted transition-colors shrink-0 z-10"
          style="color: hsl(234 12% 52%)"
        >
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <polyline points="15 18 9 12 15 6"/>
          </svg>
        </button>

        <!-- Centered group name -->
        <div class="absolute inset-0 flex items-center justify-center pointer-events-none px-12">
          <h1 class="text-lg font-bold text-foreground truncate">{group.name}</h1>
        </div>

        <!-- Gear icon (admins only) -->
        {#if currentUserRole === 'admin' || currentUserRole === 'co_admin'}
          <a
            href="/groups/{groupId}/settings"
            class="ml-auto shrink-0 z-10 p-1.5 rounded-lg hover:bg-muted transition-colors"
            style="color: hsl(234 12% 52%)"
          >
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
              <circle cx="12" cy="12" r="3"/>
              <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/>
            </svg>
          </a>
        {:else}
          <div class="ml-auto shrink-0 w-8"></div>
        {/if}
      </div>

      <!-- Horizontal tab strip -->
      <div class="flex gap-1 overflow-x-auto no-scrollbar">
        {#each tabs as tab}
          <a
            href={tab.href}
            class="relative px-3 py-2 text-sm font-medium whitespace-nowrap border-b-2 transition-colors"
            style={isTabActive(tab.key)
              ? 'border-color: hsl(234 26% 41%); color: hsl(234 26% 41%)'
              : 'border-color: transparent; color: hsl(234 12% 52%)'}
          >
            {tab.label}
            {#if tab.count > 0}
              <span class="absolute top-1.5 -right-0.5 min-w-[16px] h-4 rounded-full flex items-center justify-center text-white px-1"
                style="background: hsl(35 100% 62%); font-size: 10px; font-weight: 700; line-height: 1">
                {tab.count}
              </span>
            {/if}
          </a>
        {/each}
      </div>
    </div>

    <!-- Tab content -->
    <div class="flex-1 overflow-y-auto" style="background: hsl(234 20% 96%)">
      <slot />
    </div>

  </div>

{:else if loading}
  <div class="flex-1 flex items-center justify-center">
    <div class="w-5 h-5 rounded-full border-2 border-muted border-t-primary animate-spin"></div>
  </div>
{/if}
