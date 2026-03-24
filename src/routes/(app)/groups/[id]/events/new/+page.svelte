<script>
  import { supabase } from '$lib/supabase'
  import { page } from '$app/stores'
  import { goto } from '$app/navigation'
  import { onMount } from 'svelte'

  let groupId = $derived($page.params.id)

  // Navigation
  let currentStep = $state(1)
  let draftId = $state(null)

  // Step 1 — Basics
  let title = $state('')
  let description = $state('')
  let hostUserId = $state('')
  let coverPhotoUrl = $state(null)
  let coverPhotoUploading = $state(false)
  let coverPhotoError = $state('')
  let coverPhotoInput = $state(null)

  // Step 2 — Date & Time
  let datetimeMode = $state('set')
  let eventDate = $state('')
  let eventTime = $state('')
  let datetimeCandidates = $state(['', ''])
  let datetimeVotingDeadline = $state('')
  let datetimeSuggestionsDeadline = $state('')

  // Step 3 — Location
  let locationMode = $state('set')
  let locationText = $state('')
  let locationUrl = $state('')
  let locationCandidates = $state(['', ''])
  let locationVotingDeadline = $state('')
  let locationSuggestionsDeadline = $state('')

  // Step 4 — Bring List
  let bringListMode = $state('prefill')
  let bringListItems = $state([{ name: '', quantity: 1 }])

  // Step 5 — Options
  let isRecurring = $state(false)
  let cadence = $state('weekly')
  let customIntervalDays = $state(14)
  let hasCapacity = $state(false)
  let capacity = $state(20)

  // Meta
  let loading = $state(false)
  let saving = $state(false)
  let error = $state('')
  let members = $state([])
  let currentUserId = $state(null)
  let initialized = $state(false)

  let urlWarning = $derived(
    locationMode === 'virtual' && locationUrl && !locationUrl.match(/^https?:\/\//)
      ? 'Link should start with http:// or https://'
      : ''
  )

  onMount(async () => {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) { goto('/auth/login'); return }
    currentUserId = user.id
    hostUserId = user.id

    const { data: membership } = await supabase
      .from('group_members')
      .select('role')
      .eq('group_id', groupId)
      .eq('user_id', user.id)
      .single()

    if (!membership || (membership.role !== 'admin' && membership.role !== 'co_admin')) {
      goto(`/groups/${groupId}/events`)
      return
    }

    const { data: memberData } = await supabase
      .from('group_members')
      .select('user_id, users(display_name)')
      .eq('group_id', groupId)

    members = memberData ?? []

    // Load draft if ?draft= param exists
    const draftParam = $page.url.searchParams.get('draft')
    if (draftParam) {
      await loadDraft(draftParam)
    }

    initialized = true
  })

  async function loadDraft(id) {
    draftId = id

    const [eventRes, dtOptsRes, locOptsRes, bringRes] = await Promise.all([
      supabase.from('events').select('*, event_series(*)').eq('id', id).single(),
      supabase.from('event_datetime_options').select('*').eq('event_id', id).order('created_at'),
      supabase.from('event_location_options').select('*').eq('event_id', id).order('created_at'),
      supabase.from('bring_list_items').select('*').eq('event_id', id).order('created_at'),
    ])

    const ev = eventRes.data
    if (!ev) return

    title = ev.title ?? ''
    description = ev.description ?? ''
    hostUserId = ev.host_user_id ?? currentUserId
    coverPhotoUrl = ev.cover_photo_url ?? null

    // Date & Time
    datetimeMode = ev.datetime_mode ?? 'set'
    if (ev.datetime_mode === 'set' && ev.event_date) {
      const d = new Date(ev.event_date)
      eventDate = d.toISOString().split('T')[0]
      eventTime = d.toTimeString().slice(0, 5)
    }
    if (dtOptsRes.data?.length) {
      datetimeCandidates = dtOptsRes.data.map(o => {
        const d = new Date(o.candidate_datetime)
        return d.toISOString().slice(0, 16)
      })
      datetimeVotingDeadline = dtOptsRes.data[0]?.voting_deadline
        ? new Date(dtOptsRes.data[0].voting_deadline).toISOString().slice(0, 10)
        : ''
      datetimeSuggestionsDeadline = dtOptsRes.data[0]?.suggestions_deadline
        ? new Date(dtOptsRes.data[0].suggestions_deadline).toISOString().slice(0, 10)
        : ''
    }

    // Location
    locationMode = ev.location_mode ?? 'set'
    if (ev.location_mode === 'set' && ev.location) {
      locationText = ev.location
    } else if (ev.location_mode === 'virtual' && ev.location) {
      locationUrl = ev.location
    }
    if (locOptsRes.data?.length) {
      locationCandidates = locOptsRes.data.map(o => o.location_text)
      locationVotingDeadline = locOptsRes.data[0]?.voting_deadline
        ? new Date(locOptsRes.data[0].voting_deadline).toISOString().slice(0, 10)
        : ''
      locationSuggestionsDeadline = locOptsRes.data[0]?.suggestions_deadline
        ? new Date(locOptsRes.data[0].suggestions_deadline).toISOString().slice(0, 10)
        : ''
    }

    // Bring list
    bringListMode = ev.bring_list_mode ?? 'prefill'
    if (bringRes.data?.length) {
      bringListItems = bringRes.data.map(i => ({ name: i.name, quantity: i.quantity }))
    }

    // Options
    if (ev.capacity) {
      hasCapacity = true
      capacity = ev.capacity
    }
    if (ev.event_series) {
      isRecurring = true
      cadence = ev.event_series.cadence
      customIntervalDays = ev.event_series.custom_interval_days ?? 14
    }
  }

  // -- Cover photo --
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

  // -- Candidate helpers --
  function addDatetimeCandidate() {
    if (datetimeCandidates.length < 5) datetimeCandidates = [...datetimeCandidates, '']
  }
  function removeDatetimeCandidate(i) {
    datetimeCandidates = datetimeCandidates.filter((_, idx) => idx !== i)
  }
  function addLocationCandidate() {
    if (locationCandidates.length < 5) locationCandidates = [...locationCandidates, '']
  }
  function removeLocationCandidate(i) {
    locationCandidates = locationCandidates.filter((_, idx) => idx !== i)
  }

  // -- Bring list helpers --
  function addBringListItem() {
    bringListItems = [...bringListItems, { name: '', quantity: 1 }]
  }
  function removeBringListItem(i) {
    bringListItems = bringListItems.filter((_, idx) => idx !== i)
  }

  // -- Navigation --
  function nextStep() {
    if (currentStep === 1 && !title.trim()) {
      error = 'Please enter an event name.'
      return
    }
    error = ''
    if (currentStep < 5) currentStep++
  }

  function prevStep() {
    error = ''
    if (currentStep > 1) currentStep--
  }

  // -- Determine status based on form state --
  function resolveStatus(isDraft) {
    if (isDraft) return 'draft'
    if (datetimeMode === 'poll_host' || datetimeMode === 'poll_open') return 'pending_date'
    return 'confirmed'
  }

  // -- Resolve location value --
  function resolveLocation() {
    if (locationMode === 'set') return locationText.trim() || null
    if (locationMode === 'virtual') return locationUrl.trim() || null
    return null
  }

  // -- Resolve event_date --
  function resolveEventDate() {
    if (datetimeMode === 'set' && eventDate) {
      const timeStr = eventTime || '18:00'
      return new Date(`${eventDate}T${timeStr}`).toISOString()
    }
    return null
  }

  // -- Build event row data --
  function buildEventData(isDraft) {
    return {
      group_id: groupId,
      host_user_id: hostUserId || currentUserId,
      title: title.trim(),
      description: description.trim() || null,
      location: resolveLocation(),
      event_date: resolveEventDate(),
      cover_photo_url: coverPhotoUrl,
      status: resolveStatus(isDraft),
      datetime_mode: datetimeMode,
      location_mode: locationMode,
      capacity: hasCapacity ? capacity : null,
      bring_list_mode: bringListMode,
      series_id: null, // set after series insert if recurring
    }
  }

  // -- Save related rows (datetime options, location options, bring list items, series) --
  async function saveRelatedRows(eventId) {
    // Datetime options
    if (datetimeMode === 'poll_host' || datetimeMode === 'poll_open') {
      const validDates = datetimeCandidates.filter(d => d)
      if (validDates.length) {
        // Clear existing options for this event
        await supabase.from('event_datetime_options').delete().eq('event_id', eventId)
        await supabase.from('event_datetime_options').insert(
          validDates.map(d => ({
            event_id: eventId,
            candidate_datetime: new Date(d).toISOString(),
            voting_deadline: datetimeVotingDeadline ? new Date(datetimeVotingDeadline).toISOString() : null,
            suggestions_deadline: datetimeMode === 'poll_open' && datetimeSuggestionsDeadline
              ? new Date(datetimeSuggestionsDeadline).toISOString()
              : null,
          }))
        )
      }
    }

    // Location options
    if (locationMode === 'poll_host' || locationMode === 'poll_open') {
      const validLocs = locationCandidates.filter(l => l.trim())
      if (validLocs.length) {
        await supabase.from('event_location_options').delete().eq('event_id', eventId)
        await supabase.from('event_location_options').insert(
          validLocs.map(l => ({
            event_id: eventId,
            location_text: l.trim(),
            voting_deadline: locationVotingDeadline ? new Date(locationVotingDeadline).toISOString() : null,
            suggestions_deadline: locationMode === 'poll_open' && locationSuggestionsDeadline
              ? new Date(locationSuggestionsDeadline).toISOString()
              : null,
          }))
        )
      }
    }

    // Bring list items
    if (bringListMode === 'prefill') {
      const validItems = bringListItems.filter(i => i.name.trim())
      if (validItems.length) {
        await supabase.from('bring_list_items').delete().eq('event_id', eventId)
        await supabase.from('bring_list_items').insert(
          validItems.map(i => ({
            event_id: eventId,
            name: i.name.trim(),
            quantity: i.quantity,
            added_by: currentUserId,
          }))
        )
      }
    }

    // Recurring series
    if (isRecurring) {
      const { data: series } = await supabase.from('event_series').insert({
        cadence,
        custom_interval_days: cadence === 'custom' ? customIntervalDays : null,
        created_by: currentUserId,
      }).select().single()

      if (series) {
        await supabase.from('events').update({ series_id: series.id }).eq('id', eventId)
      }
    }
  }

  // -- Save as draft --
  async function saveDraft() {
    if (!title.trim()) { error = 'Please enter an event name to save a draft.'; return }

    saving = true
    error = ''

    const data = buildEventData(true)

    let eventId = draftId
    if (draftId) {
      const { error: updateErr } = await supabase
        .from('events')
        .update(data)
        .eq('id', draftId)
      if (updateErr) { error = updateErr.message; saving = false; return }
    } else {
      const { data: event, error: insertErr } = await supabase
        .from('events')
        .insert(data)
        .select()
        .single()
      if (insertErr) { error = insertErr.message; saving = false; return }
      eventId = event.id
      draftId = event.id
    }

    await saveRelatedRows(eventId)

    saving = false
    goto(`/groups/${groupId}/events/new?draft=${eventId}`, { replaceState: true })
  }

  // -- Publish --
  async function publishEvent() {
    if (!title.trim()) { error = 'Please enter an event name.'; return }

    loading = true
    error = ''

    const data = buildEventData(false)

    let eventId = draftId
    if (draftId) {
      const { error: updateErr } = await supabase
        .from('events')
        .update(data)
        .eq('id', draftId)
      if (updateErr) { error = updateErr.message; loading = false; return }
    } else {
      const { data: event, error: insertErr } = await supabase
        .from('events')
        .insert(data)
        .select()
        .single()
      if (insertErr) { error = insertErr.message; loading = false; return }
      eventId = event.id
    }

    await saveRelatedRows(eventId)

    // Notify all group members (except publisher)
    const { data: groupMembers } = await supabase
      .from('group_members')
      .select('user_id')
      .eq('group_id', groupId)

    const otherMembers = (groupMembers ?? []).filter(m => m.user_id !== currentUserId)
    if (otherMembers.length) {
      await supabase.from('notifications').insert(
        otherMembers.map(m => ({
          user_id: m.user_id,
          type: 'new_event',
          body: `New event: ${title.trim()}`,
          link: `/groups/${groupId}/events/${eventId}`,
          is_read: false,
        }))
      )
    }

    // Notify host if different from publisher
    if (hostUserId && hostUserId !== currentUserId) {
      await supabase.from('notifications').insert({
        user_id: hostUserId,
        type: 'host_assigned',
        body: `You're hosting ${title.trim()}`,
        link: `/groups/${groupId}/events/${eventId}`,
        is_read: false,
      })
    }

    loading = false
    goto(`/groups/${groupId}/events/${eventId}`)
  }

  let stepLabel = $derived(
    currentStep === 1 ? 'The Basics'
    : currentStep === 2 ? 'Date & Time'
    : currentStep === 3 ? 'Location'
    : currentStep === 4 ? 'Bring List'
    : 'Event Options'
  )
</script>

<div class="max-w-2xl mx-auto px-4 py-6">

  <!-- Header -->
  <div class="flex items-center justify-between mb-6">
    <div class="flex items-center gap-3">
      <button
        onclick={() => currentStep > 1 ? prevStep() : goto(`/groups/${groupId}/events`)}
        class="p-2 rounded-lg hover:bg-muted transition-colors"
        style="color: hsl(234 12% 52%)"
      >
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <polyline points="15 18 9 12 15 6"/>
        </svg>
      </button>
      <div>
        <p class="text-xs text-muted-foreground">Step {currentStep} of 5</p>
        <h2 class="text-base font-semibold text-foreground">{stepLabel}</h2>
      </div>
    </div>

    <button
      onclick={saveDraft}
      disabled={saving || !title.trim()}
      class="px-3 py-1.5 rounded-lg text-xs font-semibold transition-colors disabled:opacity-40"
      style="color: hsl(234 26% 41%); background: hsl(234 40% 97%)"
    >
      {saving ? 'Saving…' : 'Save as draft'}
    </button>
  </div>

  <!-- Step indicator dots -->
  <div class="flex gap-1.5 mb-6">
    {#each [1,2,3,4,5] as step}
      <div
        class="h-1 flex-1 rounded-full transition-colors"
        style="background: {step <= currentStep ? 'hsl(234 26% 41%)' : 'hsl(234 20% 88%)'}"
      ></div>
    {/each}
  </div>

  <!-- ============ STEP 1: The Basics ============ -->
  {#if currentStep === 1}
    <div class="flex flex-col gap-5">

      <!-- Cover photo -->
      <div class="flex flex-col gap-1.5">
        <label class="text-sm font-medium text-foreground">Cover photo <span class="text-muted-foreground font-normal">(optional)</span></label>
        <input bind:this={coverPhotoInput} type="file" accept="image/*" class="hidden" onchange={handleCoverPhotoChange} />
        {#if coverPhotoUrl}
          <div class="relative w-20 h-20">
            <img src={coverPhotoUrl} alt="Cover" class="w-20 h-20 rounded-full object-cover" />
            <button
              type="button"
              onclick={removeCoverPhoto}
              class="absolute top-0 right-0 p-1 rounded-full bg-black/50 hover:bg-black/70 transition-colors"
            >
              <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                <line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
              </svg>
            </button>
          </div>
        {:else}
          <button
            type="button"
            onclick={() => coverPhotoInput?.click()}
            disabled={coverPhotoUploading}
            class="w-20 h-20 flex flex-col items-center justify-center gap-1 rounded-full border-2 border-dashed border-border hover:border-muted-foreground/40 transition-colors bg-background disabled:opacity-50"
          >
            {#if coverPhotoUploading}
              <div class="w-5 h-5 rounded-full border-2 border-muted-foreground border-t-transparent animate-spin"></div>
              <span class="text-xs text-muted-foreground">Uploading…</span>
            {:else}
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="hsl(234 12% 62%)" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                <rect x="3" y="3" width="18" height="18" rx="2" ry="2"/>
                <circle cx="8.5" cy="8.5" r="1.5"/>
                <polyline points="21 15 16 10 5 21"/>
              </svg>
              <span class="text-xs text-muted-foreground">Click to add a cover photo</span>
            {/if}
          </button>
        {/if}
        {#if coverPhotoError}
          <p class="text-xs text-destructive">{coverPhotoError}</p>
        {/if}
      </div>

      <!-- Event name -->
      <div class="flex flex-col gap-1.5">
        <label for="title" class="text-sm font-medium text-foreground">Event name <span class="text-destructive">*</span></label>
        <input id="title" type="text" bind:value={title} placeholder="April Book Club" maxlength="80"
          class="w-full px-3 py-2.5 rounded-xl border border-input bg-background text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-ring transition" />
        <p class="text-xs text-muted-foreground">{title.length}/80</p>
      </div>

      <!-- Description -->
      <div class="flex flex-col gap-1.5">
        <label for="desc" class="text-sm font-medium text-foreground">Description <span class="text-muted-foreground font-normal">(optional)</span></label>
        <textarea id="desc" bind:value={description} placeholder="What should members know?" rows="3" maxlength="500"
          class="w-full px-3 py-2.5 rounded-xl border border-input bg-background text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-ring transition resize-none"></textarea>
        <p class="text-xs text-muted-foreground">{description.length}/500</p>
      </div>

      <!-- Host picker -->
      {#if members.length > 1}
        <div class="flex flex-col gap-1.5">
          <label for="host" class="text-sm font-medium text-foreground">Host</label>
          <select id="host" bind:value={hostUserId}
            class="w-full px-3 py-2.5 rounded-xl border border-input bg-background text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-ring transition">
            {#each members as m}
              <option value={m.user_id}>{m.users?.display_name}</option>
            {/each}
          </select>
        </div>
      {/if}
    </div>

  <!-- ============ STEP 2: Date & Time ============ -->
  {:else if currentStep === 2}
    <div class="flex flex-col gap-3">

      <!-- Card 1: Set a date -->
      <label class="flex flex-col gap-3 p-4 rounded-xl border cursor-pointer transition-colors"
        style={datetimeMode === 'set' ? 'border-color: hsl(234 26% 41%); background: hsl(234 40% 97%)' : 'border-color: hsl(234 20% 88%)'}>
        <div class="flex items-start gap-3">
          <input type="radio" bind:group={datetimeMode} value="set"
            class="mt-0.5 shrink-0 accent-[hsl(234,26%,41%)]" />
          <div>
            <p class="text-sm font-medium text-foreground">Set a date</p>
            <p class="text-xs text-muted-foreground">Pick a specific date and time.</p>
          </div>
        </div>
        {#if datetimeMode === 'set'}
          <div class="grid grid-cols-2 gap-3 pl-7">
            <div class="flex flex-col gap-1">
              <label for="date" class="text-xs font-medium text-muted-foreground">Date</label>
              <input id="date" type="date" bind:value={eventDate}
                class="w-full px-3 py-2 rounded-lg border border-input bg-background text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-ring transition" />
            </div>
            <div class="flex flex-col gap-1">
              <label for="time" class="text-xs font-medium text-muted-foreground">Time <span class="text-muted-foreground font-normal">(opt.)</span></label>
              <input id="time" type="time" bind:value={eventTime}
                class="w-full px-3 py-2 rounded-lg border border-input bg-background text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-ring transition" />
            </div>
          </div>
        {/if}
      </label>

      <!-- Card 2: Let the group vote -->
      <label class="flex flex-col gap-3 p-4 rounded-xl border cursor-pointer transition-colors"
        style={datetimeMode === 'poll_host' ? 'border-color: hsl(234 26% 41%); background: hsl(234 40% 97%)' : 'border-color: hsl(234 20% 88%)'}>
        <div class="flex items-start gap-3">
          <input type="radio" bind:group={datetimeMode} value="poll_host"
            class="mt-0.5 shrink-0 accent-[hsl(234,26%,41%)]" />
          <div>
            <p class="text-sm font-medium text-foreground">Let the group vote</p>
            <p class="text-xs text-muted-foreground">You provide date options, members vote.</p>
          </div>
        </div>
        {#if datetimeMode === 'poll_host'}
          <div class="flex flex-col gap-2 pl-7">
            <p class="text-xs font-medium text-muted-foreground">Candidate dates (2–5)</p>
            {#each datetimeCandidates as _, i}
              <div class="flex gap-2 items-center">
                <input type="datetime-local" bind:value={datetimeCandidates[i]}
                  class="flex-1 px-3 py-2 rounded-lg border border-input bg-background text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-ring transition" />
                {#if datetimeCandidates.length > 2}
                  <button type="button" onclick={() => removeDatetimeCandidate(i)}
                    class="p-2 rounded-lg hover:bg-muted transition-colors" style="color: hsl(234 12% 52%)">
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                      <line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
                    </svg>
                  </button>
                {/if}
              </div>
            {/each}
            {#if datetimeCandidates.length < 5}
              <button type="button" onclick={addDatetimeCandidate}
                class="text-sm font-medium text-left mt-1" style="color: hsl(234 26% 41%)">
                + Add another option
              </button>
            {/if}

            <div class="flex flex-col gap-1 mt-2">
              <label class="text-xs font-medium text-muted-foreground">Voting deadline</label>
              <input type="date" bind:value={datetimeVotingDeadline}
                class="w-full px-3 py-2 rounded-lg border border-input bg-background text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-ring transition" />
            </div>
          </div>
        {/if}
      </label>

      <!-- Card 3: Ask for suggestions -->
      <label class="flex flex-col gap-3 p-4 rounded-xl border cursor-pointer transition-colors"
        style={datetimeMode === 'poll_open' ? 'border-color: hsl(234 26% 41%); background: hsl(234 40% 97%)' : 'border-color: hsl(234 20% 88%)'}>
        <div class="flex items-start gap-3">
          <input type="radio" bind:group={datetimeMode} value="poll_open"
            class="mt-0.5 shrink-0 accent-[hsl(234,26%,41%)]" />
          <div>
            <p class="text-sm font-medium text-foreground">Ask the group for suggestions</p>
            <p class="text-xs text-muted-foreground">Members suggest dates, then everyone votes.</p>
          </div>
        </div>
        {#if datetimeMode === 'poll_open'}
          <div class="flex flex-col gap-3 pl-7">
            <div class="flex flex-col gap-1">
              <label class="text-xs font-medium text-muted-foreground">Suggestions close</label>
              <input type="date" bind:value={datetimeSuggestionsDeadline}
                class="w-full px-3 py-2 rounded-lg border border-input bg-background text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-ring transition" />
            </div>
            <div class="flex flex-col gap-1">
              <label class="text-xs font-medium text-muted-foreground">Voting deadline</label>
              <input type="date" bind:value={datetimeVotingDeadline}
                class="w-full px-3 py-2 rounded-lg border border-input bg-background text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-ring transition" />
            </div>
          </div>
        {/if}
      </label>

      <!-- Skip -->
      <button
        type="button"
        onclick={() => { datetimeMode = null; nextStep() }}
        class="text-sm font-medium mt-1"
        style="color: hsl(234 12% 52%)"
      >
        Skip for now
      </button>
    </div>

  <!-- ============ STEP 3: Location ============ -->
  {:else if currentStep === 3}
    <div class="flex flex-col gap-3">

      <!-- Card 1: Set a location -->
      <label class="flex flex-col gap-3 p-4 rounded-xl border cursor-pointer transition-colors"
        style={locationMode === 'set' ? 'border-color: hsl(234 26% 41%); background: hsl(234 40% 97%)' : 'border-color: hsl(234 20% 88%)'}>
        <div class="flex items-start gap-3">
          <input type="radio" bind:group={locationMode} value="set"
            class="mt-0.5 shrink-0 accent-[hsl(234,26%,41%)]" />
          <div>
            <p class="text-sm font-medium text-foreground">Set a location</p>
            <p class="text-xs text-muted-foreground">Enter an address or venue name.</p>
          </div>
        </div>
        {#if locationMode === 'set'}
          <div class="pl-7">
            <input type="text" bind:value={locationText} placeholder="123 Main St or venue name"
              class="w-full px-3 py-2 rounded-lg border border-input bg-background text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-ring transition" />
          </div>
        {/if}
      </label>

      <!-- Card 2: Virtual / link -->
      <label class="flex flex-col gap-3 p-4 rounded-xl border cursor-pointer transition-colors"
        style={locationMode === 'virtual' ? 'border-color: hsl(234 26% 41%); background: hsl(234 40% 97%)' : 'border-color: hsl(234 20% 88%)'}>
        <div class="flex items-start gap-3">
          <input type="radio" bind:group={locationMode} value="virtual"
            class="mt-0.5 shrink-0 accent-[hsl(234,26%,41%)]" />
          <div>
            <p class="text-sm font-medium text-foreground">Virtual / link</p>
            <p class="text-xs text-muted-foreground">Zoom, Google Meet, or other link.</p>
          </div>
        </div>
        {#if locationMode === 'virtual'}
          <div class="pl-7 flex flex-col gap-1">
            <input type="url" bind:value={locationUrl} placeholder="https://zoom.us/j/..."
              class="w-full px-3 py-2 rounded-lg border border-input bg-background text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-ring transition" />
            {#if urlWarning}
              <p class="text-xs" style="color: hsl(35 80% 40%)">{urlWarning}</p>
            {/if}
          </div>
        {/if}
      </label>

      <!-- Card 3: Let the group vote -->
      <label class="flex flex-col gap-3 p-4 rounded-xl border cursor-pointer transition-colors"
        style={locationMode === 'poll_host' ? 'border-color: hsl(234 26% 41%); background: hsl(234 40% 97%)' : 'border-color: hsl(234 20% 88%)'}>
        <div class="flex items-start gap-3">
          <input type="radio" bind:group={locationMode} value="poll_host"
            class="mt-0.5 shrink-0 accent-[hsl(234,26%,41%)]" />
          <div>
            <p class="text-sm font-medium text-foreground">Let the group vote</p>
            <p class="text-xs text-muted-foreground">You provide location options, members vote.</p>
          </div>
        </div>
        {#if locationMode === 'poll_host'}
          <div class="flex flex-col gap-2 pl-7">
            <p class="text-xs font-medium text-muted-foreground">Location options (2–5)</p>
            {#each locationCandidates as _, i}
              <div class="flex gap-2 items-center">
                <input type="text" bind:value={locationCandidates[i]} placeholder="Address or venue"
                  class="flex-1 px-3 py-2 rounded-lg border border-input bg-background text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-ring transition" />
                {#if locationCandidates.length > 2}
                  <button type="button" onclick={() => removeLocationCandidate(i)}
                    class="p-2 rounded-lg hover:bg-muted transition-colors" style="color: hsl(234 12% 52%)">
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                      <line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
                    </svg>
                  </button>
                {/if}
              </div>
            {/each}
            {#if locationCandidates.length < 5}
              <button type="button" onclick={addLocationCandidate}
                class="text-sm font-medium text-left mt-1" style="color: hsl(234 26% 41%)">
                + Add another option
              </button>
            {/if}

            <div class="flex flex-col gap-1 mt-2">
              <label class="text-xs font-medium text-muted-foreground">Voting deadline</label>
              <input type="date" bind:value={locationVotingDeadline}
                class="w-full px-3 py-2 rounded-lg border border-input bg-background text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-ring transition" />
            </div>
          </div>
        {/if}
      </label>

      <!-- Card 4: Ask for suggestions -->
      <label class="flex flex-col gap-3 p-4 rounded-xl border cursor-pointer transition-colors"
        style={locationMode === 'poll_open' ? 'border-color: hsl(234 26% 41%); background: hsl(234 40% 97%)' : 'border-color: hsl(234 20% 88%)'}>
        <div class="flex items-start gap-3">
          <input type="radio" bind:group={locationMode} value="poll_open"
            class="mt-0.5 shrink-0 accent-[hsl(234,26%,41%)]" />
          <div>
            <p class="text-sm font-medium text-foreground">Ask the group for suggestions</p>
            <p class="text-xs text-muted-foreground">Members suggest locations, then everyone votes.</p>
          </div>
        </div>
        {#if locationMode === 'poll_open'}
          <div class="flex flex-col gap-3 pl-7">
            <div class="flex flex-col gap-1">
              <label class="text-xs font-medium text-muted-foreground">Suggestions close</label>
              <input type="date" bind:value={locationSuggestionsDeadline}
                class="w-full px-3 py-2 rounded-lg border border-input bg-background text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-ring transition" />
            </div>
            <div class="flex flex-col gap-1">
              <label class="text-xs font-medium text-muted-foreground">Voting deadline</label>
              <input type="date" bind:value={locationVotingDeadline}
                class="w-full px-3 py-2 rounded-lg border border-input bg-background text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-ring transition" />
            </div>
          </div>
        {/if}
      </label>

      <!-- Skip -->
      <button
        type="button"
        onclick={() => { locationMode = null; nextStep() }}
        class="text-sm font-medium mt-1"
        style="color: hsl(234 12% 52%)"
      >
        Skip for now
      </button>
    </div>

  <!-- ============ STEP 4: Bring List ============ -->
  {:else if currentStep === 4}
    <div class="flex flex-col gap-3">

      <!-- Card 1: Pre-fill now -->
      <label class="flex flex-col gap-3 p-4 rounded-xl border cursor-pointer transition-colors"
        style={bringListMode === 'prefill' ? 'border-color: hsl(234 26% 41%); background: hsl(234 40% 97%)' : 'border-color: hsl(234 20% 88%)'}>
        <div class="flex items-start gap-3">
          <input type="radio" bind:group={bringListMode} value="prefill"
            class="mt-0.5 shrink-0 accent-[hsl(234,26%,41%)]" />
          <div>
            <p class="text-sm font-medium text-foreground">Pre-fill now</p>
            <p class="text-xs text-muted-foreground">Add items members can claim.</p>
          </div>
        </div>
        {#if bringListMode === 'prefill'}
          <div class="flex flex-col gap-2 pl-7">
            {#each bringListItems as _, i}
              <div class="flex gap-2 items-center">
                <input type="text" bind:value={bringListItems[i].name} placeholder="Item name"
                  class="flex-1 px-3 py-2 rounded-lg border border-input bg-background text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-ring transition" />
                <input type="number" bind:value={bringListItems[i].quantity} min="1" max="20"
                  class="w-16 px-2 py-2 rounded-lg border border-input bg-background text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-ring transition text-center" />
                {#if bringListItems.length > 1}
                  <button type="button" onclick={() => removeBringListItem(i)}
                    class="p-2 rounded-lg hover:bg-muted transition-colors" style="color: hsl(234 12% 52%)">
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                      <line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
                    </svg>
                  </button>
                {/if}
              </div>
            {/each}
            <button type="button" onclick={addBringListItem}
              class="text-sm font-medium text-left mt-1" style="color: hsl(234 26% 41%)">
              + Add another item
            </button>
          </div>
        {/if}
      </label>

      <!-- Card 2: Leave open -->
      <label class="flex items-start gap-3 p-4 rounded-xl border cursor-pointer transition-colors"
        style={bringListMode === 'open' ? 'border-color: hsl(234 26% 41%); background: hsl(234 40% 97%)' : 'border-color: hsl(234 20% 88%)'}>
        <input type="radio" bind:group={bringListMode} value="open"
          class="mt-0.5 shrink-0 accent-[hsl(234,26%,41%)]" />
        <div>
          <p class="text-sm font-medium text-foreground">Leave open for members</p>
          <p class="text-xs text-muted-foreground mt-0.5">Members can add and claim items themselves.</p>
        </div>
      </label>

      <!-- Card 3: No bring list -->
      <label class="flex items-start gap-3 p-4 rounded-xl border cursor-pointer transition-colors"
        style={bringListMode === 'none' ? 'border-color: hsl(234 26% 41%); background: hsl(234 40% 97%)' : 'border-color: hsl(234 20% 88%)'}>
        <input type="radio" bind:group={bringListMode} value="none"
          class="mt-0.5 shrink-0 accent-[hsl(234,26%,41%)]" />
        <div>
          <p class="text-sm font-medium text-foreground">No bring list</p>
          <p class="text-xs text-muted-foreground mt-0.5">The bring list section will be hidden for this event. You can change this later.</p>
        </div>
      </label>

      <!-- Skip -->
      <button
        type="button"
        onclick={() => { bringListMode = 'open'; nextStep() }}
        class="text-sm font-medium mt-1"
        style="color: hsl(234 12% 52%)"
      >
        Skip for now
      </button>
    </div>

  <!-- ============ STEP 5: Event Options ============ -->
  {:else if currentStep === 5}
    <div class="flex flex-col gap-3">

      <!-- Recurring event -->
      <div class="flex flex-col gap-3 p-4 rounded-xl border transition-colors"
        style={isRecurring ? 'border-color: hsl(234 26% 41%); background: hsl(234 40% 97%)' : 'border-color: hsl(234 20% 88%)'}>
        <label class="flex items-start gap-3 cursor-pointer">
          <input type="checkbox" bind:checked={isRecurring}
            class="mt-0.5 shrink-0 accent-[hsl(234,26%,41%)]" />
          <div>
            <p class="text-sm font-medium text-foreground">Recurring event</p>
            <p class="text-xs text-muted-foreground">Automatically create future events on a schedule.</p>
          </div>
        </label>
        {#if isRecurring}
          <div class="flex flex-col gap-3 pl-7">
            <div class="flex flex-col gap-1">
              <label class="text-xs font-medium text-muted-foreground">Cadence</label>
              <select bind:value={cadence}
                class="w-full px-3 py-2 rounded-lg border border-input bg-background text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-ring transition">
                <option value="weekly">Weekly</option>
                <option value="biweekly">Biweekly</option>
                <option value="monthly">Monthly</option>
                <option value="every_6_weeks">Every 6 weeks</option>
                <option value="custom">Custom</option>
              </select>
            </div>
            {#if cadence === 'custom'}
              <div class="flex items-center gap-2">
                <label class="text-xs text-muted-foreground shrink-0">Every</label>
                <input type="number" bind:value={customIntervalDays} min="1" max="365"
                  class="w-20 px-2 py-2 rounded-lg border border-input bg-background text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-ring transition text-center" />
                <span class="text-xs text-muted-foreground">days</span>
              </div>
            {/if}
          </div>
        {/if}
      </div>

      <!-- Limit capacity -->
      <div class="flex flex-col gap-3 p-4 rounded-xl border transition-colors"
        style={hasCapacity ? 'border-color: hsl(234 26% 41%); background: hsl(234 40% 97%)' : 'border-color: hsl(234 20% 88%)'}>
        <label class="flex items-start gap-3 cursor-pointer">
          <input type="checkbox" bind:checked={hasCapacity}
            class="mt-0.5 shrink-0 accent-[hsl(234,26%,41%)]" />
          <div>
            <p class="text-sm font-medium text-foreground">Limit capacity</p>
            <p class="text-xs text-muted-foreground">Set a maximum number of attendees. Extra RSVPs join a waitlist.</p>
          </div>
        </label>
        {#if hasCapacity}
          <div class="flex items-center gap-2 pl-7">
            <label class="text-xs text-muted-foreground shrink-0">Max attendees</label>
            <input type="number" bind:value={capacity} min="1" max="500"
              class="w-20 px-2 py-2 rounded-lg border border-input bg-background text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-ring transition text-center" />
          </div>
        {/if}
      </div>

      <!-- Skip link -->
      <button
        type="button"
        onclick={publishEvent}
        class="text-sm font-medium"
        style="color: hsl(234 12% 52%)"
      >
        Skip and publish
      </button>
    </div>
  {/if}

  <!-- Error -->
  {#if error}
    <p class="text-sm text-destructive mt-4">{error}</p>
  {/if}

  <!-- Footer navigation -->
  <div class="flex gap-3 mt-6">
    {#if currentStep > 1}
      <button
        onclick={prevStep}
        class="flex-1 py-2.5 rounded-xl text-sm font-semibold border transition-colors"
        style="border-color: hsl(234 20% 88%); color: hsl(234 12% 52%)"
      >
        Back
      </button>
    {/if}

    {#if currentStep < 5}
      <button
        onclick={nextStep}
        class="flex-1 py-2.5 rounded-xl text-sm font-semibold text-white transition-opacity disabled:opacity-60"
        style="background: hsl(234 26% 41%)"
      >
        Next
      </button>
    {:else}
      <button
        onclick={publishEvent}
        disabled={loading}
        class="flex-1 py-2.5 rounded-xl text-sm font-semibold text-white transition-opacity disabled:opacity-60"
        style="background: hsl(234 26% 41%)"
      >
        {loading ? 'Publishing…' : 'Publish event'}
      </button>
    {/if}
  </div>


</div>
