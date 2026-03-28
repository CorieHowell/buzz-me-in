<script>
  import { supabase } from '$lib/supabase'
  import { onMount, getContext } from 'svelte'
  import { goto } from '$app/navigation'
  import EventCard from '$lib/components/EventCard.svelte'

  const appContext = getContext('appContext')
  const { openCalSync } = appContext
  let myGroups = $derived(appContext.myGroups)

  let selectedGroupId = $state(null)
  let filteredEvents = $derived(
    selectedGroupId === null
      ? upcomingEvents
      : upcomingEvents.filter(e => e.group_id === selectedGroupId)
  )

  let loading = $state(true)
  let upcomingEvents = $state([])
  let userIsAdmin = $state(false)
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

    if ((events ?? []).length > 0) {
      const eventIds = events.map(e => e.id)
      const { data: myRsvps } = await supabase
        .from('event_rsvps')
        .select('event_id, rsvp')
        .eq('user_id', user.id)
        .in('event_id', eventIds)
      const rsvpMap = Object.fromEntries((myRsvps ?? []).map(r => [r.event_id, r.rsvp]))
      upcomingEvents = events.map(e => ({ ...e, myRsvp: rsvpMap[e.id] ?? null, rsvps: [] }))
    } else {
      upcomingEvents = []
    }
    loading = false
  })

  async function setRsvp(eventId, value) {
    upcomingEvents = upcomingEvents.map(e => e.id === eventId ? { ...e, myRsvp: value || null } : e)
    if (value) {
      await supabase.from('event_rsvps').upsert({ event_id: eventId, user_id: (await supabase.auth.getUser()).data.user.id, rsvp: value }, { onConflict: 'event_id,user_id' })
    } else {
      const uid = (await supabase.auth.getUser()).data.user.id
      await supabase.from('event_rsvps').delete().eq('event_id', eventId).eq('user_id', uid)
    }
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
        eventsByDay.set(d.getDate(), [...(eventsByDay.get(d.getDate()) ?? []), e.myRsvp])
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
        rsvpStates: eventsByDay.get(d) ?? [],
        isToday: d === todayDate,
      })
    }
    return cells
  })

  function separatorLabel(dateStr) {
    const d = new Date(dateStr)
    const today = new Date()
    const tomorrow = new Date(today)
    tomorrow.setDate(today.getDate() + 1)
    const isSameDay = (a, b) => a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate()
    if (isSameDay(d, today)) return `Today, ${d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}`
    if (isSameDay(d, tomorrow)) return `Tomorrow, ${d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}`
    return d.toLocaleDateString('en-US', { weekday: 'long', month: 'short', day: 'numeric' })
  }

  function rsvpDotColor(rsvpState) {
    if (rsvpState === 'yes') return 'hsl(35 100% 62%)'
    if (rsvpState === 'maybe') return 'hsl(252 40% 68%)'
    if (rsvpState === 'no') return 'hsl(0 68% 70%)'
    return 'hsl(220 9% 75%)'
  }


</script>

<div class="flex flex-col h-full bg-background">

  <!-- Page header -->
  <header class="shrink-0 flex items-center justify-between px-6 py-5 bg-background border-b border-border">
    <h1 class="text-3xl font-black tracking-tight" style="color: hsl(267.7 52.54% 9%)">Calendar</h1>
    <button
      onclick={openCalSync}
      class="flex items-center gap-2 px-4 py-2 rounded-full text-sm font-medium text-foreground hover:bg-muted transition-colors"
    >
      <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        <path d="M21.5 2v6h-6M2.5 22v-6h6M2 11.5a10 10 0 0 1 18.8-4.3M22 12.5a10 10 0 0 1-18.8 4.2"/>
      </svg>
      Sync with calendar app
    </button>
  </header>

  <!-- Two-column body -->
  <div class="flex flex-1 overflow-hidden">

    <!-- Left: mini calendar (sticky) -->
    <div class="w-96 shrink-0 bg-white border-r border-border flex flex-col">
      {#if !loading}
        <!-- Scrollable calendar area -->
        <div class="flex-1 overflow-y-auto px-6 py-6">
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
          <div class="grid grid-cols-7 gap-y-1">
            {#each calendarCells as cell}
              {#if cell === null}
                <div class="h-10"></div>
              {:else}
                <div
                  class="relative flex items-center justify-center h-10 select-none {cell.hasEvent ? 'cursor-pointer' : 'cursor-default'}"
                  onclick={() => cell.hasEvent && scrollToDay(cell.day)}
                >
                  <div class="flex items-center justify-center w-7 h-7 rounded-full transition-colors {cell.hasEvent && !cell.isToday ? 'hover:bg-purple-50' : ''}"
                    style="font-size: 13px; {cell.isToday
                      ? 'background: hsl(267.7 52.54% 9%); color: white; font-weight: 700'
                      : cell.hasEvent
                        ? 'font-weight: 600; color: hsl(267.7 52.54% 9%)'
                        : 'color: hsl(234 12% 45%)'}"
                  >{cell.day}</div>
                  {#if cell.rsvpStates.length > 0 && !cell.isToday}
                    <div class="absolute bottom-1 left-1/2 -translate-x-1/2 flex gap-0.5">
                      {#each cell.rsvpStates.slice(0, 3) as rsvp}
                        <span class="w-1 h-1 rounded-full" style="background: {rsvpDotColor(rsvp)}"></span>
                      {/each}
                    </div>
                  {/if}
                </div>
              {/if}
            {/each}
          </div>
        </div>

        <!-- RSVP legend — anchored to bottom -->
        <div class="shrink-0 px-6 py-4 flex flex-col gap-2">
          {#each [{ color: rsvpDotColor('yes'), label: 'Going' }, { color: rsvpDotColor('maybe'), label: 'Maybe' }, { color: rsvpDotColor(null), label: 'No RSVP' }] as item}
            <div class="flex items-center gap-2">
              <div class="w-2 h-2 rounded-full shrink-0" style="background: {item.color}"></div>
              <span class="text-xs text-muted-foreground">{item.label}</span>
            </div>
          {/each}
        </div>
      {/if}
    </div>

    <!-- Right: event cards (scrollable) -->
    <div class="flex-1 flex flex-col overflow-hidden" style="background: hsl(220 14% 95%)">

      <!-- Sticky group filter pills -->
      <div class="shrink-0 flex items-center gap-2 px-6 py-3 overflow-x-auto no-scrollbar border-b" style="background: hsl(220 14% 95%); border-color: rgba(0,0,0,0.06)">
        <button
          onclick={() => selectedGroupId = null}
          class="shrink-0 px-2.5 py-1 rounded-full text-xs font-medium transition-colors"
          style={selectedGroupId === null
            ? 'background: hsl(267.7 52.54% 9%); color: white'
            : 'background: white; color: hsl(234 20% 30%)'}
        >All</button>
        {#each myGroups as group}
          <button
            onclick={() => selectedGroupId = group.id}
            class="shrink-0 px-2.5 py-1 rounded-full text-xs font-medium transition-colors"
            style={selectedGroupId === group.id
              ? 'background: hsl(267.7 52.54% 9%); color: white'
              : 'background: white; color: hsl(234 20% 30%)'}
          >{group.name}</button>
        {/each}
      </div>

      <!-- Scrollable cards -->
      <div class="flex-1 overflow-y-auto px-6 py-5 flex flex-col gap-3">

        {#if loading}
          {#each [1,2,3] as _}
            <div class="rounded-xl p-4 animate-pulse bg-white">
              <div class="h-3 bg-muted rounded w-1/3 mb-3"></div>
              <div class="h-4 bg-muted rounded w-2/3"></div>
            </div>
          {/each}

        {:else if filteredEvents.length === 0}
          <div class="py-12 flex flex-col items-center text-center">
            <div class="w-16 h-16 rounded-full bg-white flex items-center justify-center mb-3">
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
              <a href="/groups" class="px-4 py-2 rounded-lg text-xs font-semibold text-white" style="background: hsl(267.7 52.54% 9%)">Create an Event</a>
            {:else}
              <a href="/groups/new" class="px-4 py-2 rounded-lg text-xs font-semibold text-white" style="background: hsl(267.7 52.54% 9%)">Create a Group to Start</a>
            {/if}
          </div>

        {:else}
          {#each filteredEvents as event, i}
            {@const prevDate = i > 0 ? new Date(filteredEvents[i - 1].event_date).toDateString() : null}
            {@const thisDate = new Date(event.event_date).toDateString()}
            {#if thisDate !== prevDate}
              <div class="flex items-center gap-3 {i > 0 ? 'mt-2' : ''}">
                <span class="shrink-0 font-semibold" style="font-size: 11px; color: hsl(220 9% 55%)">{separatorLabel(event.event_date)}</span>
                <div class="flex-1 h-px" style="background: hsl(220 14% 88%)"></div>
              </div>
            {/if}
            <EventCard {event} context="calendar" onRsvp={setRsvp} />
          {/each}
        {/if}

      </div>
    </div>

  </div>
</div>
