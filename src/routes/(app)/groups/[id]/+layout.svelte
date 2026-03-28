<script>
  import { supabase } from '$lib/supabase'
  import { page } from '$app/stores'
  import { goto } from '$app/navigation'
  import { onMount } from 'svelte'

  let groupId = $derived($page.params.id)
  let group = $state(null)
  let currentUserRole = $state(null)
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
    { key: 'board',   label: 'Board',   href: `/groups/${groupId}/board` },
    { key: 'events',  label: 'Events',  href: `/groups/${groupId}/events` },
    { key: 'members', label: 'Members', href: `/groups/${groupId}/members` },
    { key: 'lists',   label: 'Lists',   href: `/groups/${groupId}/lists` },
  ])

  const tabIcons = {
    board:   `<path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>`,
    events:  `<rect x="3" y="4" width="18" height="18" rx="2" ry="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/>`,
    members: `<path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>`,
    lists:   `<line x1="8" y1="6" x2="21" y2="6"/><line x1="8" y1="12" x2="21" y2="12"/><line x1="8" y1="18" x2="21" y2="18"/><line x1="3" y1="6" x2="3.01" y2="6"/><line x1="3" y1="12" x2="3.01" y2="12"/><line x1="3" y1="18" x2="3.01" y2="18"/>`,
  }
</script>

{#if !loading && group}

  <!-- Desktop layout: secondary nav + content -->
  <div class="hidden md:flex h-full">

    <!-- Secondary nav (176px) -->
    <aside class="w-44 shrink-0 border-r border-border flex flex-col overflow-y-auto bg-background">

      <!-- Group identity block -->
      <div class="px-4 pt-5 pb-4 border-b border-border">
        <!-- Avatar with color picker for admins -->
        <div class="relative w-10 h-10 mb-3">
          {#if group.avatar_url}
            <img src={group.avatar_url} alt={group.name} class="w-10 h-10 rounded-full object-cover" />
          {:else}
            <div class="w-10 h-10 rounded-full flex items-center justify-center text-white text-sm font-bold"
              style="background: {avatarBg()}">
              {initials(group.name)}
            </div>
            {#if currentUserRole === 'admin' || currentUserRole === 'co_admin'}
              <button
                onclick={() => avatarColorOpen = !avatarColorOpen}
                class="absolute -bottom-0.5 -right-0.5 w-3.5 h-3.5 rounded-full border-2 border-white flex items-center justify-center"
                style="background: {avatarBg()}"
                title="Change color"
              >
                <svg width="6" height="6" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">
                  <circle cx="12" cy="12" r="3"/>
                </svg>
              </button>
              {#if avatarColorOpen}
                <button class="fixed inset-0 z-40 cursor-default" onclick={() => avatarColorOpen = false} tabindex="-1" aria-hidden="true"></button>
                <div class="absolute left-0 top-full mt-2 z-50 bg-white rounded-xl border border-border p-2.5 flex gap-2"
                  style="box-shadow: 0 4px 16px rgba(0,0,0,0.12)">
                  {#each AVATAR_COLORS as opt}
                    <button
                      onclick={() => { avatarColor = opt.key; avatarColorOpen = false }}
                      class="w-7 h-7 rounded-full transition-transform hover:scale-110 shrink-0"
                      style="background: {opt.bg}; {avatarColor === opt.key ? `box-shadow: 0 0 0 2px white, 0 0 0 4px ${opt.bg}` : ''}"
                      title={opt.label}
                    ></button>
                  {/each}
                </div>
              {/if}
            {/if}
          {/if}
        </div>
        <p class="text-sm font-semibold text-foreground leading-snug truncate">{group.name}</p>
      </div>

      <!-- Nav items -->
      <nav class="flex flex-col gap-0.5 p-2 flex-1">
        {#each tabs as tab}
          {@const active = isTabActive(tab.key)}
          <a
            href={tab.href}
            class="flex items-center gap-2.5 px-3 py-2 rounded-lg text-sm font-medium transition-colors"
            style={active
              ? 'background: hsl(234 40% 97%); color: hsl(234 26% 41%)'
              : 'color: hsl(234 12% 52%)'}
          >
            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor"
              stroke-width={active ? '2' : '1.8'} stroke-linecap="round" stroke-linejoin="round">
              {@html tabIcons[tab.key]}
            </svg>
            {tab.label}
          </a>
        {/each}
      </nav>

      <!-- Footer: Settings + More overflow -->
      <div class="border-t border-border p-2 flex flex-col gap-0.5">
        {#if currentUserRole === 'admin' || currentUserRole === 'co_admin'}
          <a
            href="/groups/{groupId}/settings"
            class="flex items-center gap-2.5 px-3 py-2 rounded-lg text-sm font-medium transition-colors"
            style={currentPath.startsWith(`/groups/${groupId}/settings`)
              ? 'background: hsl(234 40% 97%); color: hsl(234 26% 41%)'
              : 'color: hsl(234 12% 52%)'}
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
            class="flex items-center gap-2.5 w-full px-3 py-2 rounded-lg text-sm font-medium transition-colors"
            style="color: hsl(234 12% 52%)"
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
