<script>
  import { supabase } from '$lib/supabase'
  import { page } from '$app/stores'
  import { goto } from '$app/navigation'
  import { onMount } from 'svelte'
  import PhotoUploader from '$lib/components/PhotoUploader.svelte'

  let groupId = $derived($page.params.id)

  // Navigation
  let currentStep = $state(1)
  let draftId = $state(null)

  // Step 1 — Basics
  let title = $state('')
  let description = $state('')
  let hostUserId = $state('')
  let coverPhotoUrl = $state(null)

  // Step 2 — Date & Time
  let datetimeMode = $state('set')
  let eventDate = $state('')
  let eventTime = $state('')
  let datetimeCandidates = $state([{date: '', time: ''}, {date: '', time: ''}])
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

    const draftParam = $page.url.searchParams.get('draft')
    if (draftParam) await loadDraft(draftParam)

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

    datetimeMode = ev.datetime_mode ?? 'set'
    if (ev.datetime_mode === 'set' && ev.event_date) {
      const d = new Date(ev.event_date)
      eventDate = d.toISOString().split('T')[0]
      eventTime = d.toTimeString().slice(0, 5)
    }
    if (dtOptsRes.data?.length) {
      datetimeCandidates = dtOptsRes.data.map(o => {
        const d = new Date(o.candidate_datetime)
        return { date: d.toISOString().split('T')[0], time: d.toTimeString().slice(0, 5) }
      })
      datetimeVotingDeadline = dtOptsRes.data[0]?.voting_deadline
        ? new Date(dtOptsRes.data[0].voting_deadline).toISOString().slice(0, 10) : ''
      datetimeSuggestionsDeadline = dtOptsRes.data[0]?.suggestions_deadline
        ? new Date(dtOptsRes.data[0].suggestions_deadline).toISOString().slice(0, 10) : ''
    }

    locationMode = ev.location_mode ?? 'set'
    if (ev.location_mode === 'set' && ev.location) locationText = ev.location
    else if (ev.location_mode === 'virtual' && ev.location) locationUrl = ev.location
    if (locOptsRes.data?.length) {
      locationCandidates = locOptsRes.data.map(o => o.location_text)
      locationVotingDeadline = locOptsRes.data[0]?.voting_deadline
        ? new Date(locOptsRes.data[0].voting_deadline).toISOString().slice(0, 10) : ''
      locationSuggestionsDeadline = locOptsRes.data[0]?.suggestions_deadline
        ? new Date(locOptsRes.data[0].suggestions_deadline).toISOString().slice(0, 10) : ''
    }

    bringListMode = ev.bring_list_mode ?? 'prefill'
    if (bringRes.data?.length) bringListItems = bringRes.data.map(i => ({ name: i.name, quantity: i.quantity }))

    if (ev.capacity) { hasCapacity = true; capacity = ev.capacity }
    if (ev.event_series) { isRecurring = true; cadence = ev.event_series.cadence; customIntervalDays = ev.event_series.custom_interval_days ?? 14 }
  }

  // -- Candidate helpers --
  function addDatetimeCandidate() { if (datetimeCandidates.length < 5) datetimeCandidates = [...datetimeCandidates, {date: '', time: ''}] }
  function removeDatetimeCandidate(i) { datetimeCandidates = datetimeCandidates.filter((_, idx) => idx !== i) }
  function addLocationCandidate() { if (locationCandidates.length < 5) locationCandidates = [...locationCandidates, ''] }
  function removeLocationCandidate(i) { locationCandidates = locationCandidates.filter((_, idx) => idx !== i) }
  function addBringListItem() { bringListItems = [...bringListItems, { name: '', quantity: 1 }] }
  function removeBringListItem(i) { bringListItems = bringListItems.filter((_, idx) => idx !== i) }

  // -- Navigation --
  function nextStep() {
    if (currentStep === 1 && !title.trim()) { error = 'Please enter an event name.'; return }
    error = ''
    if (currentStep < 5) currentStep++
  }
  function prevStep() { error = ''; if (currentStep > 1) currentStep-- }

  // -- Data helpers --
  function resolveStatus(isDraft) {
    if (isDraft) return 'draft'
    if (datetimeMode === 'poll_host' || datetimeMode === 'poll_open') return 'pending_date'
    return 'confirmed'
  }
  function resolveLocation() {
    if (locationMode === 'set') return locationText.trim() || null
    if (locationMode === 'virtual') return locationUrl.trim() || null
    return null
  }
  function resolveEventDate() {
    if (datetimeMode === 'set' && eventDate) {
      return new Date(`${eventDate}T${eventTime || '18:00'}`).toISOString()
    }
    return null
  }
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
      series_id: null,
    }
  }

  async function saveRelatedRows(eventId) {
    if (datetimeMode === 'poll_host' || datetimeMode === 'poll_open') {
      const validDates = datetimeCandidates.filter(d => d.date)
      if (validDates.length) {
        await supabase.from('event_datetime_options').delete().eq('event_id', eventId)
        await supabase.from('event_datetime_options').insert(
          validDates.map(d => ({
            event_id: eventId,
            candidate_datetime: new Date(`${d.date}T${d.time || '18:00'}`).toISOString(),
            voting_deadline: datetimeVotingDeadline ? new Date(datetimeVotingDeadline).toISOString() : null,
            suggestions_deadline: datetimeMode === 'poll_open' && datetimeSuggestionsDeadline
              ? new Date(datetimeSuggestionsDeadline).toISOString() : null,
          }))
        )
      }
    }
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
              ? new Date(locationSuggestionsDeadline).toISOString() : null,
          }))
        )
      }
    }
    if (bringListMode === 'prefill') {
      const validItems = bringListItems.filter(i => i.name.trim())
      if (validItems.length) {
        await supabase.from('bring_list_items').delete().eq('event_id', eventId)
        await supabase.from('bring_list_items').insert(
          validItems.map(i => ({ event_id: eventId, name: i.name.trim(), quantity: i.quantity, added_by: currentUserId }))
        )
      }
    }
    if (isRecurring) {
      const { data: series } = await supabase.from('event_series').insert({
        cadence,
        custom_interval_days: cadence === 'custom' ? customIntervalDays : null,
        created_by: currentUserId,
      }).select().single()
      if (series) await supabase.from('events').update({ series_id: series.id }).eq('id', eventId)
    }
  }

  async function saveDraft() {
    if (!title.trim()) { error = 'Please enter an event name to save a draft.'; return }
    saving = true; error = ''
    const data = buildEventData(true)
    let eventId = draftId
    if (draftId) {
      const { error: updateErr } = await supabase.from('events').update(data).eq('id', draftId)
      if (updateErr) { error = updateErr.message; saving = false; return }
    } else {
      const { data: event, error: insertErr } = await supabase.from('events').insert(data).select().single()
      if (insertErr) { error = insertErr.message; saving = false; return }
      eventId = event.id; draftId = event.id
    }
    await saveRelatedRows(eventId)
    saving = false
    goto(`/groups/${groupId}/events/new?draft=${eventId}`, { replaceState: true })
  }

  async function publishEvent() {
    if (!title.trim()) { error = 'Please enter an event name.'; return }
    loading = true; error = ''
    const data = buildEventData(false)
    let eventId = draftId
    if (draftId) {
      const { error: updateErr } = await supabase.from('events').update(data).eq('id', draftId)
      if (updateErr) { error = updateErr.message; loading = false; return }
    } else {
      const { data: event, error: insertErr } = await supabase.from('events').insert(data).select().single()
      if (insertErr) { error = insertErr.message; loading = false; return }
      eventId = event.id
    }
    await saveRelatedRows(eventId)
    const { data: groupMembers } = await supabase.from('group_members').select('user_id').eq('group_id', groupId)
    const otherMembers = (groupMembers ?? []).filter(m => m.user_id !== currentUserId)
    if (otherMembers.length) {
      await supabase.from('notifications').insert(
        otherMembers.map(m => ({ user_id: m.user_id, type: 'new_event', body: `New event: ${title.trim()}`, link: `/groups/${groupId}/events/${eventId}`, is_read: false }))
      )
    }
    if (hostUserId && hostUserId !== currentUserId) {
      await supabase.from('notifications').insert({ user_id: hostUserId, type: 'host_assigned', body: `You're hosting ${title.trim()}`, link: `/groups/${groupId}/events/${eventId}`, is_read: false })
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

  const accent = 'var(--color-primary)'
  const accentSoft = 'hsl(234 40% 94%)'
  const accentStroke = 'hsl(234 55% 80%)'

  function cardStyle(selected) {
    return selected
      ? `background: white; border: 1.5px solid ${accentStroke};`
      : 'background: white;'
  }
  function inputStyle(white = false) {
    return white
      ? 'background: white; border: none; outline: none;'
      : 'background: hsl(234 20% 96%); border: none; outline: none;'
  }
</script>

<!-- Full-screen overlay -->
<div class="fixed inset-0 z-[100] flex flex-col" style="background: hsl(234 20% 97%)">

  <!-- Header -->
  <div class="flex items-center justify-between px-4 pt-7 pb-3 shrink-0">
    <button
      onclick={() => goto(`/groups/${groupId}/events`)}
      class="flex items-center gap-1.5 transition-colors"
      style="color: {accent}"
    >
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
        <polyline points="15 18 9 12 15 6"/>
      </svg>
      <span class="text-xs">Back to Group</span>
    </button>
    <button
      onclick={saveDraft}
      disabled={saving || !title.trim()}
      class="text-xs transition-opacity disabled:opacity-40"
      style="color: {accent}"
    >
      {saving ? 'Saving…' : 'Save draft'}
    </button>
  </div>

  <!-- Step label + title + progress -->
  <div class="px-4 pt-4 pb-8 shrink-0">
    <p class="text-xs font-bold tracking-wide mb-1.5" style="color: hsl(234 12% 62%)">STEP {currentStep} OF 5</p>
    <h1 class="text-4xl font-extrabold mb-4" style="color: {accent}">{stepLabel}</h1>
    <!-- Progress dots -->
    <div class="flex items-center gap-1.5">
      {#each [1,2,3,4,5] as step}
        <div
          class="rounded-full transition-all duration-300"
          style="height: 6px; width: {step === currentStep ? '18px' : '6px'}; background: {step === currentStep ? accent : 'hsl(234 50% 88%)'};"
        ></div>
      {/each}
    </div>
  </div>

  <!-- Scrollable content -->
  <div class="flex-1 overflow-y-auto px-4 pb-4">

    <!-- ============ STEP 1: The Basics ============ -->
    {#if currentStep === 1}
      <div class="flex flex-col gap-4">

        <div class="flex flex-col gap-2">
          <p class="text-sm font-medium text-foreground">Event photo <span class="text-muted-foreground font-normal text-xs">optional</span></p>
          <PhotoUploader bucket="event-covers" pathPrefix={groupId} bind:value={coverPhotoUrl} shape="square" size="lg" />
        </div>

        <div class="flex flex-col gap-1.5">
          <label for="title" class="text-sm font-medium text-foreground">Event name <span class="text-destructive text-xs">required</span></label>
          <input id="title" type="text" bind:value={title} placeholder="April Book Club" maxlength="80"
            class="w-full px-3 py-2.5 rounded-xl text-sm text-foreground placeholder:text-muted-foreground transition"
            style={inputStyle(true)} />
        </div>

        <div class="flex flex-col gap-1.5">
          <label for="desc" class="text-sm font-medium text-foreground">Description <span class="text-muted-foreground font-normal text-xs">optional</span></label>
          <textarea id="desc" bind:value={description} placeholder="What should members know?" rows="3" maxlength="500"
            class="w-full px-3 py-2.5 rounded-xl text-sm text-foreground placeholder:text-muted-foreground transition resize-none"
            style={inputStyle(true)}></textarea>
        </div>

        {#if members.length > 1}
          <div class="flex flex-col gap-1.5">
            <label for="host" class="text-sm font-medium text-foreground">Host</label>
            <select id="host" bind:value={hostUserId}
              class="w-full px-3 py-2.5 rounded-xl text-sm text-foreground transition appearance-none"
              style={inputStyle(true)}>
              {#each members as m}
                <option value={m.user_id}>{m.users?.display_name}</option>
              {/each}
            </select>
          </div>
        {/if}

        {#if error}<p class="text-sm text-destructive">{error}</p>{/if}
      </div>

    <!-- ============ STEP 2: Date & Time ============ -->
    {:else if currentStep === 2}
      <div class="flex flex-col gap-3">

        <!-- Set a date -->
        <label class="block p-4 rounded-2xl cursor-pointer transition-all" style={cardStyle(datetimeMode === 'set')}>
          <input type="radio" bind:group={datetimeMode} value="set" class="sr-only" />
          <div class="flex items-center gap-3">
              <div class="w-11 h-11 rounded-xl flex items-center justify-center" style="background: {accentSoft}">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="{accent}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                  <rect x="3" y="4" width="18" height="18" rx="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/>
                </svg>
              </div>
              <p class="text-lg font-bold text-foreground flex-1">Set a date</p>
            <svg width="20" height="20" viewBox="0 0 24 24" fill="{datetimeMode === 'set' ? accent : 'none'}" stroke="{datetimeMode === 'set' ? accent : 'hsl(234 15% 80%)'}" stroke-width="2">
              <circle cx="12" cy="12" r="10"/>
              {#if datetimeMode === 'set'}<path d="M8 12l3 3 5-5" stroke="white" stroke-width="2" fill="none" stroke-linecap="round" stroke-linejoin="round"/>{/if}
            </svg>
          </div>
          {#if datetimeMode === 'set'}
            <div class="grid grid-cols-2 gap-3 mt-4 pt-4" style="border-top: 1px solid hsl(234 20% 92%)">
              <div class="flex flex-col gap-1">
                <label class="text-xs font-medium text-muted-foreground">Date</label>
                <input type="date" bind:value={eventDate} class="w-full px-3 py-2 rounded-lg text-sm text-foreground transition" style={inputStyle()} />
              </div>
              <div class="flex flex-col gap-1">
                <label class="text-xs font-medium text-muted-foreground">Time <span class="font-normal">(opt.)</span></label>
                <input type="time" bind:value={eventTime} class="w-full px-3 py-2 rounded-lg text-sm text-foreground transition" style={inputStyle()} />
              </div>
            </div>
          {/if}
        </label>

        <!-- Let the group vote -->
        <label class="block p-4 rounded-2xl cursor-pointer transition-all" style={cardStyle(datetimeMode === 'poll_host')}>
          <input type="radio" bind:group={datetimeMode} value="poll_host" class="sr-only" />
          <div class="flex items-center gap-3">
              <div class="w-11 h-11 rounded-xl flex items-center justify-center" style="background: {accentSoft}">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="{accent}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                  <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>
                </svg>
              </div>
              <p class="text-lg font-bold text-foreground flex-1">Let the group vote</p>
            <svg width="20" height="20" viewBox="0 0 24 24" fill="{datetimeMode === 'poll_host' ? accent : 'none'}" stroke="{datetimeMode === 'poll_host' ? accent : 'hsl(234 15% 80%)'}" stroke-width="2">
              <circle cx="12" cy="12" r="10"/>
              {#if datetimeMode === 'poll_host'}<path d="M8 12l3 3 5-5" stroke="white" stroke-width="2" fill="none" stroke-linecap="round" stroke-linejoin="round"/>{/if}
            </svg>
          </div>
          {#if datetimeMode === 'poll_host'}
            <div class="flex flex-col gap-3 mt-4 pt-4" style="border-top: 1px solid hsl(234 20% 92%)">
              <p class="text-xs font-medium text-muted-foreground">Candidate dates (2–5)</p>
              {#each datetimeCandidates as _, i}
                <div class="flex flex-col gap-1">
                  <div class="grid grid-cols-2 gap-2">
                    <div class="flex flex-col gap-1">
                      <label class="text-xs font-medium text-muted-foreground">Date</label>
                      <input type="date" bind:value={datetimeCandidates[i].date} class="w-full px-3 py-2 rounded-lg text-sm text-foreground transition" style={inputStyle()} />
                    </div>
                    <div class="flex flex-col gap-1">
                      <label class="text-xs font-medium text-muted-foreground">Time <span class="font-normal">(opt.)</span></label>
                      <input type="time" bind:value={datetimeCandidates[i].time} class="w-full px-3 py-2 rounded-lg text-sm text-foreground transition" style={inputStyle()} />
                    </div>
                  </div>
                  {#if datetimeCandidates.length > 2}
                    <button type="button" onclick={() => removeDatetimeCandidate(i)} class="text-xs self-start" style="color: hsl(234 12% 62%)">Remove</button>
                  {/if}
                </div>
              {/each}
              {#if datetimeCandidates.length < 5}
                <button type="button" onclick={addDatetimeCandidate} class="text-xs font-semibold text-left" style="color: {accent}">+ Add another option</button>
              {/if}
              <div class="flex flex-col gap-1">
                <label class="text-xs font-medium text-muted-foreground">Voting deadline</label>
                <input type="date" bind:value={datetimeVotingDeadline} class="w-full px-3 py-2 rounded-lg text-sm text-foreground transition" style={inputStyle()} />
              </div>
            </div>
          {/if}
        </label>

        <!-- Ask for suggestions -->
        <label class="block p-4 rounded-2xl cursor-pointer transition-all" style={cardStyle(datetimeMode === 'poll_open')}>
          <input type="radio" bind:group={datetimeMode} value="poll_open" class="sr-only" />
          <div class="flex items-center gap-3">
              <div class="w-11 h-11 rounded-xl flex items-center justify-center" style="background: {accentSoft}">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="{accent}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                  <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
                </svg>
              </div>
              <p class="text-lg font-bold text-foreground flex-1">Ask for suggestions</p>
            <svg width="20" height="20" viewBox="0 0 24 24" fill="{datetimeMode === 'poll_open' ? accent : 'none'}" stroke="{datetimeMode === 'poll_open' ? accent : 'hsl(234 15% 80%)'}" stroke-width="2">
              <circle cx="12" cy="12" r="10"/>
              {#if datetimeMode === 'poll_open'}<path d="M8 12l3 3 5-5" stroke="white" stroke-width="2" fill="none" stroke-linecap="round" stroke-linejoin="round"/>{/if}
            </svg>
          </div>
          {#if datetimeMode === 'poll_open'}
            <div class="flex flex-col gap-3 mt-4 pt-4" style="border-top: 1px solid hsl(234 20% 92%)">
              <div class="flex flex-col gap-1">
                <label class="text-xs font-medium text-muted-foreground">Suggestions close</label>
                <input type="date" bind:value={datetimeSuggestionsDeadline} class="w-full px-3 py-2 rounded-lg text-sm text-foreground transition" style={inputStyle()} />
              </div>
              <div class="flex flex-col gap-1">
                <label class="text-xs font-medium text-muted-foreground">Voting deadline</label>
                <input type="date" bind:value={datetimeVotingDeadline} class="w-full px-3 py-2 rounded-lg text-sm text-foreground transition" style={inputStyle()} />
              </div>
            </div>
          {/if}
        </label>

        {#if error}<p class="text-sm text-destructive">{error}</p>{/if}
      </div>

    <!-- ============ STEP 3: Location ============ -->
    {:else if currentStep === 3}
      <div class="flex flex-col gap-3">

        <!-- Set a location -->
        <label class="block p-4 rounded-2xl cursor-pointer transition-all" style={cardStyle(locationMode === 'set')}>
          <input type="radio" bind:group={locationMode} value="set" class="sr-only" />
          <div class="flex items-center gap-3">
              <div class="w-11 h-11 rounded-xl flex items-center justify-center" style="background: {accentSoft}">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="{accent}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                  <path d="M21 10c0 7-9 13-9 13S3 17 3 10a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/>
                </svg>
              </div>
              <p class="text-lg font-bold text-foreground flex-1">Set a location</p>
            <svg width="20" height="20" viewBox="0 0 24 24" fill="{locationMode === 'set' ? accent : 'none'}" stroke="{locationMode === 'set' ? accent : 'hsl(234 15% 80%)'}" stroke-width="2">
              <circle cx="12" cy="12" r="10"/>
              {#if locationMode === 'set'}<path d="M8 12l3 3 5-5" stroke="white" stroke-width="2" fill="none" stroke-linecap="round" stroke-linejoin="round"/>{/if}
            </svg>
          </div>
          {#if locationMode === 'set'}
            <div class="mt-4 pt-4" style="border-top: 1px solid hsl(234 20% 92%)">
              <input type="text" bind:value={locationText} placeholder="123 Main St or venue name"
                class="w-full px-3 py-2 rounded-lg text-sm text-foreground placeholder:text-muted-foreground transition" style={inputStyle()} />
            </div>
          {/if}
        </label>

        <!-- Virtual / link -->
        <label class="block p-4 rounded-2xl cursor-pointer transition-all" style={cardStyle(locationMode === 'virtual')}>
          <input type="radio" bind:group={locationMode} value="virtual" class="sr-only" />
          <div class="flex items-center gap-3">
              <div class="w-11 h-11 rounded-xl flex items-center justify-center" style="background: {accentSoft}">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="{accent}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                  <polygon points="23 7 16 12 23 17 23 7"/><rect x="1" y="5" width="15" height="14" rx="2"/>
                </svg>
              </div>
              <p class="text-lg font-bold text-foreground flex-1">Virtual / link</p>
            <svg width="20" height="20" viewBox="0 0 24 24" fill="{locationMode === 'virtual' ? accent : 'none'}" stroke="{locationMode === 'virtual' ? accent : 'hsl(234 15% 80%)'}" stroke-width="2">
              <circle cx="12" cy="12" r="10"/>
              {#if locationMode === 'virtual'}<path d="M8 12l3 3 5-5" stroke="white" stroke-width="2" fill="none" stroke-linecap="round" stroke-linejoin="round"/>{/if}
            </svg>
          </div>
          {#if locationMode === 'virtual'}
            <div class="mt-4 pt-4 flex flex-col gap-1" style="border-top: 1px solid hsl(234 20% 92%)">
              <input type="url" bind:value={locationUrl} placeholder="https://zoom.us/j/..."
                class="w-full px-3 py-2 rounded-lg text-sm text-foreground placeholder:text-muted-foreground transition" style={inputStyle()} />
              {#if urlWarning}<p class="text-xs" style="color: hsl(35 80% 40%)">{urlWarning}</p>{/if}
            </div>
          {/if}
        </label>

        <!-- Let the group vote -->
        <label class="block p-4 rounded-2xl cursor-pointer transition-all" style={cardStyle(locationMode === 'poll_host')}>
          <input type="radio" bind:group={locationMode} value="poll_host" class="sr-only" />
          <div class="flex items-center gap-3">
              <div class="w-11 h-11 rounded-xl flex items-center justify-center" style="background: {accentSoft}">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="{accent}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                  <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>
                </svg>
              </div>
              <p class="text-lg font-bold text-foreground flex-1">Let the group vote</p>
            <svg width="20" height="20" viewBox="0 0 24 24" fill="{locationMode === 'poll_host' ? accent : 'none'}" stroke="{locationMode === 'poll_host' ? accent : 'hsl(234 15% 80%)'}" stroke-width="2">
              <circle cx="12" cy="12" r="10"/>
              {#if locationMode === 'poll_host'}<path d="M8 12l3 3 5-5" stroke="white" stroke-width="2" fill="none" stroke-linecap="round" stroke-linejoin="round"/>{/if}
            </svg>
          </div>
          {#if locationMode === 'poll_host'}
            <div class="flex flex-col gap-2 mt-4 pt-4" style="border-top: 1px solid hsl(234 20% 92%)">
              <p class="text-xs font-medium text-muted-foreground">Location options (2–5)</p>
              {#each locationCandidates as _, i}
                <div class="flex gap-2 items-center">
                  <input type="text" bind:value={locationCandidates[i]} placeholder="Address or venue"
                    class="flex-1 px-3 py-2 rounded-lg text-sm text-foreground placeholder:text-muted-foreground transition" style={inputStyle()} />
                  {#if locationCandidates.length > 2}
                    <button type="button" onclick={() => removeLocationCandidate(i)} class="text-xs" style="color: hsl(234 12% 62%)">Remove</button>
                  {/if}
                </div>
              {/each}
              {#if locationCandidates.length < 5}
                <button type="button" onclick={addLocationCandidate} class="text-xs font-semibold text-left" style="color: {accent}">+ Add another option</button>
              {/if}
              <div class="flex flex-col gap-1 mt-1">
                <label class="text-xs font-medium text-muted-foreground">Voting deadline</label>
                <input type="date" bind:value={locationVotingDeadline} class="w-full px-3 py-2 rounded-lg text-sm text-foreground transition" style={inputStyle()} />
              </div>
            </div>
          {/if}
        </label>

        <!-- Ask for suggestions -->
        <label class="block p-4 rounded-2xl cursor-pointer transition-all" style={cardStyle(locationMode === 'poll_open')}>
          <input type="radio" bind:group={locationMode} value="poll_open" class="sr-only" />
          <div class="flex items-center gap-3">
              <div class="w-11 h-11 rounded-xl flex items-center justify-center" style="background: {accentSoft}">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="{accent}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                  <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
                </svg>
              </div>
              <p class="text-lg font-bold text-foreground flex-1">Ask for suggestions</p>
            <svg width="20" height="20" viewBox="0 0 24 24" fill="{locationMode === 'poll_open' ? accent : 'none'}" stroke="{locationMode === 'poll_open' ? accent : 'hsl(234 15% 80%)'}" stroke-width="2">
              <circle cx="12" cy="12" r="10"/>
              {#if locationMode === 'poll_open'}<path d="M8 12l3 3 5-5" stroke="white" stroke-width="2" fill="none" stroke-linecap="round" stroke-linejoin="round"/>{/if}
            </svg>
          </div>
          {#if locationMode === 'poll_open'}
            <div class="flex flex-col gap-3 mt-4 pt-4" style="border-top: 1px solid hsl(234 20% 92%)">
              <div class="flex flex-col gap-1">
                <label class="text-xs font-medium text-muted-foreground">Suggestions close</label>
                <input type="date" bind:value={locationSuggestionsDeadline} class="w-full px-3 py-2 rounded-lg text-sm text-foreground transition" style={inputStyle()} />
              </div>
              <div class="flex flex-col gap-1">
                <label class="text-xs font-medium text-muted-foreground">Voting deadline</label>
                <input type="date" bind:value={locationVotingDeadline} class="w-full px-3 py-2 rounded-lg text-sm text-foreground transition" style={inputStyle()} />
              </div>
            </div>
          {/if}
        </label>

        {#if error}<p class="text-sm text-destructive">{error}</p>{/if}
      </div>

    <!-- ============ STEP 4: Bring List ============ -->
    {:else if currentStep === 4}
      <div class="flex flex-col gap-3">

        <!-- Pre-fill now -->
        <label class="block p-4 rounded-2xl cursor-pointer transition-all" style={cardStyle(bringListMode === 'prefill')}>
          <input type="radio" bind:group={bringListMode} value="prefill" class="sr-only" />
          <div class="flex items-center gap-3">
              <div class="w-11 h-11 rounded-xl flex items-center justify-center" style="background: {accentSoft}">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="{accent}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                  <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/><polyline points="10 9 9 9 8 9"/>
                </svg>
              </div>
              <p class="text-lg font-bold text-foreground flex-1">Pre-fill now</p>
            <svg width="20" height="20" viewBox="0 0 24 24" fill="{bringListMode === 'prefill' ? accent : 'none'}" stroke="{bringListMode === 'prefill' ? accent : 'hsl(234 15% 80%)'}" stroke-width="2">
              <circle cx="12" cy="12" r="10"/>
              {#if bringListMode === 'prefill'}<path d="M8 12l3 3 5-5" stroke="white" stroke-width="2" fill="none" stroke-linecap="round" stroke-linejoin="round"/>{/if}
            </svg>
          </div>
          {#if bringListMode === 'prefill'}
            <div class="flex flex-col gap-2 mt-4 pt-4" style="border-top: 1px solid hsl(234 20% 92%)">
              {#each bringListItems as _, i}
                <div class="flex gap-2 items-center">
                  <input type="text" bind:value={bringListItems[i].name} placeholder="Item name"
                    class="flex-1 px-3 py-2 rounded-lg text-sm text-foreground placeholder:text-muted-foreground transition" style={inputStyle()} />
                  <div class="flex items-center rounded-lg overflow-hidden" style={inputStyle()}>
                    <button type="button" onclick={() => bringListItems[i].quantity = Math.max(1, bringListItems[i].quantity - 1)}
                      class="px-2 py-2 text-muted-foreground hover:text-foreground transition-colors text-base leading-none">−</button>
                    <span class="w-6 text-center text-sm text-foreground">{bringListItems[i].quantity}</span>
                    <button type="button" onclick={() => bringListItems[i].quantity = Math.min(20, bringListItems[i].quantity + 1)}
                      class="px-2 py-2 text-muted-foreground hover:text-foreground transition-colors text-base leading-none">+</button>
                  </div>
                  {#if bringListItems.length > 1}
                    <button type="button" onclick={() => removeBringListItem(i)} class="text-xs" style="color: hsl(234 12% 62%)">Remove</button>
                  {/if}
                </div>
              {/each}
              <button type="button" onclick={addBringListItem} class="text-xs font-semibold text-left mt-1" style="color: {accent}">+ Add another item</button>
            </div>
          {/if}
        </label>

        <!-- Leave open -->
        <label class="block p-4 rounded-2xl cursor-pointer transition-all" style={cardStyle(bringListMode === 'open')}>
          <input type="radio" bind:group={bringListMode} value="open" class="sr-only" />
          <div class="flex items-center gap-3">
              <div class="w-11 h-11 rounded-xl flex items-center justify-center" style="background: {accentSoft}">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="{accent}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                  <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><line x1="19" y1="8" x2="19" y2="14"/><line x1="22" y1="11" x2="16" y2="11"/>
                </svg>
              </div>
              <p class="text-lg font-bold text-foreground flex-1">Leave open for members</p>
            <svg width="20" height="20" viewBox="0 0 24 24" fill="{bringListMode === 'open' ? accent : 'none'}" stroke="{bringListMode === 'open' ? accent : 'hsl(234 15% 80%)'}" stroke-width="2">
              <circle cx="12" cy="12" r="10"/>
              {#if bringListMode === 'open'}<path d="M8 12l3 3 5-5" stroke="white" stroke-width="2" fill="none" stroke-linecap="round" stroke-linejoin="round"/>{/if}
            </svg>
          </div>
        </label>

        <!-- No bring list -->
        <label class="block p-4 rounded-2xl cursor-pointer transition-all" style={cardStyle(bringListMode === 'none')}>
          <input type="radio" bind:group={bringListMode} value="none" class="sr-only" />
          <div class="flex items-center gap-3">
              <div class="w-11 h-11 rounded-xl flex items-center justify-center" style="background: {accentSoft}">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="{accent}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                  <circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/>
                </svg>
              </div>
              <p class="text-lg font-bold text-foreground flex-1">No bring list</p>
            <svg width="20" height="20" viewBox="0 0 24 24" fill="{bringListMode === 'none' ? accent : 'none'}" stroke="{bringListMode === 'none' ? accent : 'hsl(234 15% 80%)'}" stroke-width="2">
              <circle cx="12" cy="12" r="10"/>
              {#if bringListMode === 'none'}<path d="M8 12l3 3 5-5" stroke="white" stroke-width="2" fill="none" stroke-linecap="round" stroke-linejoin="round"/>{/if}
            </svg>
          </div>
        </label>

        {#if error}<p class="text-sm text-destructive">{error}</p>{/if}
      </div>

    <!-- ============ STEP 5: Event Options ============ -->
    {:else if currentStep === 5}
      <div class="flex flex-col gap-3">

        <!-- Recurring event -->
        <label class="block p-4 rounded-2xl cursor-pointer transition-all" style={cardStyle(isRecurring)}>
          <input type="checkbox" bind:checked={isRecurring} class="sr-only" />
          <div class="flex items-center gap-3">
              <div class="w-11 h-11 rounded-xl flex items-center justify-center" style="background: {accentSoft}">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="{accent}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                  <polyline points="17 1 21 5 17 9"/><path d="M3 11V9a4 4 0 0 1 4-4h14"/><polyline points="7 23 3 19 7 15"/><path d="M21 13v2a4 4 0 0 1-4 4H3"/>
                </svg>
              </div>
              <p class="text-lg font-bold text-foreground flex-1">Recurring event</p>
            <!-- Checkbox toggle -->
            <div class="w-5 h-5 rounded flex items-center justify-center transition-all" style="background: {isRecurring ? accent : 'white'}; border: 2px solid {isRecurring ? accent : 'hsl(234 15% 80%)'};">
              {#if isRecurring}
                <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">
                  <polyline points="20 6 9 17 4 12"/>
                </svg>
              {/if}
            </div>
          </div>
          {#if isRecurring}
            <div class="flex flex-col gap-3 mt-4 pt-4" style="border-top: 1px solid hsl(234 20% 92%)">
              <div class="flex flex-col gap-1">
                <label class="text-xs font-medium text-muted-foreground">Cadence</label>
                <select bind:value={cadence} class="w-full px-3 py-2 rounded-lg text-sm text-foreground transition" style={inputStyle()}>
                  <option value="weekly">Weekly</option>
                  <option value="biweekly">Biweekly</option>
                  <option value="monthly">Monthly</option>
                  <option value="every_6_weeks">Every 6 weeks</option>
                  <option value="custom">Custom</option>
                </select>
              </div>
              {#if cadence === 'custom'}
                <div class="flex items-center gap-2">
                  <span class="text-xs text-muted-foreground shrink-0">Every</span>
                  <input type="number" bind:value={customIntervalDays} min="1" max="365" class="w-20 px-2 py-2 rounded-lg text-sm text-foreground transition text-center" style={inputStyle()} />
                  <span class="text-xs text-muted-foreground">days</span>
                </div>
              {/if}
            </div>
          {/if}
        </label>

        <!-- Limit capacity -->
        <label class="block p-4 rounded-2xl cursor-pointer transition-all" style={cardStyle(hasCapacity)}>
          <input type="checkbox" bind:checked={hasCapacity} class="sr-only" />
          <div class="flex items-center gap-3">
              <div class="w-11 h-11 rounded-xl flex items-center justify-center" style="background: {accentSoft}">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="{accent}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                  <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>
                </svg>
              </div>
              <p class="text-lg font-bold text-foreground flex-1">Limit capacity</p>
            <div class="w-5 h-5 rounded flex items-center justify-center transition-all" style="background: {hasCapacity ? accent : 'white'}; border: 2px solid {hasCapacity ? accent : 'hsl(234 15% 80%)'};">
              {#if hasCapacity}
                <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">
                  <polyline points="20 6 9 17 4 12"/>
                </svg>
              {/if}
            </div>
          </div>
          {#if hasCapacity}
            <div class="flex items-center gap-2 mt-4 pt-4" style="border-top: 1px solid hsl(234 20% 92%)">
              <span class="text-xs text-muted-foreground shrink-0">Max attendees</span>
              <input type="number" bind:value={capacity} min="1" max="500" class="w-20 px-2 py-2 rounded-lg text-sm text-foreground transition text-center" style={inputStyle()} />
            </div>
          {/if}
        </label>

        {#if error}<p class="text-sm text-destructive">{error}</p>{/if}
      </div>
    {/if}

  </div>

  <!-- Footer buttons -->
  <div class="px-4 pt-2 pb-6 shrink-0" style="background: hsl(234 20% 97%)">
    {#if currentStep === 1}
      <button onclick={nextStep} class="w-full py-3 rounded-xl text-sm font-semibold text-white transition-opacity" style="background: {accent}">
        Next
      </button>
    {:else if currentStep === 2}
      <div class="flex gap-3">
        <button type="button" onclick={() => { datetimeMode = null; nextStep() }}
          class="flex-1 py-3 rounded-xl text-sm font-semibold transition-colors"
          style="background: white; color: hsl(234 12% 52%);">
          Skip
        </button>
        <button onclick={nextStep} class="flex-1 py-3 rounded-xl text-sm font-semibold text-white transition-opacity" style="background: {accent}">
          Next
        </button>
      </div>
    {:else if currentStep === 3}
      <div class="flex gap-3">
        <button type="button" onclick={() => { locationMode = null; nextStep() }}
          class="flex-1 py-3 rounded-xl text-sm font-semibold transition-colors"
          style="background: white; color: hsl(234 12% 52%);">
          Skip
        </button>
        <button onclick={nextStep} class="flex-1 py-3 rounded-xl text-sm font-semibold text-white transition-opacity" style="background: {accent}">
          Next
        </button>
      </div>
    {:else if currentStep === 4}
      <div class="flex gap-3">
        <button type="button" onclick={() => { bringListMode = 'open'; nextStep() }}
          class="flex-1 py-3 rounded-xl text-sm font-semibold transition-colors"
          style="background: white; color: hsl(234 12% 52%);">
          Skip
        </button>
        <button onclick={nextStep} class="flex-1 py-3 rounded-xl text-sm font-semibold text-white transition-opacity" style="background: {accent}">
          Next
        </button>
      </div>
    {:else if currentStep === 5}
      <div class="flex gap-3">
        <button onclick={prevStep} class="flex-1 py-3 rounded-xl text-sm font-semibold transition-colors"
          style="background: white; color: hsl(234 12% 52%);">
          Back
        </button>
        <button onclick={publishEvent} disabled={loading}
          class="flex-1 py-3 rounded-xl text-sm font-semibold text-white transition-opacity disabled:opacity-60"
          style="background: {accent}">
          {loading ? 'Publishing…' : 'Publish event'}
        </button>
      </div>
    {/if}
  </div>

</div>
