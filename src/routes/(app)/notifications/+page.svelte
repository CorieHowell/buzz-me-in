<script>
  import { supabase } from '$lib/supabase'
  import { goto } from '$app/navigation'
  import { onMount } from 'svelte'

  let notifications = $state([])
  let loading = $state(true)
  let currentUserId = $state(null)

  onMount(async () => {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) { goto('/auth/login'); return }
    currentUserId = user.id
    await loadNotifications()
    await markAllRead()
    loading = false
  })

  async function loadNotifications() {
    const { data } = await supabase
      .from('notifications')
      .select('*')
      .eq('user_id', currentUserId)
      .order('created_at', { ascending: false })
      .limit(50)
    notifications = data ?? []
  }

  async function markAllRead() {
    await supabase
      .from('notifications')
      .update({ is_read: true })
      .eq('user_id', currentUserId)
      .eq('is_read', false)
  }

  function timeAgo(dateStr) {
    const diff = Date.now() - new Date(dateStr).getTime()
    const mins = Math.floor(diff / 60000)
    const hours = Math.floor(mins / 60)
    const days = Math.floor(hours / 24)
    if (mins < 1) return 'just now'
    if (mins < 60) return `${mins}m ago`
    if (hours < 24) return `${hours}h ago`
    return `${days}d ago`
  }

  function iconForType(type) {
    switch (type) {
      case 'new_member':
        return `<path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>`
      case 'join_request':
        return `<path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="8.5" cy="7" r="4"/><line x1="20" y1="8" x2="20" y2="14"/><line x1="23" y1="11" x2="17" y2="11"/>`
      case 'event_reminder':
        return `<rect x="3" y="4" width="18" height="18" rx="2" ry="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/>`
      default:
        return `<circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/>`
    }
  }
</script>

<div class="max-w-lg mx-auto px-4 py-6">

  <h1 class="text-xl font-semibold text-foreground mb-6">Notifications</h1>

  {#if loading}
    <div class="flex flex-col gap-3">
      {#each [1,2,3] as _}
        <div class="flex items-center gap-3 p-4 rounded-xl border border-border animate-pulse">
          <div class="w-9 h-9 rounded-full bg-muted shrink-0"></div>
          <div class="flex-1">
            <div class="h-4 bg-muted rounded w-3/4 mb-2"></div>
            <div class="h-3 bg-muted rounded w-1/4"></div>
          </div>
        </div>
      {/each}
    </div>

  {:else if notifications.length === 0}
    <div class="text-center py-16">
      <div class="w-16 h-16 rounded-2xl flex items-center justify-center mx-auto mb-4" style="background: hsl(234 40% 97%)">
        <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="hsl(234 26% 41%)" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
          <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/>
          <path d="M13.73 21a2 2 0 0 1-3.46 0"/>
        </svg>
      </div>
      <h2 class="text-base font-semibold text-foreground mb-1">No notifications</h2>
      <p class="text-sm text-muted-foreground">You're all caught up.</p>
    </div>

  {:else}
    <div class="flex flex-col gap-2">
      {#each notifications as notif}
        <button
          onclick={() => notif.link && goto(notif.link)}
          class="flex items-start gap-3 p-4 rounded-xl border text-left w-full transition-colors hover:bg-muted/30"
          style={!notif.is_read
            ? 'border-color: hsl(234 26% 41%); background: hsl(234 40% 97%)'
            : 'border-color: hsl(234 20% 88%)'}
        >
          <!-- Icon -->
          <div class="w-9 h-9 rounded-full flex items-center justify-center shrink-0 mt-0.5" style="background: hsl(234 26% 41%)">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              {@html iconForType(notif.type)}
            </svg>
          </div>

          <!-- Content -->
          <div class="flex-1 min-w-0">
            <p class="text-sm text-foreground">{notif.body}</p>
            <p class="text-xs text-muted-foreground mt-1">{timeAgo(notif.created_at)}</p>
          </div>

          <!-- Unread dot -->
          {#if !notif.is_read}
            <div class="w-2 h-2 rounded-full shrink-0 mt-1.5" style="background: hsl(35 100% 62%)"></div>
          {/if}
        </button>
      {/each}
    </div>
  {/if}

</div>