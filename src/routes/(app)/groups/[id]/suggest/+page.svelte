<script>
  import { supabase } from '$lib/supabase'
  import { page } from '$app/stores'
  import { goto } from '$app/navigation'
  import { onMount } from 'svelte'

  let groupId = $derived($page.params.id)
  let body = $state('')
  let sending = $state(false)
  let sent = $state(false)
  let error = $state('')
  let adminUserId = $state(null)
  let groupName = $state('')

  onMount(async () => {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) { goto('/auth/login'); return }

    // Verify membership
    const { data: membership } = await supabase
      .from('group_members')
      .select('role')
      .eq('group_id', groupId)
      .eq('user_id', user.id)
      .single()

    if (!membership) { goto(`/groups/${groupId}`); return }

    // Get group name and admin
    const { data: group } = await supabase
      .from('groups')
      .select('name')
      .eq('id', groupId)
      .single()

    groupName = group?.name ?? ''

    const { data: adminData } = await supabase
      .from('group_members')
      .select('user_id')
      .eq('group_id', groupId)
      .eq('role', 'admin')
      .single()

    adminUserId = adminData?.user_id ?? null

    // Admins don't need the suggestion box
    if (membership.role === 'admin') {
      goto(`/groups/${groupId}/board`)
      return
    }
  })

  async function sendSuggestion() {
    if (!body.trim()) return
    if (!adminUserId) { error = 'Could not find group admin.'; return }

    sending = true
    error = ''

    const { error: sendError } = await supabase
      .from('direct_messages')
      .insert({
        sender_id: null,
        recipient_id: adminUserId,
        body: `[Anonymous suggestion — ${groupName}]\n\n${body.trim()}`,
        is_anonymous: true,
      })

    if (sendError) { error = sendError.message; sending = false; return }
    sent = true
    sending = false
  }
</script>

<div class="max-w-sm mx-auto px-4 py-12">

  {#if sent}
    <div class="text-center">
      <div class="w-16 h-16 rounded-2xl flex items-center justify-center mx-auto mb-4" style="background: hsl(234 40% 97%)">
        <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="hsl(234 26% 41%)" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
          <polyline points="20 6 9 17 4 12"/>
        </svg>
      </div>
      <h2 class="text-lg font-semibold text-foreground mb-2">Suggestion sent</h2>
      <p class="text-sm text-muted-foreground mb-6">Your anonymous suggestion was sent to the group admin. They won't know it came from you.</p>
      <button
        onclick={() => goto(`/groups/${groupId}/board`)}
        class="text-sm font-medium"
        style="color: hsl(234 26% 41%)"
      >
        Back to board
      </button>
    </div>

  {:else}
    <div class="text-center mb-8">
      <div class="w-14 h-14 rounded-2xl flex items-center justify-center mx-auto mb-4" style="background: hsl(234 40% 97%)">
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="hsl(234 26% 41%)" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
          <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
        </svg>
      </div>
      <h2 class="text-lg font-semibold text-foreground mb-1">Anonymous suggestion</h2>
      <p class="text-sm text-muted-foreground">Your message will be sent to the admin of <span class="font-medium text-foreground">{groupName}</span> anonymously. They won't know who sent it.</p>
    </div>

    <div class="flex flex-col gap-4">
      <textarea
        bind:value={body}
        placeholder="Write your suggestion…"
        rows="5"
        maxlength="500"
        class="w-full px-3 py-2.5 rounded-xl border border-input bg-background text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-ring transition resize-none"
      ></textarea>
      <p class="text-xs text-muted-foreground -mt-2">{body.length}/500</p>

      {#if error}
        <p class="text-sm text-destructive">{error}</p>
      {/if}

      <button
        onclick={sendSuggestion}
        disabled={sending || !body.trim()}
        class="w-full py-2.5 rounded-xl text-sm font-semibold text-white transition-opacity disabled:opacity-60"
        style="background: hsl(234 26% 41%)"
      >
        {sending ? 'Sending…' : 'Send anonymously'}
      </button>

      <button
        onclick={() => goto(`/groups/${groupId}/board`)}
        class="text-sm text-muted-foreground text-center hover:underline"
      >
        Cancel
      </button>
    </div>
  {/if}

</div>