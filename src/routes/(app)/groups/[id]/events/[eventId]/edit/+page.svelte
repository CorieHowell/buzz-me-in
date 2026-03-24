<script>
  import { supabase } from '$lib/supabase'
  import { page } from '$app/stores'
  import { goto } from '$app/navigation'
  import { onMount } from 'svelte'

  let groupId = $derived($page.params.id)
  let eventId = $derived($page.params.eventId)

  let title = $state('')
  let description = $state('')
  let location = $state('')
  let eventDate = $state('')
  let eventTime = $state('')
  let coverPhotoUrl = $state(null)
  let coverPhotoUploading = $state(false)
  let coverPhotoError = $state('')
  let coverPhotoInput = $state(null)
  let loading = $state(true)
  let saving = $state(false)
  let error = $state('')

  onMount(async () => {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) { goto('/auth/login'); return }

    const { data: membership } = await supabase
      .from('group_members')
      .select('role')
      .eq('group_id', groupId)
      .eq('user_id', user.id)
      .single()

    if (!membership || (membership.role !== 'admin' && membership.role !== 'co_admin')) {
      goto(`/groups/${groupId}/events/${eventId}`)
      return
    }

    const { data: event } = await supabase
      .from('events')
      .select('*')
      .eq('id', eventId)
      .single()

    if (!event) { goto(`/groups/${groupId}/events`); return }

    title = event.title ?? ''
    description = event.description ?? ''
    location = event.location ?? ''
    coverPhotoUrl = event.cover_photo_url ?? null

    if (event.event_date) {
      const d = new Date(event.event_date)
      eventDate = d.toISOString().split('T')[0]
      eventTime = d.toTimeString().slice(0, 5)
    }

    loading = false
  })

  async function handleCoverPhotoChange(e) {
    const file = e.target.files?.[0]
    if (!file) return
    if (!file.type.startsWith('image/')) { coverPhotoError = 'Please select an image file.'; return }
    if (file.size > 10 * 1024 * 1024) { coverPhotoError = 'Image must be under 10MB.'; return }

    coverPhotoError = ''
    coverPhotoUploading = true

    const ext = file.name.split('.').pop()
    const path = `${groupId}/${Date.now()}.${ext}`

    const { error: uploadError } = await supabase.storage
      .from('event-covers')
      .upload(path, file, { upsert: true })

    if (uploadError) { coverPhotoError = uploadError.message; coverPhotoUploading = false; return }

    const { data: { publicUrl } } = supabase.storage.from('event-covers').getPublicUrl(path)
    coverPhotoUrl = publicUrl
    coverPhotoUploading = false
  }

  function removeCoverPhoto() {
    coverPhotoUrl = null
    if (coverPhotoInput) coverPhotoInput.value = ''
  }

  async function handleSubmit() {
    if (!title.trim()) { error = 'Please enter an event title.'; return }

    saving = true
    error = ''

    let eventDatetime = null
    if (eventDate) {
      const timeStr = eventTime || '18:00'
      eventDatetime = new Date(`${eventDate}T${timeStr}`).toISOString()
    }

    const { error: updateError } = await supabase
      .from('events')
      .update({
        title: title.trim(),
        description: description.trim() || null,
        location: location.trim() || null,
        event_date: eventDatetime,
        cover_photo_url: coverPhotoUrl,
      })
      .eq('id', eventId)

    if (updateError) { error = updateError.message; saving = false; return }

    goto(`/groups/${groupId}/events/${eventId}`)
  }
</script>

<div class="max-w-2xl mx-auto px-4 py-6">

  <a href="/groups/{groupId}/events/{eventId}" class="flex items-center gap-1.5 text-sm mb-5" style="color: hsl(234 12% 52%)">
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      <polyline points="15 18 9 12 15 6"/>
    </svg>
    Back to event
  </a>

  <h2 class="text-lg font-semibold text-foreground mb-6">Edit event</h2>

  {#if loading}
    <div class="flex flex-col gap-4">
      {#each [1,2,3] as _}
        <div class="h-12 bg-muted rounded-xl animate-pulse"></div>
      {/each}
    </div>
  {:else}
    <form onsubmit={(e) => { e.preventDefault(); handleSubmit() }} class="flex flex-col gap-5">

      <!-- Cover photo -->
      <div class="flex flex-col items-center gap-2">
        <input bind:this={coverPhotoInput} type="file" accept="image/*" class="hidden" onchange={handleCoverPhotoChange} />
        <div class="relative">
          {#if coverPhotoUrl}
            <img src={coverPhotoUrl} alt="Cover" class="w-24 h-24 rounded-full object-cover border-2 border-border" />
            <button
              type="button"
              onclick={removeCoverPhoto}
              class="absolute -top-1 -right-1 w-6 h-6 rounded-full bg-destructive flex items-center justify-center border-2 border-background"
              title="Remove photo"
            >
              <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">
                <line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
              </svg>
            </button>
          {:else}
            <button
              type="button"
              onclick={() => coverPhotoInput?.click()}
              disabled={coverPhotoUploading}
              class="w-24 h-24 rounded-full border-2 border-dashed border-border hover:border-muted-foreground/50 bg-muted flex flex-col items-center justify-center gap-1 transition-colors disabled:opacity-50"
            >
              {#if coverPhotoUploading}
                <div class="w-5 h-5 rounded-full border-2 border-muted-foreground border-t-transparent animate-spin"></div>
              {:else}
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="hsl(234 12% 62%)" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                  <path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"/><circle cx="12" cy="13" r="4"/>
                </svg>
              {/if}
            </button>
          {/if}
        </div>
        {#if coverPhotoError}
          <p class="text-xs text-destructive">{coverPhotoError}</p>
        {:else}
          <span class="text-xs text-muted-foreground">Event photo</span>
        {/if}
      </div>

      <!-- Title -->
      <div class="flex flex-col gap-1.5">
        <label for="title" class="text-sm font-medium text-foreground">Event name <span class="text-destructive">*</span></label>
        <input id="title" type="text" bind:value={title} placeholder="April Book Club" maxlength="80"
          class="w-full px-3 py-2.5 rounded-xl border border-input bg-background text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-ring transition" />
      </div>

      <!-- Description -->
      <div class="flex flex-col gap-1.5">
        <label for="desc" class="text-sm font-medium text-foreground">Description <span class="text-muted-foreground font-normal">(optional)</span></label>
        <textarea id="desc" bind:value={description} placeholder="What should members know?" rows="2" maxlength="500"
          class="w-full px-3 py-2.5 rounded-xl border border-input bg-background text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-ring transition resize-none"></textarea>
      </div>

      <!-- Location -->
      <div class="flex flex-col gap-1.5">
        <label for="location" class="text-sm font-medium text-foreground">Location <span class="text-muted-foreground font-normal">(optional)</span></label>
        <input id="location" type="text" bind:value={location} placeholder="123 Main St or Zoom link"
          class="w-full px-3 py-2.5 rounded-xl border border-input bg-background text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-ring transition" />
      </div>

      <!-- Date & time -->
      <div class="grid grid-cols-2 gap-3">
        <div class="flex flex-col gap-1.5">
          <label for="date" class="text-sm font-medium text-foreground">Date</label>
          <input id="date" type="date" bind:value={eventDate}
            class="w-full px-3 py-2.5 rounded-xl border border-input bg-background text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-ring transition" />
        </div>
        <div class="flex flex-col gap-1.5">
          <label for="time" class="text-sm font-medium text-foreground">Time</label>
          <input id="time" type="time" bind:value={eventTime}
            class="w-full px-3 py-2.5 rounded-xl border border-input bg-background text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-ring transition" />
        </div>
      </div>

      {#if error}
        <p class="text-sm text-destructive">{error}</p>
      {/if}

      <div class="flex gap-3">
        <button type="submit" disabled={saving}
          class="flex-1 py-2.5 rounded-xl text-sm font-semibold text-white transition-opacity disabled:opacity-60"
          style="background: hsl(234 26% 41%)">
          {saving ? 'Saving…' : 'Save changes'}
        </button>
        <a href="/groups/{groupId}/events/{eventId}"
          class="px-4 py-2.5 rounded-xl text-sm font-medium text-muted-foreground hover:bg-muted transition-colors">
          Cancel
        </a>
      </div>

    </form>
  {/if}

</div>
