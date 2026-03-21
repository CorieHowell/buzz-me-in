<script>
  import { supabase } from '$lib/supabase'
  import { page } from '$app/stores'
  import { goto } from '$app/navigation'
  import { onMount } from 'svelte'

  let groupId = $derived($page.params.id)
  let title = $state('')
  let description = $state('')
  let location = $state('')
  let eventDate = $state('')
  let eventTime = $state('')
  let useDatePicker = $state(false)
  let candidateDates = $state(['', '', ''])
  let responseDeadline = $state('')
  let loading = $state(false)
  let error = $state('')
  let members = $state([])
  let hostUserId = $state('')
  let currentUserId = $state(null)

  onMount(async () => {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) { goto('/auth/login'); return }
    currentUserId = user.id
    hostUserId = user.id

    // Check admin
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

    // Load members for host picker
    const { data: memberData } = await supabase
      .from('group_members')
      .select('user_id, users(display_name)')
      .eq('group_id', groupId)

    members = memberData ?? []
  })

  function addCandidateDate() {
    if (candidateDates.length < 5) candidateDates = [...candidateDates, '']
  }

  function removeCandidateDate(i) {
    candidateDates = candidateDates.filter((_, idx) => idx !== i)
  }

  async function handleSubmit() {
    if (!title.trim()) { error = 'Please enter an event title.'; return }

    if (!useDatePicker && !eventDate) { error = 'Please set a date or use the availability picker.'; return }
    if (useDatePicker && candidateDates.filter(d => d).length < 2) {
      error = 'Please add at least 2 candidate dates.'
      return
    }

    loading = true
    error = ''

    let eventDatetime = null
    let status = 'confirmed'

    if (!useDatePicker && eventDate) {
      const timeStr = eventTime || '18:00'
      eventDatetime = new Date(`${eventDate}T${timeStr}`).toISOString()
    } else {
      status = 'pending_date'
      // Use first candidate as placeholder date
      eventDatetime = new Date(candidateDates.filter(d => d)[0]).toISOString()
    }

    const { data: event, error: eventError } = await supabase
      .from('events')
      .insert({
        group_id: groupId,
        host_user_id: hostUserId || currentUserId,
        title: title.trim(),
        description: description.trim() || null,
        location: location.trim() || null,
        event_date: eventDatetime,
        status,
      })
      .select()
      .single()

    if (eventError) { error = eventError.message; loading = false; return }

    // If using date picker, insert candidate date options
    if (useDatePicker) {
      const validDates = candidateDates.filter(d => d)
      const deadline = responseDeadline
        ? new Date(responseDeadline).toISOString()
        : new Date(Date.now() + 3 * 24 * 60 * 60 * 1000).toISOString()

      await supabase.from('event_date_options').insert(
        validDates.map(d => ({
          event_id: event.id,
          candidate_date: new Date(d).toISOString(),
          response_deadline: deadline,
        }))
      )
    }

    goto(`/groups/${groupId}/events/${event.id}`)
  }
</script>

<div class="max-w-lg mx-auto px-4 py-6">
  <h2 class="text-lg font-semibold text-foreground mb-6">New event</h2>

  <form onsubmit={(e) => { e.preventDefault(); handleSubmit() }} class="flex flex-col gap-5">

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

    <!-- Date mode toggle -->
    <div class="flex flex-col gap-2">
      <label class="text-sm font-medium text-foreground">Date</label>
      <div class="flex gap-2">
        <button type="button"
          onclick={() => useDatePicker = false}
          class="flex-1 py-2 rounded-xl text-sm font-medium border transition-colors"
          style={!useDatePicker
            ? 'background: hsl(234 40% 97%); border-color: hsl(234 26% 41%); color: hsl(234 26% 41%)'
            : 'border-color: hsl(234 20% 88%); color: hsl(234 12% 52%)'}
        >
          Set a date
        </button>
        <button type="button"
          onclick={() => useDatePicker = true}
          class="flex-1 py-2 rounded-xl text-sm font-medium border transition-colors"
          style={useDatePicker
            ? 'background: hsl(234 40% 97%); border-color: hsl(234 26% 41%); color: hsl(234 26% 41%)'
            : 'border-color: hsl(234 20% 88%); color: hsl(234 12% 52%)'}
        >
          Let group pick
        </button>
      </div>
    </div>

    {#if !useDatePicker}
      <div class="grid grid-cols-2 gap-3">
        <div class="flex flex-col gap-1.5">
          <label for="date" class="text-sm font-medium text-foreground">Date <span class="text-destructive">*</span></label>
          <input id="date" type="date" bind:value={eventDate}
            class="w-full px-3 py-2.5 rounded-xl border border-input bg-background text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-ring transition" />
        </div>
        <div class="flex flex-col gap-1.5">
          <label for="time" class="text-sm font-medium text-foreground">Time</label>
          <input id="time" type="time" bind:value={eventTime}
            class="w-full px-3 py-2.5 rounded-xl border border-input bg-background text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-ring transition" />
        </div>
      </div>

    {:else}
      <!-- Availability picker -->
      <div class="flex flex-col gap-2">
        <label class="text-sm font-medium text-foreground">Candidate dates (2–5)</label>
        {#each candidateDates as _, i}
          <div class="flex gap-2 items-center">
            <input type="datetime-local" bind:value={candidateDates[i]}
              class="flex-1 px-3 py-2.5 rounded-xl border border-input bg-background text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-ring transition" />
            {#if candidateDates.length > 2}
              <button type="button" onclick={() => removeCandidateDate(i)}
                class="p-2 rounded-lg hover:bg-muted transition-colors"
                style="color: hsl(234 12% 52%)">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                  <line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
                </svg>
              </button>
            {/if}
          </div>
        {/each}
        {#if candidateDates.length < 5}
          <button type="button" onclick={addCandidateDate}
            class="text-sm font-medium text-left mt-1"
            style="color: hsl(234 26% 41%)">
            + Add another date
          </button>
        {/if}
      </div>

      <div class="flex flex-col gap-1.5">
        <label for="deadline" class="text-sm font-medium text-foreground">Response deadline <span class="text-muted-foreground font-normal">(optional — defaults to 3 days)</span></label>
        <input id="deadline" type="datetime-local" bind:value={responseDeadline}
          class="w-full px-3 py-2.5 rounded-xl border border-input bg-background text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-ring transition" />
      </div>
    {/if}

    {#if error}
      <p class="text-sm text-destructive">{error}</p>
    {/if}

    <button type="submit" disabled={loading}
      class="w-full py-2.5 rounded-xl text-sm font-semibold text-white transition-opacity disabled:opacity-60"
      style="background: hsl(234 26% 41%)">
      {loading ? 'Creating event…' : 'Create event'}
    </button>

  </form>
</div>