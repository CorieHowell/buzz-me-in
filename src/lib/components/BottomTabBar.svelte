<script>
  let {
    unreadMessages = 0,
    unreadNotifications = 0,
    currentPath = '',
  } = $props()

  function isActive(prefix) {
    return currentPath.startsWith(prefix)
  }

  const tabs = [
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

<nav class="fixed bottom-0 left-0 right-0 bg-background border-t border-border flex z-50">
  {#each tabs as tab}
    {@const active = isActive(tab.prefix)}
    {@const hasBadge = (tab.badge === 'messages' && unreadMessages > 0) || (tab.badge === 'notifications' && unreadNotifications > 0)}
    <a
      href={tab.href}
      class="flex-1 flex flex-col items-center justify-center gap-1 py-3 text-xs font-medium transition-colors"
      style={active ? 'color: hsl(234 26% 41%)' : 'color: hsl(234 12% 52%)'}
    >
      <div class="relative">
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none"
          stroke={active ? 'hsl(234 26% 41%)' : 'hsl(234 12% 52%)'}
          stroke-width={active ? '2' : '1.8'}
          stroke-linecap="round" stroke-linejoin="round">
          {@html tab.icon}
        </svg>
        {#if hasBadge}
          <span class="absolute -top-0.5 -right-0.5 w-2 h-2 rounded-full" style="background: hsl(35 100% 62%); box-shadow: 0 0 0 2px white"></span>
        {/if}
      </div>
      {tab.label}
    </a>
  {/each}
</nav>
