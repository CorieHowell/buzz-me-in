<script>
  import { supabase } from '$lib/supabase'
  import { goto } from '$app/navigation'
  import { page } from '$app/stores'
  import { onMount, setContext } from 'svelte'
  import Rail from '$lib/components/Rail.svelte'
  import BottomTabBar from '$lib/components/BottomTabBar.svelte'

  let user = $state(null)
  let ready = $state(false)
  let unreadMessages = $state(0)
  let unreadNotifications = $state(0)
  let myGroups = $state([])
  let userAvatarUrl = $state(null)
  let searchQuery = $state('')
  let calSyncOpen = $state(false)
  let userIsPro = $state(false)

  const syncProviders = [
    { name: 'Google Calendar', icon: `<svg width="16" height="16" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4"/><path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/><path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l3.66-2.84z" fill="#FBBC05"/><path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/></svg>` },
    { name: 'Apple Calendar', icon: `<svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/></svg>` },
    { name: 'Outlook', icon: `<svg width="16" height="16" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><rect x="1" y="6" width="13" height="12" rx="1" fill="#0364B8"/><path d="M7.5 9C5.57 9 4 10.57 4 12.5S5.57 16 7.5 16 11 14.43 11 12.5 9.43 9 7.5 9zm0 5.5c-1.38 0-2.5-1.12-2.5-2.5S6.12 10 7.5 10 10 11.12 10 12.5 8.88 14.5 7.5 14.5z" fill="white"/><path d="M14 8l9 4-9 4V8z" fill="#0078D4"/><path d="M14 8v8l4-2V10l-4-2z" fill="#0364B8"/></svg>` },
  ]

  onMount(async () => {
    const { data: { session } } = await supabase.auth.getSession()
    if (!session) { goto('/auth/login'); return }
    user = session.user
    ready = true
    await Promise.all([checkUnread(), loadGroups(), loadUserProfile(session.user.id)])

    supabase.auth.onAuthStateChange((_event, session) => {
      if (!session) { goto('/auth/login'); return }
      user = session?.user ?? null
    })

    // Realtime: re-check unread count on any direct_messages change
    const channel = supabase
      .channel('unread-messages')
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'direct_messages',
        filter: `recipient_id=eq.${session.user.id}`,
      }, () => { checkUnread() })
      .subscribe()

    return () => { supabase.removeChannel(channel) }
  })

  async function loadUserProfile(uid) {
    const { data } = await supabase.from('users').select('avatar_url').eq('id', uid).single()
    userAvatarUrl = data?.avatar_url ?? null
  }

  async function checkUnread() {
    if (!user) return
    const { count: msgCount } = await supabase
      .from('direct_messages')
      .select('*', { count: 'exact', head: true })
      .eq('recipient_id', user.id)
      .eq('is_read', false)
      .eq('is_deleted', false)
    unreadMessages = msgCount ?? 0

    const { count: notifCount } = await supabase
      .from('notifications')
      .select('*', { count: 'exact', head: true })
      .eq('user_id', user.id)
      .eq('is_read', false)
    unreadNotifications = notifCount ?? 0
  }

  async function loadGroups() {
    if (!user) return
    const { data } = await supabase
      .from('group_members')
      .select('role, is_favorited, joined_at, groups(id, name, avatar_url)')
      .eq('user_id', user.id)
      .order('is_favorited', { ascending: false })
      .order('joined_at', { ascending: true })
    myGroups = (data ?? []).map(m => ({ ...m.groups, role: m.role, is_favorited: m.is_favorited }))
  }

  async function signOut() {
    await supabase.auth.signOut()
    goto('/auth/login')
  }

  let currentPath = $derived($page.url.pathname)

  function initials(name) {
    if (!name) return '?'
    return name.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2)
  }

  // Expose shared state to child layouts/components via context
  setContext('appContext', {
    get user() { return user },
    get myGroups() { return myGroups },
    get unreadMessages() { return unreadMessages },
    get unreadNotifications() { return unreadNotifications },
    get userAvatarUrl() { return userAvatarUrl },
    openCalSync: () => { calSyncOpen = true },
  })
</script>

{#if ready}
<div class="flex h-screen bg-background overflow-hidden">

  <!-- Rail: desktop only -->
  <div class="hidden md:flex flex-col shrink-0">
    <Rail
      {myGroups}
      {user}
      {userAvatarUrl}
      {unreadMessages}
      {unreadNotifications}
      {currentPath}
      bind:calSyncOpen
      {signOut}
    />
  </div>

  <!-- Content area -->
  <main class="flex-1 flex flex-col overflow-hidden min-w-0">
    {#if $page.url.pathname === '/calendar'}
      <slot />
    {:else}
      <div class="flex-1 overflow-y-auto pb-20 md:pb-0">
        <slot />
      </div>
    {/if}
  </main>

  <!-- Mobile bottom tab bar -->
  <div class="md:hidden">
    <BottomTabBar
      {unreadMessages}
      {unreadNotifications}
      {currentPath}
    />
  </div>

  <!-- Calendar Sync Modal -->
  {#if calSyncOpen}
    <div class="fixed inset-0 z-50 flex items-center justify-center p-4" style="background: rgba(0,0,0,0.4)">
      <button class="absolute inset-0" onclick={() => calSyncOpen = false} tabindex="-1" aria-hidden="true"></button>
      <div class="relative bg-white rounded-2xl w-full max-w-sm overflow-hidden z-10"
        style="box-shadow: 0 20px 60px rgba(0,0,0,0.2)">
        <!-- Header -->
        <div class="px-6 pt-6 pb-4">
          <div class="flex items-start justify-between">
            <div>
              <h2 class="text-base font-semibold text-foreground">Set up Calendar Sync</h2>
              <p class="text-sm text-muted-foreground mt-0.5">Connect Buzz Me In to your calendar app.</p>
            </div>
            <button onclick={() => calSyncOpen = false} class="p-1 rounded-lg hover:bg-muted transition-colors shrink-0 -mt-0.5 -mr-1" style="color: hsl(220 9% 55%)">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
              </svg>
            </button>
          </div>
        </div>

        {#if userIsPro}
          <div class="px-4 pb-5 flex flex-col gap-1.5">
            {#each syncProviders as provider}
              <button class="flex items-center gap-3 px-4 py-3 rounded-xl hover:bg-muted transition-colors w-full text-left border border-border/60">
                {@html provider.icon}
                <span class="text-sm font-medium text-foreground">{provider.name}</span>
                <span class="ml-auto text-xs font-medium" style="color: hsl(234 26% 41%)">Connect</span>
              </button>
            {/each}
          </div>
        {:else}
          <!-- Placeholder area for character illustration -->
          <div class="mx-6 mb-4 rounded-xl flex items-center justify-center" style="height: 140px; background: hsl(234 40% 97%)">
            <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="hsl(234 26% 60%)" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
              <rect x="3" y="4" width="18" height="18" rx="2" ry="2"/>
              <line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/>
              <line x1="3" y1="10" x2="21" y2="10"/>
            </svg>
          </div>
          <div class="px-6 pb-6 text-center">
            <p class="text-sm font-semibold text-foreground mb-1">Sync with Buzz Pro</p>
            <p class="text-sm text-muted-foreground mb-4">Upgrade to sync your events with Google, Apple, and Outlook automatically.</p>
            <div class="flex flex-col gap-2.5">
              {#each syncProviders as provider}
                <div class="flex items-center gap-3 px-4 py-2.5 rounded-xl border border-border/60 opacity-50 cursor-not-allowed">
                  {@html provider.icon}
                  <span class="text-sm text-foreground">{provider.name}</span>
                  <span class="ml-auto text-xs text-muted-foreground">Locked</span>
                </div>
              {/each}
            </div>
            <button
              onclick={() => { calSyncOpen = false; goto('/upgrade') }}
              class="mt-4 w-full py-2.5 rounded-full text-sm font-semibold text-white transition-colors"
              style="background: hsl(234 26% 41%)"
            >
              Upgrade to Pro
            </button>
          </div>
        {/if}
      </div>
    </div>
  {/if}

</div>
{/if}
