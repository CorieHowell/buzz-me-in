<script>
  import { supabase } from '$lib/supabase'
  import { goto } from '$app/navigation'
  import { page } from '$app/stores'
  import { onMount } from 'svelte'
  
  let user = $state(null)
  let ready = $state(false)
  let unreadMessages = $state(0)
  let unreadNotifications = $state(0)
  let myGroups = $state([])
  let userAvatarUrl = $state(null)
  let searchQuery = $state('')
  let profileDropdownOpen = $state(false)
  let msgsOpen = $state(false)
  let notifOpen = $state(false)
  let conversations = $state([])
  let notifItems = $state([])
  let convLoading = $state(false)
  let notifLoading = $state(false)

  function handleSearch(e) {
    e.preventDefault()
    if (searchQuery.trim()) {
      goto(`/search?q=${encodeURIComponent(searchQuery.trim())}`)
      searchQuery = ''
    }
  }

  async function openMessages() {
    notifOpen = false
    profileDropdownOpen = false
    msgsOpen = !msgsOpen
    if (msgsOpen) {
      convLoading = true
      await loadConversations()
      convLoading = false
    }
  }

  async function openNotifications() {
    msgsOpen = false
    profileDropdownOpen = false
    notifOpen = !notifOpen
    if (notifOpen) {
      notifLoading = true
      await loadNotifItems()
      notifLoading = false
      if (unreadNotifications > 0) {
        supabase.from('notifications').update({ is_read: true }).eq('user_id', user.id).eq('is_read', false).then(() => {})
        unreadNotifications = 0
      }
    }
  }

  async function loadConversations() {
    if (!user) return
    const { data } = await supabase
      .from('direct_messages')
      .select('id, body, created_at, is_read, is_anonymous, sender_id, recipient_id, users!direct_messages_sender_id_fkey(display_name, avatar_url), recipient:users!direct_messages_recipient_id_fkey(display_name, avatar_url)')
      .or(`sender_id.eq.${user.id},recipient_id.eq.${user.id}`)
      .eq('is_deleted', false)
      .order('created_at', { ascending: false })
    const convMap = new Map()
    for (const msg of data ?? []) {
      if (msg.is_anonymous && msg.recipient_id === user.id) {
        convMap.set('anon-' + msg.id, { otherId: 'anonymous', otherName: 'Anonymous', otherAvatarUrl: null, lastMessage: msg.body, lastTime: msg.created_at, unread: !msg.is_read, isAnonymous: true, msgId: msg.id })
        continue
      }
      const otherId = msg.sender_id === user.id ? msg.recipient_id : msg.sender_id
      const otherName = msg.sender_id === user.id ? msg.recipient?.display_name : msg.users?.display_name
      const otherAvatarUrl = msg.sender_id === user.id ? msg.recipient?.avatar_url : msg.users?.avatar_url
      if (!otherId) continue
      if (!convMap.has(otherId)) {
        convMap.set(otherId, { otherId, otherName, otherAvatarUrl, lastMessage: msg.body, lastTime: msg.created_at, unread: !msg.is_read && msg.recipient_id === user.id, isAnonymous: false })
      } else {
        if (!msg.is_read && msg.recipient_id === user.id) convMap.get(otherId).unread = true
      }
    }
    conversations = Array.from(convMap.values()).sort((a, b) => new Date(b.lastTime) - new Date(a.lastTime))
  }

  async function loadNotifItems() {
    if (!user) return
    const { data } = await supabase
      .from('notifications')
      .select('*')
      .eq('user_id', user.id)
      .order('created_at', { ascending: false })
      .limit(20)
    notifItems = data ?? []
  }

  function notifIcon(type) {
    switch (type) {
      case 'new_member': return `<path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>`
      case 'join_request': return `<path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="8.5" cy="7" r="4"/><line x1="20" y1="8" x2="20" y2="14"/><line x1="23" y1="11" x2="17" y2="11"/>`
      case 'event_reminder': return `<rect x="3" y="4" width="18" height="18" rx="2" ry="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/>`
      default: return `<circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/>`
    }
  }

  function timeAgoShort(dateStr) {
    const diff = Date.now() - new Date(dateStr).getTime()
    const mins = Math.floor(diff / 60000)
    const hours = Math.floor(mins / 60)
    const days = Math.floor(hours / 24)
    if (mins < 1) return 'now'
    if (mins < 60) return `${mins}m`
    if (hours < 24) return `${hours}h`
    return `${days}d`
  }

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

  async function toggleFavorite(group, e) {
    e.preventDefault()
    e.stopPropagation()
    const newVal = !group.is_favorited
    myGroups = myGroups
      .map(g => g.id === group.id ? { ...g, is_favorited: newVal } : g)
      .sort((a, b) => (b.is_favorited ? 1 : 0) - (a.is_favorited ? 1 : 0))
    await supabase.from('group_members')
      .update({ is_favorited: newVal })
      .eq('group_id', group.id)
      .eq('user_id', user.id)
  }

  async function signOut() {
    await supabase.auth.signOut()
    goto('/auth/login')
  }

  let currentPath = $derived($page.url.pathname)

  function isActive(href) {
    return currentPath === href || currentPath.startsWith(href + '/')
  }

  function initials(name) {
    if (!name) return '?'
    return name.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2)
  }

  const mobileNavItems = [
    { href: '/home',          label: 'Home',     icon: `<path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/>` },
    { href: '/groups',        label: 'Groups',   icon: `<path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>` },
    { href: '/messages',      label: 'Messages', icon: `<path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>` },
    { href: '/profile',       label: 'Profile',  icon: `<path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/>` },
    { href: '/notifications',  label: 'Alerts',  icon: `<path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/>` },
  ]
</script>

{#if ready}
<div class="flex flex-col h-screen bg-background overflow-hidden">

  <!-- Top header (desktop only) -->
  <header class="hidden md:flex items-center h-16 px-4 shrink-0 z-20"
    style="background: var(--color-header)">
    <a href="/home" class="flex items-center gap-2 mr-6 shrink-0">
      <span class="font-bold text-xl leading-none">
        <span style="color: hsl(234 65% 82%)">buzz</span><span style="color: hsl(35 100% 72%)">me</span><span style="color: hsl(235 45% 78%)">in</span>
      </span>
    </a>

    <div class="flex-1"></div>

    <div class="flex items-center gap-0.5">

      <!-- Search (always open) -->
      <form onsubmit={handleSearch} class="relative flex items-center mr-2">
        <svg class="absolute left-3 pointer-events-none" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="rgba(255,255,255,0.5)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/>
        </svg>
        <input
          bind:value={searchQuery}
          placeholder="Search your groups and activity"
          class="h-9 pl-8 pr-3 text-sm rounded-full border-0 focus:outline-none w-64"
          style="background: rgba(255,255,255,0.10); color: white;"
        />
      </form>

      <!-- Messages popover -->
      <div class="relative">
        <button onclick={openMessages} class="relative p-2 rounded-lg hover:bg-white/10 transition-colors text-white" title="Messages">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor"
            stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
            <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
          </svg>
          {#if unreadMessages > 0}
            <span class="absolute top-1.5 right-1.5 w-2 h-2 rounded-full" style="background: hsl(35 100% 62%); box-shadow: 0 0 0 2px var(--color-header)"></span>
          {/if}
        </button>
        {#if msgsOpen}
          <button class="fixed inset-0 z-40 cursor-default" onclick={() => msgsOpen = false} tabindex="-1" aria-hidden="true"></button>
          <div class="absolute right-0 top-full mt-2 w-80 bg-white rounded-xl border border-border z-50 overflow-hidden"
            style="box-shadow: 0 8px 24px rgba(0,0,0,0.15)">
            <div class="px-4 py-3 border-b border-border flex items-center justify-between">
              <span class="text-sm font-semibold text-foreground">Messages</span>
              <a href="/messages" onclick={() => msgsOpen = false} class="text-xs font-medium" style="color: hsl(234 26% 41%)">See all</a>
            </div>
            <div class="overflow-y-auto" style="max-height: 400px">
              {#if convLoading}
                <div class="flex flex-col gap-2 p-3">
                  {#each [1,2,3] as _}
                    <div class="flex items-center gap-3 p-2 rounded-lg animate-pulse">
                      <div class="w-9 h-9 rounded-full bg-muted shrink-0"></div>
                      <div class="flex-1"><div class="h-3 bg-muted rounded w-1/2 mb-1.5"></div><div class="h-3 bg-muted rounded w-3/4"></div></div>
                    </div>
                  {/each}
                </div>
              {:else if conversations.length === 0}
                <div class="py-10 text-center">
                  <p class="text-sm text-muted-foreground">No messages yet.</p>
                </div>
              {:else}
                {#each conversations as conv}
                  <button
                    onclick={() => { goto(conv.isAnonymous ? `/messages/anonymous/${conv.msgId}` : `/messages/${conv.otherId}`); msgsOpen = false }}
                    class="flex items-center gap-3 px-4 py-3 w-full text-left hover:bg-muted/40 transition-colors border-b border-border/50 last:border-0"
                  >
                    {#if !conv.isAnonymous && conv.otherAvatarUrl}
                      <img src={conv.otherAvatarUrl} alt={conv.otherName} class="w-9 h-9 rounded-full object-cover shrink-0" />
                    {:else}
                      <div class="w-9 h-9 rounded-full flex items-center justify-center text-xs font-semibold text-white shrink-0"
                        style="background: {conv.isAnonymous ? 'hsl(234 12% 52%)' : 'hsl(234 26% 41%)'}">
                        {conv.isAnonymous ? '?' : initials(conv.otherName)}
                      </div>
                    {/if}
                    <div class="flex-1 min-w-0">
                      <div class="flex items-center justify-between">
                        <p class="text-sm font-semibold text-foreground truncate">{conv.otherName}</p>
                        <span class="text-xs text-muted-foreground shrink-0 ml-2">{timeAgoShort(conv.lastTime)}</span>
                      </div>
                      <p class="text-xs text-muted-foreground truncate">{conv.lastMessage}</p>
                    </div>
                    {#if conv.unread}
                      <div class="w-2 h-2 rounded-full shrink-0" style="background: hsl(35 100% 62%)"></div>
                    {/if}
                  </button>
                {/each}
              {/if}
            </div>
          </div>
        {/if}
      </div>

      <!-- Notifications popover -->
      <div class="relative">
        <button onclick={openNotifications} class="relative p-2 rounded-lg hover:bg-white/10 transition-colors text-white" title="Notifications">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor"
            stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
            <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/>
            <path d="M13.73 21a2 2 0 0 1-3.46 0"/>
          </svg>
          {#if unreadNotifications > 0}
            <span class="absolute top-1.5 right-1.5 w-2 h-2 rounded-full" style="background: hsl(35 100% 62%); box-shadow: 0 0 0 2px var(--color-header)"></span>
          {/if}
        </button>
        {#if notifOpen}
          <button class="fixed inset-0 z-40 cursor-default" onclick={() => notifOpen = false} tabindex="-1" aria-hidden="true"></button>
          <div class="absolute right-0 top-full mt-2 w-80 bg-white rounded-xl border border-border z-50 overflow-hidden"
            style="box-shadow: 0 8px 24px rgba(0,0,0,0.15)">
            <div class="px-4 py-3 border-b border-border">
              <span class="text-sm font-semibold text-foreground">Notifications</span>
            </div>
            <div class="overflow-y-auto" style="max-height: 400px">
              {#if notifLoading}
                <div class="flex flex-col gap-2 p-3">
                  {#each [1,2,3] as _}
                    <div class="flex items-center gap-3 p-2 rounded-lg animate-pulse">
                      <div class="w-9 h-9 rounded-full bg-muted shrink-0"></div>
                      <div class="flex-1"><div class="h-3 bg-muted rounded w-3/4 mb-1.5"></div><div class="h-3 bg-muted rounded w-1/4"></div></div>
                    </div>
                  {/each}
                </div>
              {:else if notifItems.length === 0}
                <div class="py-10 text-center">
                  <p class="text-sm text-muted-foreground">You're all caught up.</p>
                </div>
              {:else}
                {#each notifItems as notif}
                  <button
                    onclick={() => { if (notif.link) { goto(notif.link); notifOpen = false } }}
                    class="flex items-start gap-3 px-4 py-3 w-full text-left transition-colors hover:bg-muted/40 border-b border-border/50 last:border-0"
                    style={!notif.is_read ? 'background: hsl(234 40% 97%)' : ''}
                  >
                    <div class="w-8 h-8 rounded-full flex items-center justify-center shrink-0 mt-0.5" style="background: hsl(234 26% 41%)">
                      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        {@html notifIcon(notif.type)}
                      </svg>
                    </div>
                    <div class="flex-1 min-w-0">
                      <p class="text-sm text-foreground leading-snug">{notif.body}</p>
                      <p class="text-xs text-muted-foreground mt-0.5">{timeAgoShort(notif.created_at)}</p>
                    </div>
                  </button>
                {/each}
              {/if}
            </div>
          </div>
        {/if}
      </div>

      <!-- Profile with dropdown -->
      <div class="relative" data-profile-dropdown>
        <button onclick={() => profileDropdownOpen = !profileDropdownOpen}
          class="flex items-center gap-1.5 pl-1 pr-2 py-1 rounded-full transition-colors"
          style="background: rgba(255,255,255,0.12)"
          title="Profile">
          {#if userAvatarUrl}
            <img src={userAvatarUrl} alt="Profile" class="w-7 h-7 rounded-full object-cover shrink-0" />
          {:else}
            <div class="w-7 h-7 rounded-full flex items-center justify-center shrink-0"
              style="background: rgba(255,255,255,0.20)">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="white"
                stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
                <circle cx="12" cy="7" r="4"/>
              </svg>
            </div>
          {/if}
          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="white"
            stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
            <polyline points="6 9 12 15 18 9"/>
          </svg>
        </button>
        {#if profileDropdownOpen}
          <button class="fixed inset-0 z-40 cursor-default" onclick={() => profileDropdownOpen = false} tabindex="-1" aria-hidden="true"></button>
          <div class="absolute right-0 top-full mt-2 w-44 bg-white rounded-xl border border-border py-1 z-50"
            style="box-shadow: 0 8px 24px rgba(0,0,0,0.15)">
            <a href="/profile" onclick={() => profileDropdownOpen = false}
              class="flex items-center gap-2.5 px-3 py-2 text-sm text-foreground hover:bg-muted transition-colors">
              <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/>
                <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/>
              </svg>
              Edit profile
            </a>
            <button onclick={signOut}
              class="w-full flex items-center gap-2.5 px-3 py-2 text-sm hover:bg-muted transition-colors"
              style="color: hsl(0 72% 51%)">
              <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/>
                <polyline points="16 17 21 12 16 7"/>
                <line x1="21" y1="12" x2="9" y2="12"/>
              </svg>
              Log out
            </button>
          </div>
        {/if}
      </div>

    </div>
  </header>

  <!-- Body -->
  <div class="flex flex-1 overflow-hidden">

    <!-- Left sidebar (desktop only) -->
    <aside class="hidden md:flex flex-col w-72 border-r border-border bg-background shrink-0 overflow-y-auto">
      <nav class="flex flex-col gap-0.5 pt-8 px-3 pb-3">

        <!-- Home -->
        <a href="/home"
          class="flex items-center gap-2.5 px-5 py-2 rounded-lg text-sm font-normal transition-colors"
          style={isActive('/home') ? 'background: hsl(234 40% 97%); color: hsl(234 26% 41%)' : 'color: hsl(234 20% 30%)'}>
          <div class="w-8 h-8 flex items-center justify-center shrink-0">
            {#if isActive('/home')}
              <svg width="19" height="19" viewBox="0 0 24 24" fill="hsl(234 26% 41%)" stroke="hsl(234 26% 41%)" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
                <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>
                <polyline points="9 22 9 12 15 12 15 22" fill="white" stroke="white" stroke-width="1.5"/>
              </svg>
            {:else}
              <svg width="19" height="19" viewBox="0 0 24 24" fill="none" stroke="hsl(234 20% 40%)" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>
                <polyline points="9 22 9 12 15 12 15 22"/>
              </svg>
            {/if}
          </div>
          Home
        </a>

        <!-- My Groups section -->
        <div class="mt-10 mb-1 px-5 flex items-center justify-between">
          <span class="font-bold uppercase tracking-wider text-muted-foreground" style="font-size: 10px">My Groups</span>
          <a href="/groups/new" class="text-muted-foreground hover:text-foreground transition-colors" title="New group">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <line x1="12" y1="5" x2="12" y2="19"/>
              <line x1="5" y1="12" x2="19" y2="12"/>
            </svg>
          </a>
        </div>

        {#if myGroups.length === 0}
          <a href="/groups/new"
            class="flex items-center gap-2.5 px-5 py-2 rounded-lg text-sm font-normal transition-colors"
            style="color: hsl(234 12% 52%)">
            Create your first group
          </a>
        {:else}
          {#each myGroups as group}
            {@const active = isActive(`/groups/${group.id}`)}
            {@const isAdmin = group.role === 'admin' || group.role === 'co_admin'}
            <div class="group/row flex items-center rounded-lg transition-colors"
              style={active ? 'background: hsl(234 40% 97%)' : ''}>
              <a href="/groups/{group.id}"
                class="flex items-center gap-2.5 px-5 py-2 text-sm font-normal flex-1 min-w-0 transition-colors"
                style={active ? 'color: hsl(234 26% 41%)' : 'color: hsl(234 20% 30%)'}>
                {#if group.avatar_url}
                  <img src={group.avatar_url} alt={group.name} class="w-8 h-8 rounded-full shrink-0 object-cover"
                    style={isAdmin ? 'outline: 2px solid hsl(35 100% 62%); outline-offset: 1px' : ''} />
                {:else}
                  <div class="w-8 h-8 rounded-full flex items-center justify-center text-white shrink-0"
                    style="background: hsl(234 26% 41%); font-size: 11px; font-weight: 700;{isAdmin ? ' outline: 2px solid hsl(35 100% 62%); outline-offset: 1px;' : ''}">
                    {initials(group.name)}
                  </div>
                {/if}
                <span class="truncate">{group.name}</span>
              </a>
              <!-- Favorite star -->
              <button
                onclick={(e) => toggleFavorite(group, e)}
                class="pr-5 pl-1 py-2 shrink-0 transition-opacity {group.is_favorited ? 'opacity-100' : 'opacity-30 group-hover/row:opacity-100'}"
                title={group.is_favorited ? 'Unfavorite' : 'Favorite'}>
                <svg width="12" height="12" viewBox="0 0 24 24"
                  fill={group.is_favorited ? 'hsl(35 100% 62%)' : 'none'}
                  stroke={group.is_favorited ? 'hsl(35 100% 62%)' : 'hsl(234 12% 52%)'}
                  stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                  <polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/>
                </svg>
              </button>
            </div>
          {/each}
        {/if}


      </nav>
    </aside>

    <!-- Main content -->
    <main class="flex-1 overflow-y-auto pb-20 md:pb-0">
      <slot />
    </main>

  </div>

  <!-- Mobile bottom nav -->
  <nav class="md:hidden fixed bottom-0 left-0 right-0 bg-background border-t border-border flex z-50">
    {#each mobileNavItems as item}
      {@const active = isActive(item.href)}
      <a href={item.href}
        class="flex-1 flex flex-col items-center justify-center gap-1 py-3 text-xs font-medium transition-colors"
        style={active ? 'color: hsl(234 26% 41%)' : 'color: hsl(234 12% 52%)'}>
        <div class="relative">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none"
            stroke={active ? 'hsl(234 26% 41%)' : 'hsl(234 12% 52%)'}
            stroke-width={active ? '2' : '1.8'}
            stroke-linecap="round" stroke-linejoin="round">
            {@html item.icon}
          </svg>
          {#if item.label === 'Messages' && unreadMessages > 0}
            <span class="absolute -top-0.5 -right-0.5 w-2 h-2 rounded-full" style="background: hsl(35 100% 62%); box-shadow: 0 0 0 2px white"></span>
          {/if}
          {#if item.label === 'Alerts' && unreadNotifications > 0}
            <span class="absolute -top-0.5 -right-0.5 w-2 h-2 rounded-full" style="background: hsl(35 100% 62%); box-shadow: 0 0 0 2px white"></span>
          {/if}
        </div>
        {item.label}
      </a>
    {/each}
  </nav>

</div>
{/if}