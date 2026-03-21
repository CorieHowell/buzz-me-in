<script>
  import { supabase } from '$lib/supabase'
  import { page } from '$app/stores'
  import { goto } from '$app/navigation'
  import { onMount } from 'svelte'

  let msgId = $derived($page.params.msgId)
  let message = $state(null)
  let loading = $state(true)

  onMount(async () => {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) { goto('/auth/login'); return }

    const { data } = await supabase
      .from('direct_messages')
      .select('id, body, created_at, is_read')
      .eq('id', msgId)
      .eq('is_anonymous', true)
      .single()

    if (!data) { goto('/messages'); return }
    message = data

    // Mark as read
    await supabase
      .from('direct_messages')
      .update({ is_read: true })
      .eq('id', msgId)

    loading = false
  })

  function formatDate(dateStr) {
    return new Date(dateStr).toLocaleDateString('en-US', {
      month: 'long', day: 'numeric', year: 'numeric',
      hour: 'numeric', minute: '2-digit'
    })
  }

  function extractBody(body) {
    if (!body) return ''
    const lines = body.split('\n')
    return lines.slice(2).join('\n').trim()
  }

  function extractGroup(body) {
    if (!body) return ''
    const match = body.match(/\[Anonymous suggestion — (.+?)\]/)
    return match?.[1] ?? ''
  }
</script>

<div class="flex flex-col h-full max-w-lg mx-auto w-full">

  {#if loading}
    <div class="flex-1 flex items-center justify-center">
      <div class="w-5 h-5 rounded-full border-2 border-muted animate-spin" style="border-top-color: hsl(234 26% 41%)"></div>
    </div>

  {:else if message}

    <!-- Header -->
    <div class="flex items-center gap-3 px-4 py-3 border-b border-border bg-background shrink-0">
      <button
        onclick={() => goto('/messages')}
        class="p-1.5 rounded-lg hover:bg-muted transition-colors"
        style="color: hsl(234 12% 52%)"
      >
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <polyline points="15 18 9 12 15 6"/>
        </svg>
      </button>
      <div class="w-8 h-8 rounded-full flex items-center justify-center text-sm font-semibold text-white shrink-0" style="background: hsl(234 12% 52%)">
        ?
      </div>
      <div class="flex-1 min-w-0">
        <p class="text-sm font-semibold text-foreground">Anonymous suggestion</p>
        {#if extractGroup(message.body)}
          <p class="text-xs text-muted-foreground">{extractGroup(message.body)}</p>
        {/if}
      </div>
    </div>

    <!-- Message -->
    <div class="flex-1 overflow-y-auto px-4 py-6">
      <div class="rounded-xl border border-border p-4" style="background: hsl(234 40% 97%)">
        <p class="text-sm text-foreground whitespace-pre-wrap">{extractBody(message.body)}</p>
        <p class="text-xs text-muted-foreground mt-3">{formatDate(message.created_at)}</p>
      </div>
      <p class="text-xs text-muted-foreground text-center mt-4">
        The sender's identity is anonymous. You cannot reply to this message.
      </p>
    </div>

  {/if}
</div>