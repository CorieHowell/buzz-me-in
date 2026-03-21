<script>
  import { supabase } from '$lib/supabase'
  import { page } from '$app/stores'
  import { goto } from '$app/navigation'
  import { onMount } from 'svelte'

  let groupId = $derived($page.params.id)
  let group = $state(null)
  let inviteUrl = $state('')
  let copied = $state(false)
  let loading = $state(true)
  let regenerating = $state(false)
  let qrDataUrl = $state('')
  let isAdmin = $state(false)

  onMount(async () => {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) { goto('/auth/login'); return }

    const { data: groupData } = await supabase
      .from('groups')
      .select('id, name, invite_token, approval_mode')
      .eq('id', groupId)
      .single()

    if (!groupData) { goto(`/groups`); return }
    group = groupData

    // Check membership and role
    const { data: membership } = await supabase
      .from('group_members')
      .select('role')
      .eq('group_id', groupId)
      .eq('user_id', user.id)
      .single()

    // Not a member — redirect
    if (!membership) { goto(`/groups`); return }

    isAdmin = membership.role === 'admin' || membership.role === 'co_admin'
    inviteUrl = `${window.location.origin}/join/${groupData.invite_token}`
    await generateQR(inviteUrl)
    loading = false
  })

  async function generateQR(url) {
    try {
      const QRCode = (await import('https://cdn.jsdelivr.net/npm/qrcode@1.5.3/+esm')).default
      qrDataUrl = await QRCode.toDataURL(url, {
        width: 200,
        margin: 2,
        color: { dark: '#495085', light: '#ffffff' }
      })
    } catch (e) {
      console.error('QR generation failed', e)
    }
  }

  async function copyLink() {
    await navigator.clipboard.writeText(inviteUrl)
    copied = true
    setTimeout(() => copied = false, 2000)
  }

  async function regenerateLink() {
    if (!confirm('Regenerate the invite link? The old link will stop working immediately.')) return
    regenerating = true

    const newToken = crypto.randomUUID().replace(/-/g, '').slice(0, 24)

    const { error } = await supabase
      .from('groups')
      .update({ invite_token: newToken })
      .eq('id', groupId)

    if (!error) {
      group = { ...group, invite_token: newToken }
      inviteUrl = `${window.location.origin}/join/${newToken}`
      await generateQR(inviteUrl)
    }

    regenerating = false
  }
</script>

<div class="max-w-lg mx-auto px-4 py-6">

  {#if loading}
    <div class="flex justify-center py-16">
      <div class="w-5 h-5 rounded-full border-2 border-muted border-t-primary animate-spin"></div>
    </div>

  {:else}
    <h2 class="text-lg font-semibold text-foreground mb-1">Invite members</h2>
    <p class="text-sm text-muted-foreground mb-6">
      Share this link or QR code to invite people to
      <span class="font-medium text-foreground">{group.name}</span>.
    </p>

    <!-- Invite link — all members -->
    <div class="flex flex-col gap-2 mb-6">
      <label class="text-sm font-medium text-foreground">Invite link</label>
      <div class="flex gap-2">
        <div class="flex-1 px-3 py-2.5 rounded-xl border border-input bg-muted text-xs text-muted-foreground truncate font-mono">
          {inviteUrl}
        </div>
        <button
          onclick={copyLink}
          class="px-4 py-2.5 rounded-xl text-sm font-semibold text-white shrink-0 transition-all"
          style="background: hsl(234 26% 41%)"
        >
          {copied ? '✓ Copied' : 'Copy'}
        </button>
      </div>
    </div>

    <!-- QR code — all members -->
    {#if qrDataUrl}
      <div class="flex flex-col items-center gap-3 mb-6">
        <label class="text-sm font-medium text-foreground self-start">QR code</label>
        <div class="p-4 rounded-xl border border-border bg-white">
          <img src={qrDataUrl} alt="Invite QR code" width="200" height="200" />
        </div>
        <a
          href={qrDataUrl}
          download="buzz-me-in-invite.png"
          class="text-sm font-medium underline"
          style="color: hsl(234 26% 41%)"
        >
          Download QR code
        </a>
      </div>
    {/if}

    <!-- Join security — admin only -->
    {#if isAdmin}
      <div class="border-t border-border pt-5 mt-2 mb-6">
        <p class="text-xs font-semibold uppercase tracking-wider text-muted-foreground mb-3">Join security</p>
        <div class="flex items-center gap-2 p-3 rounded-xl" style="background: hsl(234 40% 97%)">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="hsl(234 26% 41%)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            {#if group.approval_mode === 'open'}
              <path d="M18 8h1a4 4 0 0 1 0 8h-1"/><path d="M2 8h16v9a4 4 0 0 1-4 4H6a4 4 0 0 1-4-4V8z"/><line x1="6" y1="1" x2="6" y2="4"/><line x1="10" y1="1" x2="10" y2="4"/><line x1="14" y1="1" x2="14" y2="4"/>
            {:else}
              <rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>
            {/if}
          </svg>
          <p class="text-xs font-medium" style="color: hsl(234 26% 41%)">
            {group.approval_mode === 'open'
              ? 'Open — anyone with the link joins instantly'
              : 'Request to join — you approve new members'}
          </p>
          <a
            href="/groups/{groupId}/settings"
            class="ml-auto text-xs underline shrink-0"
            style="color: hsl(234 26% 41%)"
          >
            Change
          </a>
        </div>
      </div>
    {/if}

    <!-- Revoke link — admin only -->
    {#if isAdmin}
      <div class="border-t border-border pt-5 mt-2">
        <p class="text-sm font-medium text-foreground mb-1">Revoke link</p>
        <p class="text-xs text-muted-foreground mb-3">
          Generate a new link if the current one was shared with the wrong people.
          The old link will stop working immediately.
        </p>
        <button
          onclick={regenerateLink}
          disabled={regenerating}
          class="px-4 py-2 rounded-xl text-sm font-medium border border-destructive text-destructive hover:bg-red-50 transition-colors disabled:opacity-50"
        >
          {regenerating ? 'Regenerating…' : 'Revoke and regenerate link'}
        </button>
      </div>
    {/if}

  {/if}
</div>