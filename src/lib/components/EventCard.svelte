<script>
  let { event, context = 'calendar', onRsvp = () => {} } = $props()

  let isPast = $derived(new Date(event.event_date) < new Date())
  let goingRsvps = $derived((event.rsvps ?? []).filter(r => r.rsvp === 'yes'))
  let visibleAttendees = $derived(goingRsvps.slice(0, 4))
  let extraCount = $derived(Math.max(0, goingRsvps.length - 4))

  function stripeColor(rsvp, past) {
    if (past) return 'hsl(220 9% 82%)'
    if (rsvp === 'yes') return 'hsl(35 100% 62%)'
    if (rsvp === 'maybe') return 'hsl(252 40% 68%)'
    if (rsvp === 'no') return 'hsl(0 68% 70%)'
    return 'hsl(220 9% 82%)'
  }

  function rsvpSelectStyle(rsvp) {
    if (rsvp === 'yes') return 'background: hsl(35 100% 94%); color: hsl(35 80% 30%)'
    if (rsvp === 'maybe') return 'background: hsl(252 40% 93%); color: hsl(252 35% 40%)'
    if (rsvp === 'no') return 'background: hsl(0 68% 93%); color: hsl(0 68% 40%)'
    return 'background: hsl(220 14% 93%); color: hsl(220 9% 50%)'
  }

  function formatTime(dateStr) {
    return new Date(dateStr).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })
  }

  function formatDate(dateStr) {
    return new Date(dateStr).toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' })
  }

  function initials(name) {
    if (!name) return '?'
    return name.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2)
  }

  function handleRsvpChange(e) {
    onRsvp(event.id, e.target.value)
  }
</script>

<div
  id="cal-event-{event.id}"
  class="rounded-xl bg-white flex gap-3 overflow-hidden"
  style={isPast ? 'opacity: 0.6' : ''}
>
  <!-- RSVP stripe -->
  <div class="w-1 rounded-full self-stretch shrink-0 my-3 ml-3" style="background: {stripeColor(event.myRsvp, isPast)}"></div>

  <!-- Content -->
  <div class="flex-1 min-w-0 py-3 flex flex-col gap-1.5">

    <!-- Group label (calendar context only) -->
    {#if context === 'calendar' && event.groups?.name}
      <p class="uppercase font-semibold tracking-widest" style="font-size: 9px; color: hsl(220 9% 55%); letter-spacing: 0.08em">{event.groups.name}</p>
    {/if}

    <!-- Event name -->
    <a
      href="/groups/{event.group_id}/events/{event.id}"
      class="block font-bold hover:underline leading-snug"
      style="font-size: 18px; color: hsl(267.7 52.54% 9%); text-decoration: none;"
      onclick={e => e.stopPropagation()}
    >{event.title}</a>

    <!-- Meta rows -->
    <div class="flex flex-col gap-0.5">
      <p style="font-size: 12px; color: hsl(220 9% 50%)">
        {formatDate(event.event_date)} · {formatTime(event.event_date)}
      </p>
      {#if event.location}
        <p style="font-size: 12px; color: hsl(220 9% 50%)">{event.location}</p>
      {/if}
      {#if event.bringing}
        <p style="font-size: 12px; color: hsl(220 9% 50%)"><span style="color: hsl(220 9% 38%)">Bringing:</span> {event.bringing}</p>
      {/if}
    </div>

    <!-- RSVP row -->
    <div class="flex items-center gap-2 mt-0.5 flex-wrap">
      {#if isPast}
        <span style="font-size: 11px; color: hsl(220 9% 55%)">{goingRsvps.length} attended</span>
      {:else}
        <!-- RSVP select -->
        <div class="relative shrink-0">
          <select
            value={event.myRsvp ?? ''}
            onchange={handleRsvpChange}
            class="appearance-none rounded-lg pr-6 pl-2.5 py-1 font-medium cursor-pointer focus:outline-none border-0"
            style="font-size: 11px; {rsvpSelectStyle(event.myRsvp)}"
          >
            <option value="" selected={!event.myRsvp}>RSVP</option>
            <option value="yes" selected={event.myRsvp === 'yes'}>Going</option>
            <option value="maybe" selected={event.myRsvp === 'maybe'}>Maybe</option>
            <option value="no" selected={event.myRsvp === 'no'}>Can't go</option>
          </select>
          <svg
            class="pointer-events-none absolute right-1.5 top-1/2 -translate-y-1/2"
            width="10" height="10" viewBox="0 0 24 24" fill="none"
            stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"
            style="color: inherit"
          >
            <polyline points="6 9 12 15 18 9"/>
          </svg>
        </div>

        {#if visibleAttendees.length > 0}
          <!-- Divider -->
          <div class="w-px h-4 shrink-0" style="background: hsl(220 14% 88%)"></div>

          <!-- Attendee stack -->
          <div class="flex items-center">
            {#each visibleAttendees as person, i}
              <div
                class="w-[20px] h-[20px] rounded-full flex items-center justify-center text-white border-2 border-white shrink-0 overflow-hidden"
                style="background: hsl(267.7 52.54% 9%); font-size: 7px; font-weight: 700; margin-left: {i > 0 ? '-5px' : '0'}; position: relative; z-index: {10 - i}"
                title={person.display_name ?? person.name}
              >
                {#if person.avatar_url}
                  <img src={person.avatar_url} alt={person.display_name ?? person.name} class="w-full h-full object-cover" />
                {:else}
                  {initials(person.display_name ?? person.name)}
                {/if}
              </div>
            {/each}
            {#if extraCount > 0}
              <div
                class="w-[20px] h-[20px] rounded-full flex items-center justify-center border-2 border-white shrink-0"
                style="background: hsl(220 14% 88%); color: hsl(234 12% 40%); font-size: 7px; font-weight: 700; margin-left: -5px; position: relative; z-index: 5"
              >+{extraCount}</div>
            {/if}
            <span class="ml-1.5" style="font-size: 11px; color: hsl(220 9% 55%)">{goingRsvps.length} going</span>
          </div>
        {/if}
      {/if}
    </div>

  </div>

  <!-- Right photo -->
  {#if event.cover_photo_url}
    <div class="w-24 shrink-0 self-stretch overflow-hidden rounded-r-xl">
      <img src={event.cover_photo_url} alt={event.title} class="w-full h-full object-cover" />
    </div>
  {:else}
    <div class="pr-3"></div>
  {/if}

</div>
