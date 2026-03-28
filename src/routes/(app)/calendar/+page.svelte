<script>
  import { supabase } from '$lib/supabase'
  import { onMount, getContext } from 'svelte'
  import { fly } from 'svelte/transition'
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
  let navDirection = $state('next')
  let isMobile = $state(false)

  const DAYS = ['SU', 'MO', 'TU', 'WE', 'TH', 'FR', 'SA']
  const MONTHS = ['January', 'February', 'March', 'April', 'May', 'June',
                  'July', 'August', 'September', 'October', 'November', 'December']

  onMount(async () => {
    const mq = window.matchMedia('(max-width: 767px)')
    isMobile = mq.matches
    mq.addEventListener('change', e => { isMobile = e.matches })

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

    const { data: events } = await supabase
      .from('events')
      .select('id, title, event_date, location, cover_photo_url, group_id, groups(name)')
      .in('group_id', groupIds)
      .gte('event_date', now)
      .order('event_date', { ascending: true })
      .limit(100)

    if ((events ?? []).length > 0) {
      const eventIds = events.map(e => e.id)
      const { data: myRsvps } = await supabase
        .from('event_rsvps')
        .select('event_id, status')
        .eq('user_id', user.id)
        .in('event_id', eventIds)
      const rsvpMap = Object.fromEntries((myRsvps ?? []).map(r => [r.event_id, dbToCode(r.status)]))
      upcomingEvents = events.map(e => ({ ...e, myRsvp: rsvpMap[e.id] ?? null, rsvps: [] }))
    } else {
      upcomingEvents = []
    }
    loading = false
  })

  function dbToCode(status) {
    if (status === 'going') return 'yes'
    if (status === 'not_going') return 'no'
    return status // 'maybe' stays as-is
  }

  function codeToDb(code) {
    if (code === 'yes') return 'going'
    if (code === 'no') return 'not_going'
    return code // 'maybe' stays as-is
  }

  async function setRsvp(eventId, value) {
    upcomingEvents = upcomingEvents.map(e => e.id === eventId ? { ...e, myRsvp: value || null } : e)
    const uid = (await supabase.auth.getUser()).data.user.id
    if (value) {
      await supabase.from('event_rsvps').upsert({ event_id: eventId, user_id: uid, status: codeToDb(value) }, { onConflict: 'event_id,user_id' })
    } else {
      await supabase.from('event_rsvps').delete().eq('event_id', eventId).eq('user_id', uid)
    }
  }

  function scrollToDay(day, year, month) {
    const event = upcomingEvents.find(e => {
      const d = new Date(e.event_date)
      return d.getFullYear() === year && d.getMonth() === month && d.getDate() === day
    })
    if (!event) return
    const el = document.getElementById(`cal-event-${event.id}`)
    if (el) el.scrollIntoView({ behavior: 'smooth', block: 'start' })
  }

  let calendarCollapsed = $state(false)
  let weekNavDirection = $state('next')
  let weekStartDate = $state((() => {
    const d = new Date()
    d.setDate(d.getDate() - d.getDay())
    d.setHours(0, 0, 0, 0)
    return d
  })())

  function prevWeek() {
    weekNavDirection = 'prev'
    const d = new Date(weekStartDate)
    d.setDate(d.getDate() - 7)
    weekStartDate = d
  }

  function nextWeek() {
    weekNavDirection = 'next'
    const d = new Date(weekStartDate)
    d.setDate(d.getDate() + 7)
    weekStartDate = d
  }

  let weekCells = $derived.by(() => {
    const today = new Date()
    const cells = []
    for (let i = 0; i < 7; i++) {
      const d = new Date(weekStartDate)
      d.setDate(weekStartDate.getDate() + i)
      const year = d.getFullYear()
      const month = d.getMonth()
      const day = d.getDate()
      const dayEvents = upcomingEvents.filter(e => {
        const ed = new Date(e.event_date)
        return ed.getFullYear() === year && ed.getMonth() === month && ed.getDate() === day
      })
      cells.push({
        day, month, year,
        hasEvent: dayEvents.length > 0,
        rsvpStates: dayEvents.map(e => e.myRsvp),
        isToday: day === today.getDate() && month === today.getMonth() && year === today.getFullYear(),
      })
    }
    return cells
  })

  function prevMonth() {
    navDirection = 'prev'
    if (calendarMonth === 0) { calendarMonth = 11; calendarYear-- }
    else calendarMonth--
  }

  function nextMonth() {
    navDirection = 'next'
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

  // Thursday of the week gives the "dominant" month when a week spans two
  let weekDisplayTitle = $derived.by(() => {
    const d = new Date(weekStartDate)
    d.setDate(weekStartDate.getDate() + 3)
    return `${MONTHS[d.getMonth()]} ${d.getFullYear()}`
  })

  function rsvpDotColor(rsvpState) {
    if (rsvpState === 'yes') return 'hsl(35 100% 62%)'
    if (rsvpState === 'maybe') return 'hsl(252 40% 68%)'
    if (rsvpState === 'no') return 'hsl(355 68% 73%)'
    return 'hsl(220 9% 75%)'
  }


</script>

<div class="flex flex-col flex-1 min-h-0 bg-background">

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
      <span class="hidden md:inline">Sync with calendar app</span>
      <span class="md:hidden">Sync</span>
    </button>
  </header>

  <!-- Body: stacks on mobile, side-by-side on desktop -->
  <div class="flex flex-col md:flex-row flex-1 overflow-hidden min-h-0">

    <!-- Calendar panel -->
    <div class="shrink-0 md:flex-[2] md:min-w-0 bg-white border-b md:border-b-0 md:border-r border-border flex flex-col">
      {#if !loading}
        <!-- Calendar content -->
        <div class="px-6 py-3 md:px-8 md:py-6">
          <!-- Month heading + nav -->
          <div class="flex items-center justify-between mb-3 md:mb-6">
            <h2 class="text-2xl font-bold tracking-tight" style="color: hsl(267.7 52.54% 9%)">{calendarCollapsed ? weekDisplayTitle : `${MONTHS[calendarMonth]} ${calendarYear}`}</h2>
            <div class="flex items-center gap-1">
              {#if calendarCollapsed}
                <button onclick={prevWeek} class="p-1.5 rounded hover:bg-muted transition-colors text-muted-foreground" aria-label="Previous week">
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                    <polyline points="15 18 9 12 15 6"/>
                  </svg>
                </button>
                <button onclick={nextWeek} class="p-1.5 rounded hover:bg-muted transition-colors text-muted-foreground" aria-label="Next week">
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                    <polyline points="9 18 15 12 9 6"/>
                  </svg>
                </button>
              {:else}
                <button onclick={prevMonth} class="p-1.5 rounded hover:bg-muted transition-colors text-muted-foreground" aria-label="Previous month">
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                    <polyline points="18 15 12 9 6 15"/>
                  </svg>
                </button>
                <button onclick={nextMonth} class="p-1.5 rounded hover:bg-muted transition-colors text-muted-foreground" aria-label="Next month">
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                    <polyline points="6 9 12 15 18 9"/>
                  </svg>
                </button>
              {/if}
              <button
                onclick={() => calendarCollapsed = !calendarCollapsed}
                class="md:hidden ml-1 px-2.5 py-1 rounded text-xs font-medium transition-colors hover:bg-muted"
                style="color: hsl(234 12% 52%)"
              >{calendarCollapsed ? 'Show' : 'Hide'}</button>
            </div>
          </div>

          <!-- Day headers -->
          <div class="grid grid-cols-7 mb-1 md:mb-2">
            {#each DAYS as d}
              <div class="text-center font-bold uppercase tracking-widest pb-1 md:pb-2" style="font-size: 10px; color: hsl(234 12% 62%)">{d}</div>
            {/each}
          </div>

          <!-- Cells -->
          <div class="overflow-hidden">
            {#if calendarCollapsed}
              <!-- Week view -->
              {#key weekStartDate.getTime()}
                <div
                  in:fly={{ x: isMobile ? 0 : (weekNavDirection === 'next' ? 80 : -80), duration: isMobile ? 0 : 250, opacity: isMobile ? 1 : 0 }}
                  out:fly={{ x: isMobile ? 0 : (weekNavDirection === 'next' ? -80 : 80), duration: isMobile ? 0 : 250, opacity: isMobile ? 1 : 0 }}
                >
                  <div class="grid grid-cols-7">
                    {#each weekCells as cell}
                      <div
                        class="relative flex items-center justify-center h-10 md:h-14 select-none {cell.hasEvent ? 'cursor-pointer' : 'cursor-default'}"
                        onclick={() => cell.hasEvent && scrollToDay(cell.day, cell.year, cell.month)}
                      >
                        <div class="flex items-center justify-center w-9 h-9 rounded-full transition-colors {cell.hasEvent && !cell.isToday ? 'hover:bg-purple-50' : ''}"
                          style="font-size: 15px; {cell.isToday
                            ? 'background: hsl(267.7 52.54% 9%); color: white; font-weight: 800'
                            : cell.hasEvent
                              ? 'font-weight: 700; color: hsl(267.7 52.54% 9%)'
                              : 'color: hsl(234 12% 55%)'}"
                        >{cell.day}</div>
                        {#if cell.rsvpStates.length > 0 && !cell.isToday}
                          <div class="absolute bottom-1.5 left-1/2 -translate-x-1/2 flex gap-1">
                            {#each cell.rsvpStates.slice(0, 3) as rsvp}
                              <span class="w-1.5 h-1.5 rounded-full" style="background: {rsvpDotColor(rsvp)}"></span>
                            {/each}
                          </div>
                        {/if}
                      </div>
                    {/each}
                  </div>
                </div>
              {/key}
            {:else}
              <!-- Full month (animated) -->
              {#key `${calendarYear}-${calendarMonth}`}
                <div
                  in:fly={{ y: isMobile ? 0 : (navDirection === 'next' ? 60 : -60), duration: isMobile ? 0 : 300, opacity: isMobile ? 1 : 0 }}
                  out:fly={{ y: isMobile ? 0 : (navDirection === 'next' ? -60 : 60), duration: isMobile ? 0 : 300, opacity: isMobile ? 1 : 0 }}
                >
                  <div class="grid grid-cols-7">
                    {#each calendarCells as cell}
                      {#if cell === null}
                        <div class="h-10 md:h-14"></div>
                      {:else}
                        <div
                          class="relative flex items-center justify-center h-10 md:h-14 select-none {cell.hasEvent ? 'cursor-pointer' : 'cursor-default'}"
                          onclick={() => cell.hasEvent && scrollToDay(cell.day, calendarYear, calendarMonth)}
                        >
                          <div class="flex items-center justify-center w-9 h-9 rounded-full transition-colors {cell.hasEvent && !cell.isToday ? 'hover:bg-purple-50' : ''}"
                            style="font-size: 15px; {cell.isToday
                              ? 'background: hsl(267.7 52.54% 9%); color: white; font-weight: 800'
                              : cell.hasEvent
                                ? 'font-weight: 700; color: hsl(267.7 52.54% 9%)'
                                : 'color: hsl(234 12% 55%)'}"
                          >{cell.day}</div>
                          {#if cell.rsvpStates.length > 0 && !cell.isToday}
                            <div class="absolute bottom-1.5 left-1/2 -translate-x-1/2 flex gap-1">
                              {#each cell.rsvpStates.slice(0, 3) as rsvp}
                                <span class="w-1.5 h-1.5 rounded-full" style="background: {rsvpDotColor(rsvp)}"></span>
                              {/each}
                            </div>
                          {/if}
                        </div>
                      {/if}
                    {/each}
                  </div>
                </div>
              {/key}
            {/if}
          </div>
        </div>

        <!-- RSVP legend (hidden on mobile when collapsed; sticky to bottom on desktop) -->
        <div class="shrink-0 px-6 md:px-8 py-4 md:mt-auto items-center gap-6 {calendarCollapsed ? 'hidden md:flex' : 'flex'}">
          {#each [{ color: rsvpDotColor('yes'), label: 'Going' }, { color: rsvpDotColor('maybe'), label: 'Maybe' }, { color: rsvpDotColor('no'), label: "Can't go" }, { color: rsvpDotColor(null), label: 'No RSVP' }] as item}
            <div class="flex items-center gap-2">
              <div class="w-2 h-2 rounded-full shrink-0" style="background: {item.color}"></div>
              <span class="text-xs text-muted-foreground">{item.label}</span>
            </div>
          {/each}
        </div>
      {/if}
    </div>

    <!-- Right: event cards (scrollable) -->
    <div class="flex-1 md:flex-[3] flex flex-col overflow-hidden min-h-0" style="background: hsl(220 14% 95%)">

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
      <div class="flex-1 min-h-0 overflow-y-auto px-6 pt-5 pb-24 md:pb-5">

        {#if loading}
          {#each [1,2,3] as _}
            <div class="rounded-xl p-4 animate-pulse bg-white mb-3">
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
            <p class="text-xs text-muted-foreground mb-4 max-w-[220px]">You don't have any upcoming events.</p>
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
              <div class="flex items-center gap-3 {i > 0 ? 'mt-4' : ''} mb-3">
                <span class="shrink-0 font-semibold" style="font-size: 11px; color: hsl(220 9% 55%)">{separatorLabel(event.event_date)}</span>
                <div class="flex-1 h-px" style="background: hsl(220 14% 88%)"></div>
              </div>
            {/if}
            <div class="mb-3">
              <EventCard {event} context="calendar" onRsvp={setRsvp} />
            </div>
          {/each}
        {/if}

      </div>
    </div>

  </div>
</div>
