<script>
  import { supabase } from '$lib/supabase'
  import { page } from '$app/stores'
  import { goto } from '$app/navigation'
  import { onMount, setContext } from 'svelte'

  let conversations = $state([])
  let loading = $state(true)
  let currentUserId = $state(null)
  let openMenuId = $state(null)
  let mutedIds = $state(new Set())

  let currentPath = $derived($page.url.pathname)

  onMount(async () => {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) { goto('/auth/login'); return }
    currentUserId = user.id
    await loadConversations()
    loading = false
  })

  async function loadConversations() {
    if (!currentUserId) return
    const { data } = await supabase
      .from('direct_messages')
      .select('id, body, created_at, is_read, is_anonymous, sender_id, recipient_id, users!direct_messages_sender_id_fkey(display_name, avatar_url), recipient:users!direct_messages_recipient_id_fkey(display_name, avatar_url)')
      .or(`sender_id.eq.${currentUserId},recipient_id.eq.${currentUserId}`)
      .eq('is_deleted', false)
      .order('created_at', { ascending: false })

    const convMap = new Map()

    for (const msg of data ?? []) {
      if (msg.is_anonymous && msg.recipient_id === currentUserId) {
        const key = 'anon-' + msg.id
        convMap.set(key, {
          key,
          otherId: 'anonymous',
          otherName: 'Anonymous suggestion',
          otherAvatarUrl: null,
          lastMessage: extractSuggestionBody(msg.body),
          lastTime: msg.created_at,
          unread: !msg.is_read,
          isAnonymous: true,
          msgId: msg.id,
        })
        continue
      }

      const otherId = msg.sender_id === currentUserId ? msg.recipient_id : msg.sender_id
      const otherName = msg.sender_id === currentUserId
        ? msg.recipient?.display_name
        : msg.users?.display_name
      const otherAvatarUrl = msg.sender_id === currentUserId
        ? msg.recipient?.avatar_url
        : msg.users?.avatar_url

      if (!otherId) continue

      if (!convMap.has(otherId)) {
        convMap.set(otherId, {
          key: otherId,
          otherId,
          otherName,
          otherAvatarUrl,
          lastMessage: msg.body,
          lastTime: msg.created_at,
          unread: !msg.is_read && msg.recipient_id === currentUserId,
          isAnonymous: false,
          msgId: null,
        })
      } else {
        const existing = convMap.get(otherId)
        if (!msg.is_read && msg.recipient_id === currentUserId) {
          existing.unread = true
        }
      }
    }

    conversations = Array.from(convMap.values())
      .sort((a, b) => new Date(b.lastTime) - new Date(a.lastTime))
  }

  function extractSuggestionBody(body) {
    if (!body) return ''
    const lines = body.split('\n')
    return lines.slice(2).join('\n').trim() || body
  }

  function timeAgo(dateStr) {
    const diff = Date.now() - new Date(dateStr).getTime()
    const mins = Math.floor(diff / 60000)
    const hours = Math.floor(mins / 60)
    const days = Math.floor(hours / 24)
    if (mins < 1) return 'now'
    if (mins < 60) return `${mins}m`
    if (hours < 24) return `${hours}h`
    return `${days}d`
  }

  function initials(name) {
    if (!name) return '?'
    return name.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2)
  }

  function handleConvClick(conv) {
    if (conv.isAnonymous) {
      goto(`/messages/anonymous/${conv.msgId}`)
    } else {
      goto(`/messages/${conv.otherId}`)
    }
  }

  function toggleMenu(e, key) {
    e.stopPropagation()
    openMenuId = openMenuId === key ? null : key
  }

  async function markRead(conv) {
    openMenuId = null
    conversations = conversations.map(c =>
      c.key === conv.key ? { ...c, unread: false } : c
    )
    await supabase
      .from('direct_messages')
      .update({ is_read: true })
      .eq('sender_id', conv.otherId)
      .eq('recipient_id', currentUserId)
      .eq('is_read', false)
  }

  function toggleMute(conv) {
    openMenuId = null
    const next = new Set(mutedIds)
    if (next.has(conv.key)) next.delete(conv.key)
    else next.add(conv.key)
    mutedIds = next
  }

  async function deleteConv(conv) {
    openMenuId = null
    conversations = conversations.filter(c => c.key !== conv.key)
    if (!conv.isAnonymous) {
      await supabase
        .from('direct_messages')
        .update({ is_deleted: true })
        .or(`and(sender_id.eq.${conv.otherId},recipient_id.eq.${currentUserId}),and(sender_id.eq.${currentUserId},recipient_id.eq.${conv.otherId})`)
    } else {
      await supabase
        .from('direct_messages')
        .update({ is_deleted: true })
        .eq('id', conv.msgId)
    }
  }

  // Share state with child pages via context
  setContext('messagesContext', {
    get conversations() { return conversations },
    get loading() { return loading },
    get currentUserId() { return currentUserId },
    get openMenuId() { return openMenuId },
    get mutedIds() { return mutedIds },
    handleConvClick,
    toggleMenu,
    markRead,
    toggleMute,
    deleteConv,
    timeAgo,
    initials,
  })
</script>

<!-- Desktop: secondary nav (conversation list) + content outlet -->
<div class="hidden md:flex h-full">

  <!-- Conversation list sidebar -->
  <aside class="w-64 shrink-0 border-r border-border flex flex-col bg-background overflow-hidden">
    <div class="px-4 py-4 border-b border-border shrink-0">
      <p class="text-sm font-semibold text-foreground">Messages</p>
    </div>

    <div class="flex-1 overflow-y-auto">
      {#if loading}
        <div class="flex flex-col gap-0 p-2">
          {#each [1,2,3] as _}
            <div class="flex items-center gap-3 px-3 py-3 animate-pulse">
              <div class="w-8 h-8 rounded-full bg-muted shrink-0"></div>
              <div class="flex-1 min-w-0">
                <div class="h-3 bg-muted rounded w-1/2 mb-1.5"></div>
                <div class="h-3 bg-muted rounded w-3/4"></div>
              </div>
            </div>
          {/each}
        </div>
      {:else if conversations.length === 0}
        <p class="text-xs text-muted-foreground px-4 py-8 text-center">No messages yet.</p>
      {:else}
        {#each conversations as conv (conv.key)}
          {@const isMuted = mutedIds.has(conv.key)}
          {@const isConvActive = currentPath.includes(conv.isAnonymous ? conv.msgId : conv.otherId)}
          <button
            onclick={() => handleConvClick(conv)}
            class="w-full flex items-center gap-3 px-3 py-3 hover:bg-muted/40 transition-colors border-b border-border/40 last:border-0 text-left"
            style={isConvActive ? 'background: hsl(234 40% 97%)' : ''}
          >
            <!-- Avatar -->
            {#if !conv.isAnonymous && conv.otherAvatarUrl}
              <img src={conv.otherAvatarUrl} alt={conv.otherName} class="w-8 h-8 rounded-full object-cover shrink-0" />
            {:else}
              <div class="w-8 h-8 rounded-full flex items-center justify-center text-xs font-semibold text-white shrink-0"
                style="background: {conv.isAnonymous ? 'hsl(234 12% 52%)' : 'hsl(234 26% 41%)'}">
                {conv.isAnonymous ? '?' : initials(conv.otherName)}
              </div>
            {/if}

            <div class="flex-1 min-w-0">
              <p class="text-xs font-semibold text-foreground truncate"
                style={isMuted ? 'color: hsl(234 12% 52%)' : ''}>{conv.otherName}</p>
              <p class="text-xs text-muted-foreground truncate">{conv.lastMessage}</p>
            </div>

            <div class="flex flex-col items-end gap-1 shrink-0">
              <span class="text-xs text-muted-foreground">{timeAgo(conv.lastTime)}</span>
              {#if conv.unread && !isMuted}
                <div class="w-1.5 h-1.5 rounded-full" style="background: hsl(35 100% 62%)"></div>
              {/if}
            </div>
          </button>
        {/each}
      {/if}
    </div>
  </aside>

  <!-- Content outlet -->
  <main class="flex-1 overflow-y-auto min-w-0">
    <slot />
  </main>
</div>

<!-- Mobile: full-width slot only -->
<div class="md:hidden flex flex-col h-full">
  <slot />
</div>
