<script>
  import { supabase } from '$lib/supabase'
  import { page } from '$app/stores'
  import { goto } from '$app/navigation'
  import { onMount, tick } from 'svelte'

  let otherId = $derived($page.params.userId)
  let otherUser = $state(null)
  let messages = $state([])
  let loading = $state(true)
  let currentUserId = $state(null)
  let newMessage = $state('')
  let sending = $state(false)
  let messagesEnd = $state(null)
  let sharedGroup = $state(null)

  onMount(async () => {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) { goto('/auth/login'); return }
    currentUserId = user.id

    // Load other user
    const { data: otherData } = await supabase
      .from('users')
      .select('id, display_name, avatar_url')
      .eq('id', otherId)
      .single()
    otherUser = otherData

    // Verify shared group membership
    const { data: myGroups } = await supabase
      .from('group_members')
      .select('group_id')
      .eq('user_id', user.id)

    const myGroupIds = myGroups?.map(g => g.group_id) ?? []

    const { data: theirMembership } = await supabase
      .from('group_members')
      .select('group_id, groups(name)')
      .eq('user_id', otherId)
      .in('group_id', myGroupIds)
      .limit(1)
      .single()

    sharedGroup = theirMembership?.groups?.name ?? null

    await loadMessages()
    await markRead()
    loading = false
    await scrollToBottom()
  })

async function loadMessages() {
  const { data } = await supabase
    .from('direct_messages')
    .select('id, body, created_at, is_edited, is_deleted, is_anonymous, sender_id, recipient_id')
    .or(`and(sender_id.eq.${currentUserId},recipient_id.eq.${otherId}),and(recipient_id.eq.${currentUserId},is_anonymous.eq.true),and(sender_id.eq.${otherId},recipient_id.eq.${currentUserId})`)
    .eq('is_deleted', false)
    .order('created_at', { ascending: true })
  messages = data ?? []
}

  async function markRead() {
    await supabase
      .from('direct_messages')
      .update({ is_read: true })
      .eq('sender_id', otherId)
      .eq('recipient_id', currentUserId)
      .eq('is_read', false)
  }

  async function sendMessage() {
    if (!newMessage.trim()) return
    sending = true
    const body = newMessage.trim()
    newMessage = ''

    await supabase.from('direct_messages').insert({
      sender_id: currentUserId,
      recipient_id: otherId,
      body,
    })

    await loadMessages()
    sending = false
    await scrollToBottom()
  }

  async function deleteMessage(msgId) {
    await supabase.from('direct_messages').update({ is_deleted: true }).eq('id', msgId)
    await loadMessages()
  }

  async function scrollToBottom() {
    await tick()
    messagesEnd?.scrollIntoView({ behavior: 'smooth' })
  }

  function timeStr(dateStr) {
    return new Date(dateStr).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })
  }

  function dateLabel(dateStr) {
    const d = new Date(dateStr)
    const today = new Date()
    const yesterday = new Date(today)
    yesterday.setDate(yesterday.getDate() - 1)
    if (d.toDateString() === today.toDateString()) return 'Today'
    if (d.toDateString() === yesterday.toDateString()) return 'Yesterday'
    return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
  }

  function shouldShowDate(messages, index) {
    if (index === 0) return true
    const prev = new Date(messages[index - 1].created_at).toDateString()
    const curr = new Date(messages[index].created_at).toDateString()
    return prev !== curr
  }

  function initials(name) {
    if (!name) return '?'
    return name.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2)
  }
</script>

<div class="flex flex-col h-full w-full max-w-lg mx-auto">

  {#if loading}
    <div class="flex-1 flex items-center justify-center">
      <div class="w-5 h-5 rounded-full border-2 border-muted animate-spin" style="border-top-color: hsl(234 26% 41%)"></div>
    </div>

  {:else}

    <!-- Header -->
    <div class="flex items-center gap-3 px-4 py-3 border-b border-border bg-background shrink-0">
      <button onclick={() => goto('/messages')} class="p-1.5 rounded-lg hover:bg-muted transition-colors" style="color: hsl(234 12% 52%)">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <polyline points="15 18 9 12 15 6"/>
        </svg>
      </button>
      {#if otherUser?.avatar_url}
        <img src={otherUser.avatar_url} alt={otherUser.display_name} class="w-8 h-8 rounded-full object-cover shrink-0" />
      {:else}
        <div class="w-8 h-8 rounded-full flex items-center justify-center text-xs font-semibold text-white shrink-0" style="background: hsl(234 26% 41%)">
          {initials(otherUser?.display_name)}
        </div>
      {/if}
      <div class="flex-1 min-w-0">
        <p class="text-sm font-semibold text-foreground">{otherUser?.display_name}</p>
        {#if sharedGroup}
          <p class="text-xs text-muted-foreground truncate">{sharedGroup}</p>
        {/if}
      </div>
    </div>

    <!-- Messages -->
    <div class="flex-1 overflow-y-auto px-4 py-4 flex flex-col gap-1">

      {#if messages.length === 0}
        <div class="flex-1 flex items-center justify-center">
          <p class="text-sm text-muted-foreground">Send a message to start the conversation.</p>
        </div>
      {:else}
        {#each messages as msg, i}
          {@const isMe = msg.sender_id === currentUserId}

          {#if shouldShowDate(messages, i)}
            <div class="flex justify-center my-3">
              <span class="text-xs text-muted-foreground px-3 py-1 rounded-full bg-muted">{dateLabel(msg.created_at)}</span>
            </div>
          {/if}

          <div class="flex {isMe ? 'justify-end' : 'justify-start'} mb-1">
            <div class="max-w-[75%]">
              <div
                class="px-3 py-2 rounded-2xl text-sm {isMe ? 'rounded-br-sm' : 'rounded-bl-sm'}"
                style={isMe
                  ? 'background: hsl(234 26% 41%); color: white'
                  : 'background: hsl(234 40% 97%); color: hsl(234 20% 18%)'}
              >
                {msg.body}
              </div>
              <div class="flex items-center gap-1 mt-0.5 {isMe ? 'justify-end' : 'justify-start'}">
                <span class="text-xs text-muted-foreground">{timeStr(msg.created_at)}</span>
                {#if msg.is_edited}
                  <span class="text-xs text-muted-foreground">· Edited</span>
                {/if}
                {#if isMe}
                  <button
                    onclick={() => deleteMessage(msg.id)}
                    class="text-xs text-muted-foreground hover:text-destructive transition-colors ml-1"
                  >
                    Delete
                  </button>
                {/if}
              </div>
            </div>
          </div>
        {/each}
        <div bind:this={messagesEnd}></div>
      {/if}
    </div>

    <!-- Input -->
    <div class="px-4 py-3 border-t border-border bg-background shrink-0 w-full">
      <div class="flex gap-2 items-end">
        <textarea
          bind:value={newMessage}
          placeholder="Message {otherUser?.display_name}…"
          rows="1"
          class="flex-1 px-3 py-2.5 rounded-xl border border-input bg-background text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-ring resize-none"
          onkeydown={(e) => {
            if (e.key === 'Enter' && !e.shiftKey) {
              e.preventDefault()
              sendMessage()
            }
          }}
        ></textarea>
        <button
          onclick={sendMessage}
          disabled={sending || !newMessage.trim()}
          class="p-2.5 rounded-xl text-white transition-opacity disabled:opacity-40 shrink-0"
          style="background: hsl(234 26% 41%)"
        >
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <line x1="22" y1="2" x2="11" y2="13"/><polygon points="22 2 15 22 11 13 2 9 22 2"/>
          </svg>
        </button>
      </div>
    </div>

  {/if}
</div>