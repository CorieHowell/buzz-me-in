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
  let calSyncOpen = $state(false)
  let userIsPro = $state(false)

  const syncProviders = [
    { name: 'Google Calendar', icon: `<svg width="16" height="16" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4"/><path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/><path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l3.66-2.84z" fill="#FBBC05"/><path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/></svg>` },
    { name: 'Apple Calendar', icon: `<svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/></svg>` },
    { name: 'Outlook', icon: `<svg width="16" height="16" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><rect x="1" y="6" width="13" height="12" rx="1" fill="#0364B8"/><path d="M7.5 9C5.57 9 4 10.57 4 12.5S5.57 16 7.5 16 11 14.43 11 12.5 9.43 9 7.5 9zm0 5.5c-1.38 0-2.5-1.12-2.5-2.5S6.12 10 7.5 10 10 11.12 10 12.5 8.88 14.5 7.5 14.5z" fill="white"/><path d="M14 8l9 4-9 4V8z" fill="#0078D4"/><path d="M14 8v8l4-2V10l-4-2z" fill="#0364B8"/></svg>` },
  ]
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
      if (DEV_MOCK) { unreadNotifications = 0; return }
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
      case 'join_request':      return `<path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="8.5" cy="7" r="4"/><line x1="20" y1="8" x2="20" y2="14"/><line x1="23" y1="11" x2="17" y2="11"/>`
      case 'event_reminder':    return `<rect x="3" y="4" width="18" height="18" rx="2" ry="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/>`
      case 'event_cancelled':   return `<rect x="3" y="4" width="18" height="18" rx="2" ry="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/><line x1="10" y1="14" x2="14" y2="18"/><line x1="14" y1="14" x2="10" y2="18"/>`
      case 'event_rescheduled': return `<rect x="3" y="4" width="18" height="18" rx="2" ry="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/><polyline points="12 14 12 17 14 17"/>`
      case 'reply':             return `<path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>`
      case 'bring_assigned':    return `<path d="M6 2L3 6v14a2 2 0 002 2h14a2 2 0 002-2V6l-3-4z"/><line x1="3" y1="6" x2="21" y2="6"/><path d="M16 10a4 4 0 01-8 0"/>`
      case 'date_vote':         return `<rect x="3" y="4" width="18" height="18" rx="2" ry="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/><polyline points="9 16 11 18 15 14"/>`
      default:                  return `<circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/>`
    }
  }

  function notifIconBg(type) {
    switch (type) {
      case 'event_reminder':
      case 'event_cancelled':
      case 'event_rescheduled':
      case 'date_vote':         return 'hsl(234 26% 41%)'
      case 'join_request':      return 'hsl(234 26% 41%)'
      case 'reply':             return 'hsl(220 9% 46%)'
      case 'bring_assigned':    return 'hsl(142 55% 40%)'
      default:                  return 'hsl(234 26% 41%)'
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

  const DEV_MOCK = true

  const mockUser = { id: 'mock-user-id', email: 'dev@example.com' }
  const mockGroups = [
    { id: 'g1', name: 'Book Club', avatar_url: null, role: 'admin', is_favorited: true },
    { id: 'g2', name: 'Hiking Crew', avatar_url: null, role: 'member', is_favorited: false },
    { id: 'g3', name: 'Dinner Club', avatar_url: null, role: 'co_admin', is_favorited: false },
  ]

  const mockNotifs = [
    { id: 'n1', type: 'event_reminder', body: 'March Book Club is tomorrow at 7:00 PM', groupName: 'Book Club',  entityPhoto: null, entityInitials: 'BC', link: '/groups/g1/events/e1', created_at: new Date(Date.now() - 30 * 60 * 1000).toISOString(), is_read: false },
    { id: 'n2', type: 'join_request',   body: 'Alex W. wants to join Hiking Crew',      actorName: 'Alex W.',   actorPhoto: null,  link: '/groups/g2/members', created_at: new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString(), is_read: false },
    { id: 'n3', type: 'reply',          body: 'Sarah M. replied to your post in Book Club', actorName: 'Sarah M.', actorPhoto: null, link: '/groups/g1/board', created_at: new Date(Date.now() - 5 * 60 * 60 * 1000).toISOString(), is_read: true },
    { id: 'n4', type: 'bring_assigned', body: "You've been assigned to bring Lemon bars to March Book Club", entityPhoto: null, entityInitials: 'BC', link: '/groups/g1/events/e1', created_at: new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString(), is_read: true },
  ]

  function notifAvatarInitials(notif) {
    if (notif.actorName) return notif.actorName.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2)
    return notif.entityInitials ?? '?'
  }

  function notifAvatarPhoto(notif) {
    return notif.actorPhoto ?? notif.entityPhoto ?? null
  }

  onMount(async () => {
    if (DEV_MOCK) {
      user = mockUser
      myGroups = mockGroups
      notifItems = mockNotifs
      unreadNotifications = mockNotifs.filter(n => !n.is_read).length
      ready = true
      return
    }

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
<div class="flex h-screen bg-background overflow-hidden">

  <!-- Left sidebar (desktop only) -->
  <aside class="hidden md:flex flex-col w-72 shrink-0 overflow-y-auto relative" style="background: var(--color-header)">
    <!-- Blob decorations -->
    <div class="absolute top-0 right-0 w-56 h-56 rounded-full pointer-events-none" style="background: var(--color-accent); opacity: 0.07; filter: blur(70px); transform: translate(30%, -25%);"></div>
    <div class="absolute bottom-0 left-0 w-48 h-48 rounded-full pointer-events-none" style="background: var(--color-accent-soft); opacity: 0.07; filter: blur(60px);"></div>

    <!-- Wordmark -->
    <div class="px-6 pt-7 pb-2 shrink-0 relative z-10">
      <a href="/home" class="inline-block">
        <span class="font-semibold text-3xl leading-none tracking-tight">
          <span style="color: hsl(234 65% 82%)">buzz</span><span style="color: hsl(35 100% 72%)">me</span><span style="color: hsl(235 45% 78%)">in</span>
        </span>
      </a>
    </div>

    <nav class="flex flex-col gap-0.5 pt-6 px-3 pb-3 relative z-10">

      <!-- Home -->
      <a href="/home"
        class="flex items-center gap-2.5 px-5 py-2 rounded-full text-sm font-normal transition-colors"
        style={isActive('/home') ? 'background: rgba(255,255,255,0.12); color: white' : 'color: rgba(255,255,255,0.82)'}>
        <div class="w-8 h-8 flex items-center justify-center shrink-0">
          {#if isActive('/home')}
            <svg width="19" height="19" viewBox="0 0 24 24" fill="white" stroke="white" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
              <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>
              <polyline points="9 22 9 12 15 12 15 22" fill="rgba(255,255,255,0.25)" stroke="rgba(255,255,255,0.5)" stroke-width="1.5"/>
            </svg>
          {:else}
            <svg width="19" height="19" viewBox="0 0 24 24" fill="none" stroke="rgba(255,255,255,0.82)" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
              <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>
              <polyline points="9 22 9 12 15 12 15 22"/>
            </svg>
          {/if}
        </div>
        Home
      </a>

      <!-- My Groups section -->
      <div class="mt-10 mb-1 px-5 flex items-center justify-between">
        <span class="font-bold uppercase tracking-wider" style="font-size: 10px; color: rgba(255,255,255,0.52)">My Groups</span>
        <a href="/groups/new" class="transition-opacity opacity-80 hover:opacity-100" title="New group" style="color: rgba(255,255,255,0.92)">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <line x1="12" y1="5" x2="12" y2="19"/>
            <line x1="5" y1="12" x2="19" y2="12"/>
          </svg>
        </a>
      </div>

      {#if myGroups.length === 0}
        <a href="/groups/new"
          class="flex items-center gap-2.5 px-5 py-2 rounded-full text-sm font-normal transition-colors"
          style="color: rgba(255,255,255,0.78)">
          Create your first group
        </a>
      {:else}
        {#each myGroups as group}
          {@const active = isActive(`/groups/${group.id}`)}
          {@const isAdmin = group.role === 'admin' || group.role === 'co_admin'}
          <div class="group/row flex items-center rounded-full transition-colors"
            style={active ? 'background: rgba(255,255,255,0.12)' : ''}>
            <a href="/groups/{group.id}"
              class="flex items-center gap-2.5 px-5 py-2 text-sm font-normal flex-1 min-w-0 transition-colors"
              style={active ? 'color: white' : 'color: rgba(255,255,255,0.82)'}>
              {#if group.avatar_url}
                <img src={group.avatar_url} alt={group.name} class="w-8 h-8 rounded-full shrink-0 object-cover"
                  style={isAdmin ? 'outline: 2px solid hsl(35 100% 62%); outline-offset: 1px' : ''} />
              {:else}
                <div class="w-8 h-8 rounded-full flex items-center justify-center text-white shrink-0"
                  style="background: rgba(255,255,255,0.15); font-size: 11px; font-weight: 700;{isAdmin ? ' outline: 2px solid hsl(35 100% 62%); outline-offset: 1px;' : ''}">
                  {initials(group.name)}
                </div>
              {/if}
              <span class="truncate">{group.name}</span>
            </a>
            <!-- Favorite star -->
            <button
              onclick={(e) => toggleFavorite(group, e)}
              class="pr-5 pl-1 py-2 shrink-0 transition-opacity {group.is_favorited ? 'opacity-100' : 'opacity-55 group-hover/row:opacity-100'}"
              title={group.is_favorited ? 'Unfavorite' : 'Favorite'}>
              <svg width="12" height="12" viewBox="0 0 24 24"
                fill={group.is_favorited ? 'hsl(35 100% 62%)' : 'none'}
                stroke={group.is_favorited ? 'hsl(35 100% 62%)' : 'rgba(255,255,255,0.5)'}
                stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/>
              </svg>
            </button>
          </div>
        {/each}
      {/if}

    </nav>
  </aside>

  <!-- Right column: header + content -->
  <div class="flex flex-col flex-1 overflow-hidden">

    <!-- Top header (desktop only) -->
    <header class="hidden md:flex items-center h-16 px-6 shrink-0 z-20 bg-background border-b border-border">

      <div class="flex-1"></div>

      <div class="flex items-center gap-2.5">

        <!-- Search -->
        <form onsubmit={handleSearch} class="relative flex items-center">
          <svg class="absolute left-3 pointer-events-none" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="hsl(234 12% 58%)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/>
          </svg>
          <input
            bind:value={searchQuery}
            placeholder="Search"
            class="h-9 pl-8 pr-3 text-sm rounded-full border-0 focus:outline-none w-44"
            style="background: hsl(234 20% 96%); color: hsl(234 20% 18%);"
          />
        </form>

        <!-- Messages popover -->
        <div class="relative">
          <button onclick={openMessages} class="relative p-2.5 rounded-lg hover:bg-muted transition-colors" style="color: hsl(234 26% 41%)" title="Messages">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor"
            stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
            <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
          </svg>
          {#if unreadMessages > 0}
            <span class="absolute top-1.5 right-1.5 w-2 h-2 rounded-full" style="background: hsl(35 100% 62%); box-shadow: 0 0 0 2px white"></span>
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
        <button onclick={openNotifications} class="relative p-2.5 rounded-lg hover:bg-muted transition-colors" style="color: hsl(234 26% 41%)" title="Notifications">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor"
            stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
            <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/>
            <path d="M13.73 21a2 2 0 0 1-3.46 0"/>
          </svg>
          {#if unreadNotifications > 0}
            <span class="absolute top-1.5 right-1.5 w-2 h-2 rounded-full" style="background: hsl(35 100% 62%); box-shadow: 0 0 0 2px white"></span>
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
                    class="flex items-start gap-3 px-4 py-3 w-full text-left transition-colors hover:bg-slate-50 border-b border-border/50 last:border-0"
                  >
                    <!-- Photo avatar + icon badge -->
                    <div class="relative shrink-0 mt-0.5">
                      <div class="w-9 h-9 rounded-full overflow-hidden flex items-center justify-center text-white text-xs font-bold" style="background: hsl(234 26% 41%)">
                        {#if notifAvatarPhoto(notif)}
                          <img src={notifAvatarPhoto(notif)} alt="" class="w-full h-full object-cover" />
                        {:else}
                          {notifAvatarInitials(notif)}
                        {/if}
                      </div>
                      <div class="absolute -bottom-0.5 -right-0.5 w-4 h-4 rounded-full flex items-center justify-center border-2 border-white" style="background: {notifIconBg(notif.type)}">
                        <svg width="8" height="8" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                          {@html notifIcon(notif.type)}
                        </svg>
                      </div>
                    </div>
                    <div class="flex-1 min-w-0">
                      <p class="text-sm leading-snug" style={!notif.is_read ? 'color: hsl(234 20% 18%); font-weight: 500' : 'color: hsl(220 9% 40%)'}>{notif.body}</p>
                      <p class="text-xs text-muted-foreground mt-0.5">{timeAgoShort(notif.created_at)}</p>
                    </div>
                    {#if !notif.is_read}
                      <div class="w-2 h-2 rounded-full shrink-0 mt-1.5" style="background: hsl(234 26% 41%)"></div>
                    {/if}
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
          style="background: hsl(234 20% 96%)"
          title="Profile">
          {#if userAvatarUrl}
            <img src={userAvatarUrl} alt="Profile" class="w-7 h-7 rounded-full object-cover shrink-0" />
          {:else}
            <div class="w-7 h-7 rounded-full flex items-center justify-center shrink-0"
              style="background: hsl(234 40% 97%)">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="hsl(234 26% 41%)"
                stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
                <circle cx="12" cy="7" r="4"/>
              </svg>
            </div>
          {/if}
          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="hsl(234 26% 41%)"
            stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
            <polyline points="6 9 12 15 18 9"/>
          </svg>
        </button>
        {#if profileDropdownOpen}
          <button class="fixed inset-0 z-40 cursor-default" onclick={() => profileDropdownOpen = false} tabindex="-1" aria-hidden="true"></button>
          <div class="absolute right-0 top-full mt-2 w-56 bg-white rounded-xl border border-border py-1 z-50"
            style="box-shadow: 0 8px 24px rgba(0,0,0,0.15)">
            <a href="/profile" onclick={() => profileDropdownOpen = false}
              class="flex items-center gap-2.5 px-3 py-2 text-sm text-foreground hover:bg-muted transition-colors">
              <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/>
                <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/>
              </svg>
              Edit profile
            </a>
            <button onclick={() => { profileDropdownOpen = false; calSyncOpen = true }}
              class="w-full flex items-center text-left gap-2.5 px-3 py-2 text-sm text-foreground hover:bg-muted transition-colors">
              <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                <rect x="3" y="4" width="18" height="18" rx="2" ry="2"/>
                <line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/>
                <line x1="3" y1="10" x2="21" y2="10"/>
              </svg>
              Set up Calendar Sync
            </button>
            <div class="border-t border-border my-1"></div>
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