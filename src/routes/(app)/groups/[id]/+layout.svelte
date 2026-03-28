<script>
  import { supabase } from '$lib/supabase'
  import { page } from '$app/stores'
  import { goto } from '$app/navigation'
  import { onMount } from 'svelte'

  let groupId = $derived($page.params.id)
  let group = $state(null)
  let currentUserRole = $state(null)
  let memberCount = $state(null)
  let loading = $state(true)
  let userId = $state(null)

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
    })()
  })

  let avatarColor = $state('indigo')
  let avatarColorOpen = $state(false)
  let overflowOpen = $state(false)

  const AVATAR_COLORS = [
    { key: 'indigo', label: 'Indigo', bg: 'hsl(234 26% 41%)',  ring: 'hsl(234 26% 55%)' },
    { key: 'amber',  label: 'Amber',  bg: 'hsl(35 95% 52%)',   ring: 'hsl(35 95% 65%)' },
    { key: 'coral',  label: 'Coral',  bg: 'hsl(355 68% 62%)',  ring: 'hsl(355 68% 75%)' },
  ]

  function avatarBg() {
    return AVATAR_COLORS.find(c => c.key === avatarColor)?.bg ?? 'hsl(234 26% 41%)'
  }

  let currentPath = $derived($page.url.pathname)

  function isTabActive(tab) {
    return currentPath.startsWith(`/groups/${groupId}/${tab}`)
  }

  function initials(name) {
    if (!name) return '?'
    return name.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2)
  }

  let tabs = $derived([
    { key: 'board',   label: 'Board',   href: `/groups/${groupId}/board`,   count: 0 },
    { key: 'events',  label: 'Events',  href: `/groups/${groupId}/events`,  count: 0 },
    { key: 'members', label: 'Members', href: `/groups/${groupId}/members`, count: 0 },
    { key: 'lists',   label: 'Lists',   href: `/groups/${groupId}/lists`,   count: 0 },
  ])

</script>

{#if !loading && group}

  <!-- Desktop layout: secondary nav + content -->
  <div class="hidden md:flex h-full">

    <!-- Secondary nav (176px) -->
    <aside class="relative w-60 shrink-0 border-r flex flex-col overflow-hidden" style="background: var(--color-header); border-color: rgba(255,255,255,0.12)">

      <!-- Decorative blobs (matching marketing hero) -->
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
      <nav class="relative z-10 flex flex-col gap-0.5 py-2 flex-1">
        {#each tabs as tab}
          {@const active = isTabActive(tab.key)}
          <a
            href={tab.href}
            class="flex items-center gap-2.5 mx-5 px-2 py-2 rounded-xl text-sm font-medium transition-colors hover:bg-white/10"
            style={active
              ? 'background: rgba(255,255,255,0.22); color: white'
              : 'color: rgba(255,255,255,0.70)'}
          >
            {tab.label}
            {#if tab.count > 0}
              <span class="ml-auto text-xs font-semibold rounded-full px-1.5 py-0.5 leading-none"
                style="background: rgba(255,255,255,0.18); color: white; min-width: 1.25rem; text-align: center">
                {tab.count}
              </span>
            {/if}
          </a>
        {/each}
      </nav>

      <!-- Footer: Settings + More overflow -->
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

        <!-- More / overflow -->
        <div class="relative">
          <button
            onclick={() => overflowOpen = !overflowOpen}
            class="flex items-center gap-2.5 w-full mx-5 px-2 py-2 rounded-xl text-sm font-medium transition-colors hover:bg-white/10"
            style="color: rgba(255,255,255,0.70)"
          >
            <svg width="15" height="15" viewBox="0 0 24 24" fill="currentColor" stroke="none">
              <circle cx="5" cy="12" r="1.5"/><circle cx="12" cy="12" r="1.5"/><circle cx="19" cy="12" r="1.5"/>
            </svg>
            More
          </button>
          {#if overflowOpen}
            <button class="fixed inset-0 z-40 cursor-default" onclick={() => overflowOpen = false} tabindex="-1" aria-hidden="true"></button>
            <div class="absolute left-0 bottom-full mb-1 w-44 bg-white rounded-xl border border-border py-1 z-50"
              style="box-shadow: 0 4px 16px rgba(0,0,0,0.13)">
              <a href="/groups/{groupId}/invite" onclick={() => overflowOpen = false}
                class="flex items-center gap-2.5 px-3 py-2 text-sm text-foreground hover:bg-muted transition-colors">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                  <path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/>
                  <path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/>
                </svg>
                Invite link
              </a>
              <a href="/groups/{groupId}/suggest" onclick={() => overflowOpen = false}
                class="flex items-center gap-2.5 px-3 py-2 text-sm text-foreground hover:bg-muted transition-colors">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                  <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
                </svg>
                Anonymous suggestion
              </a>
            </div>
          {/if}
        </div>
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

      <div class="flex items-center gap-2 mb-3">
        <!-- Back button -->
        <button
          onclick={() => goto('/groups')}
          class="p-1.5 rounded-lg hover:bg-muted transition-colors shrink-0"
          style="color: hsl(234 12% 52%)"
        >
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <polyline points="15 18 9 12 15 6"/>
          </svg>
        </button>

        <!-- Avatar -->
        {#if group.avatar_url}
          <img src={group.avatar_url} alt={group.name} class="w-8 h-8 rounded-full object-cover shrink-0" />
        {:else}
          <div class="relative shrink-0">
            <div class="w-8 h-8 rounded-full flex items-center justify-center text-white text-xs font-bold"
              style="background: {avatarBg()}">
              {initials(group.name)}
            </div>
          </div>
        {/if}

        <h1 class="text-lg font-semibold text-foreground truncate flex-1">{group.name}</h1>

        <!-- Overflow ⋯ button -->
        <div class="relative ml-auto shrink-0">
          <button
            onclick={() => overflowOpen = !overflowOpen}
            class="p-1.5 rounded-lg hover:bg-muted transition-colors"
            style="color: hsl(234 12% 52%)"
          >
            <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor" stroke="none">
              <circle cx="12" cy="5" r="1.5"/><circle cx="12" cy="12" r="1.5"/><circle cx="12" cy="19" r="1.5"/>
            </svg>
          </button>
          {#if overflowOpen}
            <button class="fixed inset-0 z-40 cursor-default" onclick={() => overflowOpen = false} tabindex="-1" aria-hidden="true"></button>
            <div class="absolute right-0 top-full mt-1 w-48 bg-white rounded-xl border border-border py-1 z-50"
              style="box-shadow: 0 8px 24px rgba(0,0,0,0.13)">
              {#if currentUserRole === 'admin' || currentUserRole === 'co_admin'}
                <a href="/groups/{groupId}/settings" onclick={() => overflowOpen = false}
                  class="flex items-center gap-2.5 px-3 py-2 text-sm text-foreground hover:bg-muted transition-colors">
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                    <circle cx="12" cy="12" r="3"/>
                    <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/>
                  </svg>
                  Settings
                </a>
              {/if}
              <a href="/groups/{groupId}/invite" onclick={() => overflowOpen = false}
                class="flex items-center gap-2.5 px-3 py-2 text-sm text-foreground hover:bg-muted transition-colors">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                  <path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/>
                  <path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/>
                </svg>
                Invite link
              </a>
              <a href="/groups/{groupId}/suggest" onclick={() => overflowOpen = false}
                class="flex items-center gap-2.5 px-3 py-2 text-sm text-foreground hover:bg-muted transition-colors">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                  <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
                </svg>
                Anonymous suggestion
              </a>
            </div>
          {/if}
        </div>
      </div>

      <!-- Horizontal tab strip -->
      <div class="flex gap-1 overflow-x-auto no-scrollbar">
        {#each tabs as tab}
          <a
            href={tab.href}
            class="px-3 py-2 text-sm font-medium whitespace-nowrap border-b-2 transition-colors"
            style={isTabActive(tab.key)
              ? 'border-color: hsl(234 26% 41%); color: hsl(234 26% 41%)'
              : 'border-color: transparent; color: hsl(234 12% 52%)'}
          >
            {tab.label}
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
