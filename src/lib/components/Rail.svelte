<script>
  // icons
  import GroupsIconSvg from '$lib/icons/GroupsIcon.svg?raw'
  import GroupsIconHoverSvg from '$lib/icons/GroupsIcon-Hover.svg?raw'
  import MessagesIconSvg from '$lib/icons/MessagesIcon.svg?raw'
  import MessagesIconHoverSvg from '$lib/icons/MessagesIcon-Hover.svg?raw'
  import CalendarIconSvg from '$lib/icons/CalendarIcon.svg?raw'
  import CalendarIconHoverSvg from '$lib/icons/CalendarIcon-Hover.svg?raw'
  import NotificationIconSvg from '$lib/icons/NotificationIcon.svg?raw'
  import NotificationsIconHoverSvg from '$lib/icons/NotificationsIcon-Hover.svg?raw'
  import NotificationsActiveIconSvg from '$lib/icons/NotificationsActiveIcon.svg?raw'
  import NotificationsActiveIconHoverSvg from '$lib/icons/NotificationsActiveIcon-Hover.svg?raw'

  function processIcon(raw, size = 20) {
    return raw.replace('<svg ', `<svg width="${size}" height="${size}" `)
  }

  let {
    myGroups = [],
    user = null,
    userAvatarUrl = null,
    unreadMessages = 0,
    unreadNotifications = 0,
    currentPath = '',
    calSyncOpen = $bindable(false),
    signOut = () => {},
  } = $props()

  let profileDropdownOpen = $state(false)

  function isActive(prefix) {
    if (prefix === '/groups') {
      // Only active on the groups list/new — not inside a specific group
      return currentPath === '/groups' || currentPath.startsWith('/groups/new')
    }
    return currentPath.startsWith(prefix)
  }

  function initials(name) {
    if (!name) return '?'
    return name.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2)
  }

  let navItems = $derived([
    {
      href: '/groups',
      label: 'Groups',
      prefix: '/groups',
      iconHtml: processIcon(GroupsIconSvg),
      iconHoverHtml: processIcon(GroupsIconHoverSvg),
    },
    {
      href: '/messages',
      label: 'Messages',
      prefix: '/messages',
      iconHtml: processIcon(MessagesIconSvg),
      iconHoverHtml: processIcon(MessagesIconHoverSvg),
      badge: 'messages',
    },
    {
      href: '/calendar',
      label: 'Calendar',
      prefix: '/calendar',
      iconHtml: processIcon(CalendarIconSvg),
      iconHoverHtml: processIcon(CalendarIconHoverSvg),
    },
    {
      href: '/notifications',
      label: 'Alerts',
      prefix: '/notifications',
      iconHtml: processIcon(unreadNotifications > 0 ? NotificationsActiveIconSvg : NotificationIconSvg),
      iconHoverHtml: processIcon(unreadNotifications > 0 ? NotificationsActiveIconHoverSvg : NotificationsIconHoverSvg),
    },
  ])
</script>

<aside class="relative flex flex-col h-screen w-[76px] shrink-0 overflow-hidden" style="background: hsl(267.7 52.54% 9%)">

  <!-- Decorative blobs (matching marketing hero) -->
  <div class="absolute top-0 right-0 w-40 h-40 rounded-full pointer-events-none"
    style="background: var(--color-accent); opacity: 0.10; filter: blur(60px); transform: translate(40%, -30%);"></div>
  <div class="absolute bottom-0 left-0 w-32 h-32 rounded-full pointer-events-none"
    style="background: var(--color-accent-soft); opacity: 0.10; filter: blur(50px);"></div>

  <!-- Logo -->
  <a href="/home" class="relative z-10 flex items-center justify-center h-14 shrink-0" title="Home">
    <div class="flex flex-col items-center font-black">
      <span style="font-size: 13px; line-height: 1; color: hsl(234 65% 82%); letter-spacing: -0.01em">buzz</span>
      <span style="font-size: 12px; line-height: 1; letter-spacing: -0.01em; margin-top: -4px"><span style="color: hsl(35 100% 72%)">me</span><span style="color: hsl(234 65% 82%)">in</span></span>
    </div>
  </a>

  <!-- Primary nav icons -->
  <nav class="relative z-10 flex flex-col items-center gap-1 pb-2">
    {#each navItems as item}
      {@const active = isActive(item.prefix)}
      <a
        href={item.href}
        title={item.label}
        class="group relative flex items-center justify-center w-9 h-9 rounded-xl transition-colors hover:bg-white/10"
        style={active ? 'background: rgba(255,255,255,0.22)' : ''}
      >
        <span class={active ? 'hidden' : 'group-hover:hidden'}>{@html item.iconHtml}</span>
        <span class={active ? 'flex' : 'hidden group-hover:flex'}>{@html item.iconHoverHtml}</span>
        {#if item.badge === 'messages' && unreadMessages > 0}
          <span class="absolute top-1 right-1 w-2 h-2 rounded-full" style="background: hsl(35 100% 62%); box-shadow: 0 0 0 1.5px hsl(267.7 52.54% 9%)"></span>
        {/if}
      </a>
    {/each}

  </nav>

  <!-- Group avatar shortcuts (scrollable) -->
  <div class="relative z-10 flex-1 overflow-y-auto flex flex-col items-center gap-4 px-2 py-2 no-scrollbar">
    {#if myGroups.length > 0}
      <div class="w-6 h-px rounded-full mb-0.5" style="background: rgba(255,255,255,0.12)"></div>
    {/if}
    {#each myGroups as group}
      {@const isGroupActive = currentPath.startsWith(`/groups/${group.id}`)}
      {@const isAdmin = group.role === 'admin' || group.role === 'co_admin'}
      <a
        href="/groups/{group.id}/board"
        title={group.name}
        class="shrink-0 transition-all"
      >
        {#if group.avatar_url}
          <img
            src={group.avatar_url}
            alt={group.name}
            class="w-8 h-8 object-cover transition-all {isGroupActive ? 'rounded-full' : 'rounded-lg'}"
            style="{isGroupActive ? 'box-shadow: 0 0 0 2px rgba(255,255,255,0.7), 0 0 14px 6px hsla(252, 60%, 82%, 0.28)' : ''}{isAdmin ? '; outline: 1.5px solid hsl(35 100% 62%); outline-offset: 1px' : ''}"
          />
        {:else}
          <div
            class="w-8 h-8 flex items-center justify-center text-white shrink-0 transition-all {isGroupActive ? 'rounded-full' : 'rounded-lg'}"
            style="background: rgba(255,255,255,0.15); font-size: 10px; font-weight: 700; {isGroupActive ? 'box-shadow: 0 0 0 2px rgba(255,255,255,0.7), 0 0 14px 6px hsla(252, 60%, 82%, 0.28)' : ''}{isAdmin ? '; outline: 1.5px solid hsl(35 100% 62%); outline-offset: 1px' : ''}"
          >
            {initials(group.name)}
          </div>
        {/if}
      </a>
    {/each}
  </div>

  <!-- User avatar + profile dropdown (bottom) -->
  <div class="relative z-10 flex items-center justify-center pb-4">
    <button
      onclick={() => profileDropdownOpen = !profileDropdownOpen}
      title="Profile"
      class="w-8 h-8 rounded-lg overflow-hidden flex items-center justify-center shrink-0 transition-opacity hover:opacity-85"
      style="background: rgba(255,255,255,0.2)"
    >
      {#if userAvatarUrl}
        <img src={userAvatarUrl} alt="Profile" class="w-full h-full object-cover" />
      {:else}
        <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="rgba(255,255,255,0.9)"
          stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
          <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
          <circle cx="12" cy="7" r="4"/>
        </svg>
      {/if}
    </button>

    {#if profileDropdownOpen}
      <button class="fixed inset-0 z-40 cursor-default" onclick={() => profileDropdownOpen = false} tabindex="-1" aria-hidden="true"></button>
      <div class="absolute left-full bottom-0 ml-2 w-52 bg-white rounded-xl border border-border py-1 z-50"
        style="box-shadow: 0 8px 24px rgba(0,0,0,0.18)">
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
        <button onclick={() => { profileDropdownOpen = false; signOut() }}
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

</aside>
