<script>
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

  const navItems = [
    {
      href: '/groups',
      label: 'Groups',
      prefix: '/groups',
      icon: `<path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>`,
    },
    {
      href: '/messages',
      label: 'Messages',
      prefix: '/messages',
      icon: `<path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>`,
      badge: 'messages',
    },
    {
      href: '/calendar',
      label: 'Calendar',
      prefix: '/calendar',
      icon: `<rect x="3" y="4" width="18" height="18" rx="2" ry="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/>`,
    },
    {
      href: '/notifications',
      label: 'Alerts',
      prefix: '/notifications',
      icon: `<path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/>`,
      badge: 'notifications',
    },
  ]
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
      {@const hasBadge = (item.badge === 'messages' && unreadMessages > 0) || (item.badge === 'notifications' && unreadNotifications > 0)}
      <a
        href={item.href}
        title={item.label}
        class="relative flex items-center justify-center w-9 h-9 rounded-xl transition-colors hover:bg-white/10"
        style={active ? 'background: rgba(255,255,255,0.22); color: white' : 'color: rgba(255,255,255,0.70)'}
      >
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor"
          stroke-width={active ? '2.2' : '1.8'} stroke-linecap="round" stroke-linejoin="round">
          {@html item.icon}
        </svg>
        {#if hasBadge}
          <span class="absolute top-1 right-1 w-2 h-2 rounded-full" style="background: hsl(35 100% 62%); box-shadow: 0 0 0 1.5px var(--color-header)"></span>
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
            style="{isGroupActive ? 'box-shadow: 0 0 0 2px rgba(255,255,255,0.7), 0 0 14px 6px hsla(252, 60%, 82%, 0.28)' : ''}{isAdmin ? '; outline: 2px solid hsl(35 100% 62%); outline-offset: 1px' : ''}"
          />
        {:else}
          <div
            class="w-8 h-8 flex items-center justify-center text-white shrink-0 transition-all {isGroupActive ? 'rounded-full' : 'rounded-lg'}"
            style="background: rgba(255,255,255,0.15); font-size: 10px; font-weight: 700; {isGroupActive ? 'box-shadow: 0 0 0 2px rgba(255,255,255,0.7), 0 0 14px 6px hsla(252, 60%, 82%, 0.28)' : ''}{isAdmin ? '; outline: 2px solid hsl(35 100% 62%); outline-offset: 1px' : ''}"
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
