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

  const DEV_MOCK = true

  onMount(async () => {
    if (DEV_MOCK) {
      userId = 'mock-user-id'
      group = { id: groupId, name: groupId === 'g1' ? 'Book Club' : groupId === 'g2' ? 'Hiking Crew' : 'Dinner Club', avatar_url: null }
      currentUserRole = 'admin'
      loading = false
      return
    }

    const { data: { user } } = await supabase.auth.getUser()
    if (!user) { goto('/auth/login'); return }
    userId = user.id
  })

  $effect(() => {
    if (!groupId || !userId) return
    if (DEV_MOCK) return
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
    if (tab === 'home') return currentPath === `/groups/${groupId}`
    return currentPath.startsWith(`/groups/${groupId}/${tab}`)
  }

  function initials(name) {
    if (!name) return '?'
    return name.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2)
  }

  let tabs = $derived([
    { key: 'home',    label: 'Home',    href: `/groups/${groupId}` },
    { key: 'events',  label: 'Events',  href: `/groups/${groupId}/events` },
    { key: 'board',   label: 'Board',   href: `/groups/${groupId}/board` },
    { key: 'members', label: 'Members', href: `/groups/${groupId}/members` },
    { key: 'lists',   label: 'Lists',   href: `/groups/${groupId}/lists` },
  ])
</script>

<div class="flex flex-col h-full">

  {#if !loading && group}

    <!-- Group header bar -->
    <div class="border-b border-border bg-background px-4 pt-4 pb-0">
      <div class="max-w-2xl mx-auto">

        <!-- Back + group name -->
        <div class="flex items-center gap-2 mb-3">
          <button
            onclick={() => goto('/groups')}
            class="p-1.5 rounded-lg hover:bg-muted transition-colors shrink-0"
            style="color: hsl(234 12% 52%)"
          >
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <polyline points="15 18 9 12 15 6"/>
            </svg>
          </button>
          {#if group.avatar_url}
            <img src={group.avatar_url} alt={group.name} class="w-8 h-8 rounded-full object-cover shrink-0" />
          {:else}
            <div class="relative shrink-0">
              <div class="w-8 h-8 rounded-full flex items-center justify-center text-white text-xs font-bold"
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
            </div>
          {/if}
          <h1 class="text-lg font-semibold text-foreground truncate">{group.name}</h1>
          {#if currentUserRole === 'admin' || currentUserRole === 'co_admin'}
            <a
              href="/groups/{groupId}/settings"
              class="ml-auto p-1.5 rounded-lg hover:bg-muted transition-colors shrink-0"
              style="color: hsl(234 12% 52%)"
            >
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                <circle cx="12" cy="12" r="3"/>
                <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/>
              </svg>
            </a>
          {/if}
        </div>

        <!-- Tab bar -->
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
    </div>

    <!-- Tab content -->
    <div class="flex-1 overflow-y-auto">
      <slot />
    </div>

  {:else if loading}
    <div class="flex-1 flex items-center justify-center">
      <div class="w-5 h-5 rounded-full border-2 border-muted border-t-primary animate-spin"></div>
    </div>
  {/if}

</div>