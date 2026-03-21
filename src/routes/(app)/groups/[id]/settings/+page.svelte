<script>
  import { supabase } from '$lib/supabase'
  import { page } from '$app/stores'
  import { goto } from '$app/navigation'
  import { onMount } from 'svelte'
  import PhotoUploader from '$lib/components/PhotoUploader.svelte'

  let groupId = $derived($page.params.id)
  let loading = $state(true)
  let saving = $state(false)
  let saved = $state(false)
  let error = $state('')
  let deleting = $state(false)

  let name = $state('')
  let description = $state('')
  let approvalMode = $state('request_to_join')
  let avatarUrl = $state(null)
  let currentUserRole = $state(null)

  onMount(async () => {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) { goto('/auth/login'); return }

    const { data: membership } = await supabase
      .from('group_members')
      .select('role')
      .eq('group_id', groupId)
      .eq('user_id', user.id)
      .single()

    currentUserRole = membership?.role ?? null

    if (currentUserRole !== 'admin' && currentUserRole !== 'co_admin') {
      goto(`/groups/${groupId}`)
      return
    }

    const { data: group } = await supabase
      .from('groups')
      .select('name, description, approval_mode, avatar_url')
      .eq('id', groupId)
      .single()

    name = group?.name ?? ''
    description = group?.description ?? ''
    approvalMode = group?.approval_mode ?? 'request_to_join'
    avatarUrl = group?.avatar_url ?? null
    loading = false
  })

  async function saveSettings() {
    if (!name.trim()) { error = 'Group name is required.'; return }
    saving = true
    error = ''

    const { error: updateError } = await supabase
      .from('groups')
      .update({
        name: name.trim(),
        description: description.trim() || null,
        approval_mode: approvalMode,
        avatar_url: avatarUrl || null,
      })
      .eq('id', groupId)

    if (updateError) { error = updateError.message; saving = false; return }
    saved = true
    setTimeout(() => saved = false, 2000)
    saving = false
  }

  async function deleteGroup() {
    if (!confirm('Are you sure you want to delete this group? This cannot be undone.')) return
    if (!confirm('All posts, events, and members will be permanently deleted. Continue?')) return

    deleting = true
    await supabase.from('groups').delete().eq('id', groupId)
    goto('/groups')
  }

  let isAdmin = $derived(currentUserRole === 'admin')
</script>

<div class="max-w-lg mx-auto px-4 py-6">

  {#if loading}
    <div class="flex flex-col gap-4 animate-pulse">
      <div class="h-5 bg-muted rounded w-1/3"></div>
      <div class="h-10 bg-muted rounded"></div>
      <div class="h-20 bg-muted rounded"></div>
    </div>

  {:else}
    <h2 class="text-lg font-semibold text-foreground mb-6">Group settings</h2>

    <div class="flex flex-col gap-5">

      <!-- Group photo -->
      <div class="flex flex-col gap-1.5">
        <label class="text-sm font-medium text-foreground">Group photo</label>
        <PhotoUploader bucket="group-avatars" pathPrefix={groupId} bind:value={avatarUrl} shape="square" size="lg" />
      </div>

      <!-- Name -->
      <div class="flex flex-col gap-1.5">
        <label class="text-sm font-medium text-foreground">Group name <span class="text-destructive">*</span></label>
        <input
          type="text"
          bind:value={name}
          maxlength="60"
          class="w-full px-3 py-2.5 rounded-xl border border-input bg-background text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-ring transition"
        />
        <p class="text-xs text-muted-foreground">{name.length}/60</p>
      </div>

      <!-- Description -->
      <div class="flex flex-col gap-1.5">
        <label class="text-sm font-medium text-foreground">Description <span class="text-muted-foreground font-normal">(optional)</span></label>
        <textarea
          bind:value={description}
          placeholder="What's this group about?"
          rows="3"
          maxlength="200"
          class="w-full px-3 py-2.5 rounded-xl border border-input bg-background text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-ring transition resize-none"
        ></textarea>
        <p class="text-xs text-muted-foreground">{description.length}/200</p>
      </div>

      <!-- Approval mode -->
      <div class="flex flex-col gap-2">
        <label class="text-sm font-medium text-foreground">Who can join?</label>

        <label
          class="flex items-start gap-3 p-4 rounded-xl border cursor-pointer transition-colors"
          style={approvalMode === 'request_to_join'
            ? 'border-color: hsl(234 26% 41%); background: hsl(234 40% 97%)'
            : 'border-color: hsl(234 20% 88%)'}
        >
          <input
            type="radio"
            bind:group={approvalMode}
            value="request_to_join"
            class="mt-0.5 shrink-0 accent-[hsl(234,26%,41%)]"
          />
          <div>
            <p class="text-sm font-medium text-foreground">Request to join</p>
            <p class="text-xs text-muted-foreground mt-0.5">Anyone with the link can request — you approve or decline.</p>
          </div>
        </label>

        <label
          class="flex items-start gap-3 p-4 rounded-xl border cursor-pointer transition-colors"
          style={approvalMode === 'open'
            ? 'border-color: hsl(234 26% 41%); background: hsl(234 40% 97%)'
            : 'border-color: hsl(234 20% 88%)'}
        >
          <input
            type="radio"
            bind:group={approvalMode}
            value="open"
            class="mt-0.5 shrink-0 accent-[hsl(234,26%,41%)]"
          />
          <div>
            <p class="text-sm font-medium text-foreground">Open</p>
            <p class="text-xs text-muted-foreground mt-0.5">Anyone with the link joins instantly — no approval needed.</p>
          </div>
        </label>
      </div>

      {#if error}
        <p class="text-sm text-destructive">{error}</p>
      {/if}

      <button
        onclick={saveSettings}
        disabled={saving}
        class="w-full py-2.5 rounded-xl text-sm font-semibold text-white transition-opacity disabled:opacity-60"
        style="background: hsl(234 26% 41%)"
      >
        {saving ? 'Saving…' : saved ? '✓ Saved' : 'Save settings'}
      </button>

    </div>

    <!-- Danger zone — admin only -->
    {#if isAdmin}
      <div class="mt-10 pt-6 border-t border-border">
        <p class="text-sm font-semibold text-foreground mb-1">Danger zone</p>
        <p class="text-xs text-muted-foreground mb-4">Deleting a group permanently removes all posts, events, members, and data. This cannot be undone.</p>
        <button
          onclick={deleteGroup}
          disabled={deleting}
          class="px-4 py-2 rounded-xl text-sm font-medium border border-destructive text-destructive hover:bg-red-50 transition-colors disabled:opacity-50"
        >
          {deleting ? 'Deleting…' : 'Delete group'}
        </button>
      </div>
    {/if}

  {/if}
</div>