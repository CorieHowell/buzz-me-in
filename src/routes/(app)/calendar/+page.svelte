<script>
  import { supabase } from '$lib/supabase'
  import { onMount } from 'svelte'
  import { goto } from '$app/navigation'

  let loading = $state(true)
  let upcomingEvents = $state([])
  let userIsAdmin = $state(false)
  let rsvpDropdownId = $state(null)
  let calendarYear = $state(new Date().getFullYear())
  let calendarMonth = $state(new Date().getMonth())

  const DAYS = ['SU', 'MO', 'TU', 'WE', 'TH', 'FR', 'SA']
  const MONTHS = ['January', 'February', 'March', 'April', 'May', 'June',
                  'July', 'August', 'September', 'October', 'November', 'December']

  onMount(async () => {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return

    const { data: memberships } = await supabase
      .from('group_members')
      .select('group_id, role')
      .eq('user_id', user.id)

    const groupIds = memberships?.map(m => m.group_id) ?? []
    userIsAdmin = memberships?.some(m => m.role === 'admin' || m.role === 'co_admin') ?? false

    if (groupIds.length === 0) {
      loading = false
      return
    }

    const now = new Date().toISOString()
    const in90 = new Date(Date.now() + 90 * 24 * 60 * 60 * 1000).toISOString()

    const { data: events } = await supabase
      .from('events')
      .select('id, title, event_date, location, cover_photo_url, group_id, groups(name)')
      .in('group_id', groupIds)
      .eq('status', 'confirmed')
      .gte('event_date', now)
      .lte('event_date', in90)
      .order('event_date', { ascending: true })
      .limit(20)

    upcomingEvents = events ?? []
    loading = false
  })

  function setRsvp(eventId, value) {
    upcomingEvents = upcomingEvents.map(e => e.id === eventId ? { ...e, myRsvp: value } : e)
    rsvpDropdownId = null
  }

  function scrollToDay(day) {
    const event = upcomingEvents.find(e => {
      const d = new Date(e.event_date)
      return d.getFullYear() === calendarYear && d.getMonth() === calendarMonth && d.getDate() === day
    })
    if (!event) return
    const el = document.getElementById(`cal-event-${event.id}`)
    if (el) el.scrollIntoView({ behavior: 'smooth', block: 'start' })
  }

  function prevMonth() {
    if (calendarMonth === 0) { calendarMonth = 11; calendarYear-- }
    else calendarMonth--
  }

  function nextMonth() {
    if (calendarMonth === 11) { calendarMonth = 0; calendarYear++ }
    else calendarMonth++
  }

  let calendarCells = $derived.by(() => {
    const firstDay = new Date(calendarYear, calendarMonth, 1).getDay()
    const daysInMonth = new Date(calendarYear, calendarMonth + 1, 0).getDate()

    const eventsByDay = new Map()
    upcomingEvents.forEach(e => {
      const d = new Date(e.event_date)
      if (d.getFullYear() === calendarYear && d.getMonth() === calendarMonth) {
        eventsByDay.set(d.getDate(), e.myRsvp)
      }
    })

    const today = new Date()
    const isCurrentMonth = today.getFullYear() === calendarYear && today.getMonth() === calendarMonth
    const todayDate = isCurrentMonth ? today.getDate() : -1

    const cells = []
    for (let i = 0; i < firstDay; i++) cells.push(null)
    for (let d = 1; d <= daysInMonth; d++) {
      cells.push({
        day: d,
        hasEvent: eventsByDay.has(d),
        rsvpState: eventsByDay.get(d) ?? null,
        isToday: d === todayDate,
      })
    }
    return cells
  })

  function rsvpDotColor(rsvpState) {
    if (rsvpState === 'yes') return 'hsl(35 100% 55%)'
    if (rsvpState === 'maybe') return 'hsl(355 68% 62%)'
    return 'hsl(220 9% 65%)'
  }

  function formatEventDateTime(dateStr) {
    const d = new Date(dateStr)
    const date = d.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' })
    const time = d.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })
    return `${date} @ ${time}`
  }

  function initials(name) {
    if (!name) return '?'
    return name.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2)
  }
</script>

<div class="px-6 py-6 md:px-10 md:py-8 bg-background min-h-full">

  <h1 class="text-xl font-semibold text-foreground mb-6">Calendar</h1>

  {#if loading}
    <div class="flex flex-col gap-3">
      {#each [1,2,3] as _}
        <div class="rounded-xl p-4 animate-pulse bg-white border border-border">
          <div class="h-3 bg-muted rounded w-1/3 mb-3"></div>
          <div class="h-4 bg-muted rounded w-2/3"></div>
        </div>
      {/each}
    </div>

  {:else}
    <div class="flex flex-col md:flex-row gap-8 md:items-start">

      <!-- Calendar grid (left / top) -->
      <div class="md:w-72 shrink-0">
        <!-- Month nav -->
        <div class="flex items-center justify-between mb-2">
          <button onclick={prevMonth} class="p-1 rounded hover:bg-muted transition-colors text-muted-foreground">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
              <polyline points="15 18 9 12 15 6"/>
            </svg>
          </button>
          <span class="text-sm font-semibold text-foreground">{MONTHS[calendarMonth]} {calendarYear}</span>
          <button onclick={nextMonth} class="p-1 rounded hover:bg-muted transition-colors text-muted-foreground">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
              <polyline points="9 18 15 12 9 6"/>
            </svg>
          </button>
        </div>

        <!-- Day headers -->
        <div class="grid grid-cols-7 mb-1">
          {#each DAYS as d}
            <div class="text-center font-semibold uppercase tracking-wider py-1" style="font-size: 9px; color: hsl(234 12% 72%)">{d}</div>
          {/each}
        </div>

        <!-- Calendar cells -->
        <div class="grid grid-cols-7">
          {#each calendarCells as cell}
            {#if cell === null}
              <div class="h-8"></div>
            {:else}
              <div
                class="relative flex items-center justify-center h-8 select-none {cell.hasEvent ? 'cursor-pointer' : 'cursor-default'}"
                onclick={() => cell.hasEvent && scrollToDay(cell.day)}
              >
                <div class="flex items-center justify-center w-6 h-6 rounded-full transition-colors {cell.hasEvent && !cell.isToday ? 'hover:bg-amber-100' : ''}"
                  style="font-size: 12px; {cell.isToday
                    ? 'background: hsl(234 26% 41%); color: white; font-weight: 700'
                    : cell.hasEvent
                      ? 'font-weight: 600; color: hsl(234 26% 41%)'
                      : 'color: hsl(234 12% 45%)'}"
                >{cell.day}</div>
                {#if cell.hasEvent && !cell.isToday}
                  <span class="absolute bottom-0.5 left-1/2 -translate-x-1/2 w-1 h-1 rounded-full"
                    style="background: {rsvpDotColor(cell.rsvpState)}"></span>
                {/if}
              </div>
            {/if}
          {/each}
        </div>

        <!-- RSVP legend -->
        <div class="flex items-center gap-4 mt-4 px-1">
          {#each [{ color: rsvpDotColor('yes'), label: 'Going' }, { color: rsvpDotColor('maybe'), label: 'Maybe' }, { color: rsvpDotColor(null), label: 'No RSVP' }] as item}
            <div class="flex items-center gap-1.5">
              <div class="w-2 h-2 rounded-full shrink-0" style="background: {item.color}"></div>
              <span class="text-xs text-muted-foreground">{item.label}</span>
            </div>
          {/each}
        </div>
      </div>

      <!-- Events list (right / below) -->
      <div class="flex-1 flex flex-col gap-3">
        {#if upcomingEvents.length === 0}
          <div class="py-12 flex flex-col items-center text-center">
            <div class="w-16 h-16 rounded-full bg-muted flex items-center justify-center mb-3">
              <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="hsl(234 12% 72%)" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
                <rect x="3" y="4" width="18" height="18" rx="2" ry="2"/>
                <line x1="16" y1="2" x2="16" y2="6"/>
                <line x1="8" y1="2" x2="8" y2="6"/>
                <line x1="3" y1="10" x2="21" y2="10"/>
              </svg>
            </div>
            <p class="text-sm font-semibold text-foreground mb-1">No upcoming events</p>
            <p class="text-xs text-muted-foreground mb-4 max-w-[220px]">You don't have any confirmed events in the next 90 days.</p>
            {#if userIsAdmin}
              <a href="/groups" class="px-4 py-2 rounded-lg text-xs font-semibold text-white" style="background: hsl(234 26% 41%)">
                Create an Event
              </a>
            {:else}
              <a href="/groups/new" class="px-4 py-2 rounded-lg text-xs font-semibold text-white" style="background: hsl(234 26% 41%)">
                Create a Group to Start
              </a>
            {/if}
          </div>

        {:else}
          {#each upcomingEvents as event}
            {@const visibleRsvps = (event.rsvps ?? []).slice(0, 5)}
            {@const extraRsvps = Math.max(0, (event.rsvps ?? []).length - 5)}
            <div id="cal-event-{event.id}" class="bg-white rounded-xl border border-border/60">
              <div class="p-4">

                <!-- Title/date + circle avatar -->
                <div class="flex items-center gap-3 mb-2.5">
                  <div class="flex-1 min-w-0">
                    <a href="/groups/{event.group_id}/events/{event.id}"
                      class="text-sm font-semibold text-foreground hover:underline leading-snug block truncate">
                      {event.title}
                    </a>
                    <p class="text-xs text-muted-foreground mt-0.5">{formatEventDateTime(event.event_date)}</p>
                  </div>
                  <div class="w-11 h-11 rounded-full shrink-0 overflow-hidden" style="background: hsl(220 14% 93%)">
                    {#if event.cover_photo_url}
                      <img src={event.cover_photo_url} alt={event.title} class="w-full h-full object-cover" />
                    {:else}
                      <div class="w-full h-full flex flex-col items-center justify-center gap-0 select-none">
                        <span class="font-semibold uppercase tracking-widest leading-none" style="font-size: 8px; color: hsl(220 9% 65%)">{new Date(event.event_date).toLocaleDateString('en-US', { month: 'short' })}</span>
                        <span class="font-bold leading-none mt-0.5" style="font-size: 1.25rem; color: hsl(220 9% 50%)">{new Date(event.event_date).getDate()}</span>
                      </div>
                    {/if}
                  </div>
                </div>

                <!-- Meta: group + location -->
                <div class="flex flex-col gap-1.5 mb-3">
                  <div class="flex items-center gap-1.5">
                    <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="hsl(234 12% 80%)" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                      <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/>
                      <path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>
                    </svg>
                    <span class="text-xs text-muted-foreground">{event.groups?.name}</span>
                  </div>
                  {#if event.location}
                    <div class="flex items-center gap-1.5">
                      <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="hsl(234 12% 80%)" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                        <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/>
                        <circle cx="12" cy="10" r="3"/>
                      </svg>
                      <span class="text-xs text-muted-foreground truncate">{event.location}</span>
                    </div>
                  {/if}
                </div>

                <!-- Bottom row: RSVP | avatars -->
                <div class="flex items-center gap-2.5">
                  <div class="relative shrink-0">
                    <button
                      onclick={() => rsvpDropdownId = rsvpDropdownId === event.id ? null : event.id}
                      class="flex items-center justify-center gap-1.5 py-1.5 rounded-lg text-xs font-semibold transition-colors whitespace-nowrap w-20"
                      style={event.myRsvp === 'yes'
                        ? 'background: hsl(35 100% 93%); color: hsl(35 80% 32%)'
                        : event.myRsvp === 'maybe'
                          ? 'background: hsl(355 68% 93%); color: hsl(355 68% 38%)'
                          : 'background: hsl(220 14% 93%); color: hsl(220 9% 46%)'}
                    >
                      {#if event.myRsvp === 'yes'}
                        <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>
                        Going
                      {:else if event.myRsvp === 'maybe'}
                        <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/><circle cx="5" cy="12" r="1"/></svg>
                        Maybe
                      {:else}
                        RSVP
                      {/if}
                      <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="6 9 12 15 18 9"/></svg>
                    </button>

                    {#if rsvpDropdownId === event.id}
                      <button class="fixed inset-0 z-40 cursor-default" onclick={() => rsvpDropdownId = null} tabindex="-1" aria-hidden="true"></button>
                      <div class="absolute left-0 bottom-full mb-1 w-32 bg-white rounded-lg border border-border py-1 z-50"
                        style="box-shadow: 0 4px 16px rgba(0,0,0,0.12)">
                        <button onclick={() => setRsvp(event.id, 'yes')} class="w-full flex items-center gap-2 px-3 py-2 text-xs text-left hover:bg-gray-50 transition-colors" style={event.myRsvp === 'yes' ? 'color: hsl(35 80% 32%); font-weight: 600' : 'color: hsl(234 20% 30%)'}>
                          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>
                          Going
                        </button>
                        <button onclick={() => setRsvp(event.id, 'maybe')} class="w-full flex items-center gap-2 px-3 py-2 text-xs text-left hover:bg-gray-50 transition-colors" style={event.myRsvp === 'maybe' ? 'color: hsl(355 68% 38%); font-weight: 600' : 'color: hsl(234 20% 30%)'}>
                          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/><circle cx="5" cy="12" r="1"/></svg>
                          Maybe
                        </button>
                        <button onclick={() => setRsvp(event.id, 'no')} class="w-full flex items-center gap-2 px-3 py-2 text-xs text-left hover:bg-gray-50 transition-colors" style={event.myRsvp === 'no' ? 'color: hsl(0 72% 51%); font-weight: 600' : 'color: hsl(234 20% 30%)'}>
                          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
                          Can't go
                        </button>
                      </div>
                    {/if}
                  </div>

                  {#if visibleRsvps.length > 0}
                    <div class="w-px h-4 shrink-0" style="background: hsl(220 14% 88%)"></div>
                    <div class="flex items-center">
                      {#each visibleRsvps as person, i}
                        <div
                          class="w-6 h-6 rounded-full flex items-center justify-center text-white border-2 border-white shrink-0 overflow-hidden"
                          style="background: hsl(234 26% 41%); font-size: 8px; font-weight: 700; margin-left: {i > 0 ? '-6px' : '0'}; z-index: {10 - i}; position: relative;"
                          title={person.name}
                        >
                          {#if person.avatar_url}
                            <img src={person.avatar_url} alt={person.name} class="w-full h-full object-cover" />
                          {:else}
                            {initials(person.name)}
                          {/if}
                        </div>
                      {/each}
                      {#if extraRsvps > 0}
                        <div
                          class="w-6 h-6 rounded-full flex items-center justify-center border-2 border-white shrink-0"
                          style="background: hsl(220 14% 88%); color: hsl(234 12% 40%); font-size: 8px; font-weight: 700; margin-left: -6px; position: relative; z-index: 5"
                        >+{extraRsvps}</div>
                      {/if}
                    </div>
                  {/if}
                </div>

              </div>
            </div>
          {/each}
        {/if}
      </div>

    </div>
  {/if}

</div>
