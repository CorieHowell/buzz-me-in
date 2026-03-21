<script>
  import { supabase } from '$lib/supabase'
  import { goto } from '$app/navigation'
  import PhotoUploader from '$lib/components/PhotoUploader.svelte'

  let name = $state('')
  let description = $state('')
  let approvalMode = $state('request_to_join')
  let avatarUrl = $state(null)
  let loading = $state(false)
  let error = $state('')

  async function handleCreate() {
    if (!name.trim()) { error = 'Please give your group a name.'; return }

    loading = true
    error = ''

    const { data: { user } } = await supabase.auth.getUser()
    if (!user) { goto('/auth/login'); return }

    // Create the group
    const { data: group, error: groupError } = await supabase
      .from('groups')
      .insert({
        name: name.trim(),
        description: description.trim() || null,
        approval_mode: approvalMode,
        avatar_url: avatarUrl || null,
      })
      .select()
      .single()

    if (groupError) {
      error = groupError.message
      loading = false
      return
    }

    // Add creator as admin
    const { error: memberError } = await supabase
      .from('group_members')
      .insert({
        group_id: group.id,
        user_id: user.id,
        role: 'admin',
      })

    if (memberError) {
      error = memberError.message
      loading = false
      return
    }

    goto(`/groups/${group.id}`)
  }
</script>

<div class="max-w-lg mx-auto px-4 py-6">

  <!-- Header -->
  <div class="flex items-center gap-3 mb-6">
    <button
      onclick={() => goto('/groups')}
      class="p-2 rounded-lg hover:bg-muted transition-colors"
      style="color: hsl(234 12% 52%)"
    >
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        <polyline points="15 18 9 12 15 6"/>
      </svg>
    </button>
    <h1 class="text-xl font-semibold text-foreground">Create a group</h1>
  </div>

  <form onsubmit={(e) => { e.preventDefault(); handleCreate() }} class="flex flex-col gap-5">

    <!-- Group photo -->
    <div class="flex flex-col gap-1.5">
      <label class="text-sm font-medium text-foreground">Group photo <span class="text-muted-foreground font-normal">(optional)</span></label>
      <PhotoUploader bucket="group-avatars" pathPrefix="new" bind:value={avatarUrl} shape="square" size="lg" />
    </div>

    <!-- Group name -->
    <div class="flex flex-col gap-1.5">
      <label for="name" class="text-sm font-medium text-foreground">Group name <span class="text-destructive">*</span></label>
      <input
        id="name"
        type="text"
        bind:value={name}
        placeholder="Thursday Book Club"
        maxlength="60"
        class="w-full px-3 py-2.5 rounded-xl border border-input bg-background text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-ring transition"
      />
      <p class="text-xs text-muted-foreground">{name.length}/60</p>
    </div>

    <!-- Description -->
    <div class="flex flex-col gap-1.5">
      <label for="description" class="text-sm font-medium text-foreground">Description <span class="text-muted-foreground font-normal">(optional)</span></label>
      <textarea
        id="description"
        bind:value={description}
        placeholder="What's this group about? Members will see this on the group preview page."
        rows="3"
        maxlength="200"
        class="w-full px-3 py-2.5 rounded-xl border border-input bg-background text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-ring transition resize-none"
      ></textarea>
      <p class="text-xs text-muted-foreground">{description.length}/200</p>
    </div>

    <!-- Approval mode -->
    <div class="flex flex-col gap-2">
      <label class="text-sm font-medium text-foreground">Who can join?</label>

      <label class="flex items-start gap-3 p-4 rounded-xl border cursor-pointer transition-colors"
        style={approvalMode === 'request_to_join' ? 'border-color: hsl(234 26% 41%); background: hsl(234 40% 97%)' : 'border-color: hsl(234 20% 88%)'}>
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

      <label class="flex items-start gap-3 p-4 rounded-xl border cursor-pointer transition-colors"
        style={approvalMode === 'open' ? 'border-color: hsl(234 26% 41%); background: hsl(234 40% 97%)' : 'border-color: hsl(234 20% 88%)'}>
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
      type="submit"
      disabled={loading}
      class="w-full py-2.5 rounded-xl text-sm font-semibold text-white transition-opacity disabled:opacity-60"
      style="background: hsl(234 26% 41%)"
    >
      {loading ? 'Creating group…' : 'Create group'}
    </button>

  </form>
</div>