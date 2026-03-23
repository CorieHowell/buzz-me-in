<script>
  import { supabase } from '$lib/supabase'
  import { onMount } from 'svelte'
  import { goto } from '$app/navigation'

  let loading = $state(true)
  let feedItems = $state([])
  let upcomingEvents = $state([])
  let userName = $state('')
  let userIsAdmin = $state(false)
  let rsvpDropdownId = $state(null)
  let feedRsvpDropdownId = $state(null)
  let calendarYear = $state(new Date().getFullYear())
  let calendarMonth = $state(new Date().getMonth())

  // Feed interactivity
  let expandedPostId = $state(null)
  let replyDrafts = $state({})
  let emojiPickerPostId = $state(null)

  const EMOJI_OPTIONS = ['❤️', '👍', '😂', '😮', '🙌', '🔥']

  function toggleReaction(postId, emoji) {
    feedItems = feedItems.map(item => {
      if (item.id !== postId) return item
      const reactions = item.reactions ?? []
      const existing = reactions.find(r => r.emoji === emoji)
      const myReaction = item.myReaction
      let updated
      if (myReaction === emoji) {
        // Remove reaction
        updated = reactions.map(r => r.emoji === emoji ? { ...r, count: r.count - 1 } : r).filter(r => r.count > 0)
        return { ...item, reactions: updated, myReaction: null }
      } else {
        // Remove old reaction if any
        let base = myReaction
          ? reactions.map(r => r.emoji === myReaction ? { ...r, count: r.count - 1 } : r).filter(r => r.count > 0)
          : reactions
        // Add new
        if (base.find(r => r.emoji === emoji)) {
          updated = base.map(r => r.emoji === emoji ? { ...r, count: r.count + 1 } : r)
        } else {
          updated = [...base, { emoji, count: 1 }]
        }
        return { ...item, reactions: updated, myReaction: emoji }
      }
    })
    emojiPickerPostId = null
  }

  function submitReply(postId) {
    const text = (replyDrafts[postId] ?? '').trim()
    if (!text) return
    feedItems = feedItems.map(item => {
      if (item.id !== postId) return item
      const newReply = { author: userName, avatar: null, body: text, time: new Date().toISOString() }
      return { ...item, replies: [...(item.replies ?? []), newReply], replyCount: (item.replyCount ?? 0) + 1 }
    })
    replyDrafts = { ...replyDrafts, [postId]: '' }
  }

  const DEV_MOCK = true

  onMount(async () => {
    if (DEV_MOCK) {
      userName = 'Corie'
      userIsAdmin = true
      const d1 = new Date(); d1.setDate(d1.getDate() + 2); d1.setHours(19, 0, 0, 0)
      const d2 = new Date(); d2.setDate(d2.getDate() + 5); d2.setHours(8, 30, 0, 0)
      upcomingEvents = [
        {
          id: 'e1',
          title: 'March Book Club',
          event_date: d1.toISOString(),
          location: "Sarah's Place · 123 Elm St",
          group_id: 'g1',
          groups: { name: 'Book Club' },
          cover_photo_url: null,
          myBringItem: 'Lemon bars',
          rsvps: [
            { name: 'Sarah M.', avatar_url: null },
            { name: 'James T.', avatar_url: null },
            { name: 'Priya K.', avatar_url: null },
          ],
          myRsvp: 'yes'
        },
        {
          id: 'e2',
          title: 'Eagle Rock Trail',
          event_date: d2.toISOString(),
          location: 'Trailhead Parking Lot',
          group_id: 'g2',
          groups: { name: 'Hiking Crew' },
          cover_photo_url: null,
          myBringItem: null,
          rsvps: [
            { name: 'Marcus R.', avatar_url: null },
            { name: 'Sarah M.', avatar_url: null },
            { name: 'James T.', avatar_url: null },
            { name: 'Priya K.', avatar_url: null },
            { name: 'Alex W.', avatar_url: null },
            { name: 'Jordan L.', avatar_url: null },
          ],
          myRsvp: null
        },
      ]
      feedItems = [
        {
          type: 'post', id: 'p1', groupName: 'Book Club', groupId: 'g1', author: 'Sarah M.', authorId: 'u1', authorAvatar: null,
          body: "Just finished the last chapter — so good! Can't wait to discuss on Thursday. Anyone bringing snacks?",
          time: new Date(Date.now() - 25 * 60 * 1000).toISOString(),
          reactions: [{ emoji: '❤️', count: 4 }, { emoji: '🙌', count: 2 }], myReaction: '❤️',
          replyCount: 2,
          replies: [
            { author: 'James T.', authorId: 'u3', avatar: null, body: "Me too! I'll bring chips 🍟", time: new Date(Date.now() - 20 * 60 * 1000).toISOString() },
            { author: 'Priya K.', authorId: 'u5', avatar: null, body: "Can't wait to discuss the ending!", time: new Date(Date.now() - 15 * 60 * 1000).toISOString() },
          ],
        },
        {
          type: 'event_created', id: 'ev1', groupName: 'Hiking Crew', groupId: 'g2', author: 'James T.', authorId: 'u3', authorAvatar: null,
          eventTitle: 'Eagle Rock Trail', eventId: 'e2',
          eventDate: new Date(Date.now() + 5 * 24 * 60 * 60 * 1000).setHours(8, 30, 0, 0),
          eventLocation: 'Trailhead Parking Lot',
          eventCoverPhoto: null,
          eventStatus: 'confirmed',
          myRsvp: null,
          time: new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString(),
        },
        {
          type: 'member', id: 'm1', groupName: 'Hiking Crew', groupId: 'g2', author: 'Alex W.', authorId: 'u4', authorAvatar: null,
          time: new Date(Date.now() - 4 * 60 * 60 * 1000).toISOString(),
        },
        {
          type: 'post', id: 'p2', groupName: 'Dinner Club', groupId: 'g3', author: 'Priya K.', authorId: 'u5', authorAvatar: null,
          body: 'Thinking Italian for next month — anyone have a good spot in Silver Lake? Open to suggestions!',
          time: new Date(Date.now() - 18 * 60 * 60 * 1000).toISOString(),
          reactions: [], myReaction: null, replyCount: 0, replies: [],
        },
        {
          type: 'post', id: 'p3', groupName: 'Book Club', groupId: 'g1', author: 'Marcus R.', authorId: 'u6', authorAvatar: null,
          body: "I'm bringing my famous lemon bars 🍋",
          time: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000).toISOString(),
          reactions: [{ emoji: '😂', count: 3 }, { emoji: '❤️', count: 1 }], myReaction: null, replyCount: 1,
          replies: [
            { author: 'Sarah M.', authorId: 'u1', avatar: null, body: 'Yes!! Obsessed with your lemon bars 😍', time: new Date(Date.now() - 23 * 60 * 60 * 1000).toISOString() },
          ],
        },
      ]
      loading = false
      return
    }

    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return

    const { data: profile } = await supabase
      .from('users')
      .select('display_name')
      .eq('id', user.id)
      .single()

    userName = profile?.display_name?.split(' ')[0] ?? 'there'

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
    const in30 = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString()

    const { data: events } = await supabase
      .from('events')
      .select('id, title, event_date, location, cover_photo_url, group_id, groups(name)')
      .in('group_id', groupIds)
      .eq('status', 'confirmed')
      .gte('event_date', now)
      .lte('event_date', in30)
      .order('event_date', { ascending: true })
      .limit(3)

    upcomingEvents = events ?? []

    const weekAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString()

    const { data: posts } = await supabase
      .from('posts')
      .select('id, body, created_at, group_id, user_id, is_deleted, groups(name), users(display_name, avatar_url)')
      .in('group_id', groupIds)
      .eq('is_deleted', false)
      .is('parent_id', null)
      .gte('created_at', weekAgo)
      .order('created_at', { ascending: false })
      .limit(5)

    const { data: newMembers } = await supabase
      .from('group_members')
      .select('joined_at, group_id, user_id, groups(name), users(display_name, avatar_url)')
      .in('group_id', groupIds)
      .gte('joined_at', weekAgo)
      .neq('user_id', user.id)
      .order('joined_at', { ascending: false })
      .limit(5)

    const { data: newEvents } = await supabase
      .from('events')
      .select('id, title, created_at, group_id, host_user_id, groups(name), users(display_name, avatar_url)')
      .in('group_id', groupIds)
      .gte('created_at', weekAgo)
      .order('created_at', { ascending: false })
      .limit(5)

    const postItems = (posts ?? []).map(p => ({
      type: 'post',
      id: p.id,
      groupName: p.groups?.name,
      groupId: p.group_id,
      author: p.users?.display_name,
      authorId: p.user_id,
      authorAvatar: p.users?.avatar_url ?? null,
      body: p.body,
      time: p.created_at,
    }))

    const memberItems = (newMembers ?? []).map(m => ({
      type: 'member',
      id: m.joined_at + m.group_id,
      groupName: m.groups?.name,
      groupId: m.group_id,
      author: m.users?.display_name,
      authorId: m.user_id,
      authorAvatar: m.users?.avatar_url ?? null,
      time: m.joined_at,
    }))

    const eventItems = (newEvents ?? []).map(e => ({
      type: 'event_created',
      id: e.id,
      groupName: e.groups?.name,
      groupId: e.group_id,
      author: e.users?.display_name,
      authorId: e.host_user_id,
      authorAvatar: e.users?.avatar_url ?? null,
      eventTitle: e.title,
      eventId: e.id,
      time: e.created_at,
    }))

    feedItems = [...postItems, ...memberItems, ...eventItems].sort(
      (a, b) => new Date(b.time) - new Date(a.time)
    )

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

  function setFeedRsvp(itemId, value) {
    feedItems = feedItems.map(f => f.id === itemId ? { ...f, myRsvp: value } : f)
    feedRsvpDropdownId = null
  }

  function timeAgo(dateStr) {
    const diff = Date.now() - new Date(dateStr).getTime()
    const mins = Math.floor(diff / 60000)
    const hours = Math.floor(mins / 60)
    const days = Math.floor(hours / 24)
    if (mins < 1) return 'just now'
    if (mins < 60) return `${mins}m ago`
    if (hours < 24) return `${hours}h ago`
    return `${days}d ago`
  }

  function formatEventDateTime(dateStr) {
    const d = new Date(dateStr)
    const date = d.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' })
    const time = d.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })
    return `${date} @ ${time}`
  }

  function truncate(str, n = 120) {
    if (!str) return ''
    return str.length > n ? str.slice(0, n) + '…' : str
  }

  function initials(name) {
    if (!name) return '?'
    return name.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2)
  }

  // Calendar
  const DAYS = ['SU', 'MO', 'TU', 'WE', 'TH', 'FR', 'SA']
  const MONTHS = ['January', 'February', 'March', 'April', 'May', 'June',
                  'July', 'August', 'September', 'October', 'November', 'December']

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

    // Map day → rsvp state for events in this month
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

</script>

<div class="md:h-full md:flex bg-background">
  <div class="flex-1 md:overflow-y-auto">
  <div class="px-10 py-6">

    <!-- Header -->
    <div class="mb-6 flex flex-col justify-center min-h-[180px]">
      <h1 class="text-xl font-semibold text-foreground">Hey {userName} 👋</h1>
      <p class="text-sm text-muted-foreground mt-0.5">Here's what's happening in your groups.</p>
    </div>
    {#if loading}
      <div class="flex flex-col gap-3">
        {#each [1,2,3] as _}
          <div class="rounded-xl p-4 animate-pulse bg-white">
            <div class="h-3 bg-muted rounded w-1/3 mb-3"></div>
            <div class="h-4 bg-muted rounded w-2/3 mb-2"></div>
            <div class="h-3 bg-muted rounded w-1/2"></div>
          </div>
        {/each}
      </div>

    {:else if upcomingEvents.length === 0 && feedItems.length === 0}
      <div class="flex flex-col items-center justify-center text-center py-16 px-4">
        <div class="w-16 h-16 rounded-2xl flex items-center justify-center mb-4" style="background: hsl(234 40% 97%)">
          <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="hsl(234 26% 41%)" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
            <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
            <circle cx="9" cy="7" r="4"/>
            <path d="M23 21v-2a4 4 0 0 0-3-3.87"/>
            <path d="M16 3.13a4 4 0 0 1 0 7.75"/>
          </svg>
        </div>
        <h2 class="text-base font-semibold text-foreground mb-1">No activity yet</h2>
        <p class="text-sm text-muted-foreground mb-6 max-w-xs">Create your first group and invite your people to get started.</p>
        <button onclick={() => goto('/groups/new')} class="px-5 py-2.5 rounded-lg text-sm font-semibold text-white" style="background: hsl(234 26% 41%)">
          Create a group
        </button>
      </div>

    {:else}

      <!-- Mobile: horizontal event card strip -->
      {#if upcomingEvents.length > 0}
        <div class="md:hidden mb-6">
          <h2 class="text-sm font-medium text-muted-foreground mb-4">Upcoming Events</h2>
          <div class="-mx-10 flex gap-3 overflow-x-auto px-10 pb-3 no-scrollbar">
            {#each upcomingEvents as event}
              {@const visibleRsvps = (event.rsvps ?? []).slice(0, 5)}
              {@const extraRsvps = Math.max(0, (event.rsvps ?? []).length - 5)}
              <div class="bg-white rounded-xl p-4 shrink-0 w-[260px] flex flex-col gap-2.5">

                <!-- Title + circle -->
                <div class="flex items-center gap-3">
                  <div class="flex-1 min-w-0">
                    <a href="/groups/{event.group_id}/events/{event.id}"
                      class="text-sm font-semibold text-foreground leading-snug block truncate">
                      {event.title}
                    </a>
                    <p class="text-xs text-muted-foreground mt-0.5">{formatEventDateTime(event.event_date)}</p>
                  </div>
                  <div class="w-10 h-10 rounded-full shrink-0 overflow-hidden border border-border/40" style="background: hsl(220 14% 93%)">
                    {#if event.cover_photo_url}
                      <img src={event.cover_photo_url} alt={event.title} class="w-full h-full object-cover" />
                    {:else}
                      <div class="w-full h-full flex flex-col items-center justify-center gap-0 select-none">
                        <span class="font-semibold uppercase tracking-widest leading-none" style="font-size: 8px; color: hsl(220 9% 65%)">{new Date(event.event_date).toLocaleDateString('en-US', { month: 'short' })}</span>
                        <span class="font-bold leading-none mt-0.5" style="font-size: 1.125rem; color: hsl(220 9% 50%)">{new Date(event.event_date).getDate()}</span>
                      </div>
                    {/if}
                  </div>
                </div>

                <!-- Meta -->
                <div class="flex flex-col gap-1">
                  <div class="flex items-center gap-1.5">
                    <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="hsl(220 9% 72%)" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                      <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/>
                      <path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>
                    </svg>
                    <span class="text-xs text-muted-foreground truncate">{event.groups?.name}</span>
                  </div>
                  {#if event.location}
                    <div class="flex items-center gap-1.5">
                      <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="hsl(220 9% 72%)" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                        <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/>
                        <circle cx="12" cy="10" r="3"/>
                      </svg>
                      <span class="text-xs text-muted-foreground truncate">{event.location}</span>
                    </div>
                  {/if}
                </div>

                <!-- RSVP + avatars -->
                <div class="flex items-center gap-2 mt-auto pt-1">
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
                      <div class="absolute left-0 bottom-full mb-1 w-32 bg-white rounded-lg border border-border py-1 z-50" style="box-shadow: 0 4px 16px rgba(0,0,0,0.12)">
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
                        <div class="w-6 h-6 rounded-full flex items-center justify-center text-white border-2 border-white shrink-0 overflow-hidden"
                          style="background: hsl(234 26% 41%); font-size: 8px; font-weight: 700; margin-left: {i > 0 ? '-6px' : '0'}; z-index: {10 - i}; position: relative;" title={person.name}>
                          {#if person.avatar_url}
                            <img src={person.avatar_url} alt={person.name} class="w-full h-full object-cover" />
                          {:else}
                            {initials(person.name)}
                          {/if}
                        </div>
                      {/each}
                      {#if extraRsvps > 0}
                        <div class="w-6 h-6 rounded-full flex items-center justify-center border-2 border-white shrink-0"
                          style="background: hsl(220 14% 88%); color: hsl(234 12% 40%); font-size: 8px; font-weight: 700; margin-left: -6px; position: relative; z-index: 5">
                          +{extraRsvps}
                        </div>
                      {/if}
                    </div>
                  {/if}
                </div>

              </div>
            {/each}
          </div>
        </div>
      {/if}

        <!-- Activity Feed -->
        <div class="pt-8">
          <h2 class="text-sm font-medium text-muted-foreground mb-4">Recent Activity</h2>
          {#if feedItems.length > 0}
            <div class="flex flex-col divide-y divide-border/60">
              {#each feedItems as item}
                <div class="py-7">
                  <div class="flex gap-3 {item.type === 'member' ? 'items-center' : 'items-start'}">

                    <!-- Avatar -->
                    {#if item.authorAvatar}
                      <img src={item.authorAvatar} alt={item.author} class="w-8 h-8 rounded-full object-cover shrink-0{item.type !== 'member' ? ' mt-0.5' : ''}" />
                    {:else}
                      <div class="w-8 h-8 rounded-full flex items-center justify-center text-white shrink-0{item.type !== 'member' ? ' mt-0.5' : ''}" style="background: hsl(234 26% 41%); font-size: 9px; font-weight: 700">
                        {item.author?.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2) ?? '?'}
                      </div>
                    {/if}

                    <div class="flex-1 min-w-0">

                      {#if item.type === 'post'}
                        <!-- Name + time -->
                        <div class="flex items-baseline gap-2 mb-0.5">
                          <a href="/profile/{item.authorId}" class="text-sm font-semibold text-foreground hover:underline">{item.author}</a>
                          <span class="text-xs text-muted-foreground">{timeAgo(item.time)}</span>
                        </div>
                        <!-- Group subline -->
                        <p class="text-xs text-muted-foreground mb-2">
                          Posted in <a href="/groups/{item.groupId}/board" class="hover:underline">{item.groupName}</a>
                        </p>
                        <!-- Body -->
                        <p class="text-sm text-foreground leading-relaxed mb-3">{item.body}</p>

                        <!-- Reactions + reply bar -->
                        <div class="flex items-center gap-2 flex-wrap">
                          {#each (item.reactions ?? []) as r}
                            <button
                              onclick={() => toggleReaction(item.id, r.emoji)}
                              class="flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-medium transition-colors"
                              style={item.myReaction === r.emoji
                                ? 'background: hsl(234 40% 94%); color: hsl(234 26% 41%); border: 1px solid hsl(234 26% 80%)'
                                : 'background: hsl(220 14% 93%); color: hsl(220 9% 40%); border: 1px solid transparent'}
                            >{r.emoji} {r.count}</button>
                          {/each}

                          <div class="relative">
                            <button
                              onclick={() => emojiPickerPostId = emojiPickerPostId === item.id ? null : item.id}
                              class="flex items-center justify-center w-7 h-7 rounded-full text-sm hover:bg-slate-100 transition-colors"
                              style="color: hsl(220 9% 55%)"
                            >+</button>
                            {#if emojiPickerPostId === item.id}
                              <button class="fixed inset-0 z-40 cursor-default" onclick={() => emojiPickerPostId = null} tabindex="-1" aria-hidden="true"></button>
                              <div class="absolute left-0 bottom-full mb-1 flex gap-1 bg-white rounded-xl border border-border px-2 py-1.5 z-50" style="box-shadow: 0 4px 16px rgba(0,0,0,0.1)">
                                {#each EMOJI_OPTIONS as emoji}
                                  <button onclick={() => toggleReaction(item.id, emoji)} class="text-lg hover:scale-125 transition-transform leading-none p-0.5">{emoji}</button>
                                {/each}
                              </div>
                            {/if}
                          </div>

                          <button
                            onclick={() => expandedPostId = expandedPostId === item.id ? null : item.id}
                            class="flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-medium ml-auto transition-colors"
                            style="color: hsl(220 9% 55%)"
                          >
                            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                              <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
                            </svg>
                            {(item.replyCount ?? 0) > 0 ? `${item.replyCount} ${item.replyCount === 1 ? 'reply' : 'replies'}` : 'Reply'}
                          </button>
                        </div>

                        <!-- Inline reply thread -->
                        {#if expandedPostId === item.id}
                          <div class="mt-3 pt-3 border-t border-border/50 flex flex-col gap-3">
                            {#each (item.replies ?? []) as reply}
                              <div class="flex gap-2">
                                {#if reply.avatar}
                                  <img src={reply.avatar} alt={reply.author} class="w-6 h-6 rounded-full object-cover shrink-0 mt-0.5" />
                                {:else}
                                  <div class="w-6 h-6 rounded-full flex items-center justify-center text-white shrink-0 mt-0.5" style="background: hsl(234 26% 41%); font-size: 8px; font-weight: 700">
                                    {reply.author?.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2) ?? '?'}
                                  </div>
                                {/if}
                                <div class="flex-1 min-w-0">
                                  <div class="flex items-baseline gap-2 mb-0.5">
                                    <a href="/profile/{reply.authorId}" class="text-xs font-semibold text-foreground hover:underline">{reply.author}</a>
                                    <span class="text-xs text-muted-foreground">{timeAgo(reply.time)}</span>
                                  </div>
                                  <p class="text-sm text-foreground">{reply.body}</p>
                                </div>
                              </div>
                            {/each}
                            <div class="flex gap-2 items-center">
                              <div class="w-6 h-6 rounded-full flex items-center justify-center text-white shrink-0" style="background: hsl(234 26% 41%); font-size: 8px; font-weight: 700">
                                {userName.slice(0, 2).toUpperCase()}
                              </div>
                              <div class="flex-1 flex gap-2">
                                <input
                                  type="text"
                                  placeholder="Write a reply…"
                                  value={replyDrafts[item.id] ?? ''}
                                  oninput={(e) => replyDrafts = { ...replyDrafts, [item.id]: e.target.value }}
                                  onkeydown={(e) => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); submitReply(item.id) } }}
                                  class="flex-1 text-sm px-3 py-1.5 rounded-xl border border-input bg-background focus:outline-none focus:ring-2 focus:ring-ring transition"
                                />
                                <button
                                  onclick={() => submitReply(item.id)}
                                  disabled={!(replyDrafts[item.id] ?? '').trim()}
                                  class="px-3 py-1.5 rounded-xl text-xs font-semibold text-white disabled:opacity-40 transition-opacity"
                                  style="background: hsl(234 26% 41%)"
                                >Send</button>
                              </div>
                            </div>
                          </div>
                        {/if}

                      {:else if item.type === 'member'}
                        <!-- Single line: [name] joined [group] -->
                        <div class="flex items-center gap-1.5 flex-wrap">
                          <a href="/profile/{item.authorId}" class="text-sm font-semibold text-foreground hover:underline">{item.author}</a>
                          <span class="text-sm text-muted-foreground">joined</span>
                          <a href="/groups/{item.groupId}/members" class="text-sm font-medium text-foreground hover:underline">{item.groupName}</a>
                          <span class="text-xs text-muted-foreground ml-auto">{timeAgo(item.time)}</span>
                        </div>

                      {:else if item.type === 'event_created'}
                        <!-- Name + time -->
                        <div class="flex items-baseline gap-2 mb-0.5">
                          <a href="/profile/{item.authorId}" class="text-sm font-semibold text-foreground hover:underline">{item.author}</a>
                          <span class="text-xs text-muted-foreground">{timeAgo(item.time)}</span>
                        </div>
                        <!-- Group subline -->
                        <p class="text-xs text-muted-foreground mb-2">
                          Created an event in <a href="/groups/{item.groupId}" class="hover:underline">{item.groupName}</a>
                        </p>
                        <!-- Event details card -->
                        <div class="rounded-lg overflow-hidden" style="background: hsl(35 100% 97%); border: 1px solid hsl(35 100% 88%)">
                          <div class="p-3">
                            <div class="flex items-center gap-3 mb-2">
                              <div class="flex-1 min-w-0">
                                <a href="/groups/{item.groupId}/events/{item.eventId}" class="text-sm font-semibold text-foreground hover:underline leading-snug block">{item.eventTitle}</a>
                                {#if item.eventDate}
                                  <p class="text-xs text-muted-foreground mt-0.5">{formatEventDateTime(new Date(item.eventDate).toISOString())}</p>
                                {/if}
                              </div>
                              {#if item.eventCoverPhoto}
                                <img src={item.eventCoverPhoto} alt="" class="w-10 h-10 rounded-full object-cover shrink-0" />
                              {:else if item.eventDate}
                                <div class="w-10 h-10 rounded-full shrink-0 flex flex-col items-center justify-center border border-border/40" style="background: hsl(220 14% 93%)">
                                  <span class="font-semibold uppercase leading-none" style="font-size: 7px; color: hsl(220 9% 65%)">{new Date(item.eventDate).toLocaleDateString('en-US', { month: 'short' })}</span>
                                  <span class="font-bold leading-none mt-0.5" style="font-size: 1rem; color: hsl(220 9% 50%)">{new Date(item.eventDate).getDate()}</span>
                                </div>
                              {/if}
                            </div>
                            {#if item.eventLocation}
                              <div class="flex items-center gap-1.5 mb-2">
                                <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="hsl(220 9% 65%)" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                                  <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/>
                                </svg>
                                <span class="text-xs text-muted-foreground">{item.eventLocation}</span>
                              </div>
                            {/if}
                            <!-- Action: RSVP or poll -->
                            {#if item.eventStatus === 'pending_date'}
                              <button class="w-full py-1.5 rounded-lg text-xs font-semibold text-white" style="background: hsl(234 26% 41%)">
                                Vote on a date
                              </button>
                            {:else}
                              <div class="relative">
                                <button
                                  onclick={() => feedRsvpDropdownId = feedRsvpDropdownId === item.id ? null : item.id}
                                  class="flex items-center justify-center gap-1.5 py-1.5 rounded-lg text-xs font-semibold transition-colors whitespace-nowrap w-20"
                                  style={item.myRsvp === 'yes'
                                    ? 'background: hsl(35 100% 93%); color: hsl(35 80% 32%)'
                                    : item.myRsvp === 'maybe'
                                      ? 'background: hsl(355 68% 93%); color: hsl(355 68% 38%)'
                                      : 'background: hsl(220 14% 93%); color: hsl(220 9% 46%)'}
                                >
                                  {#if item.myRsvp === 'yes'}
                                    <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>
                                    Going
                                  {:else if item.myRsvp === 'maybe'}
                                    <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/><circle cx="5" cy="12" r="1"/></svg>
                                    Maybe
                                  {:else}
                                    RSVP
                                  {/if}
                                  <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="6 9 12 15 18 9"/></svg>
                                </button>
                                {#if feedRsvpDropdownId === item.id}
                                  <button class="fixed inset-0 z-40 cursor-default" onclick={() => feedRsvpDropdownId = null} tabindex="-1" aria-hidden="true"></button>
                                  <div class="absolute left-0 bottom-full mb-1 w-32 bg-white rounded-lg border border-border py-1 z-50" style="box-shadow: 0 4px 16px rgba(0,0,0,0.12)">
                                    <button onclick={() => setFeedRsvp(item.id, 'yes')} class="w-full flex items-center gap-2 px-3 py-2 text-xs text-left hover:bg-gray-50 transition-colors" style={item.myRsvp === 'yes' ? 'color: hsl(35 80% 32%); font-weight: 600' : 'color: hsl(234 20% 30%)'}>
                                      <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>
                                      Going
                                    </button>
                                    <button onclick={() => setFeedRsvp(item.id, 'maybe')} class="w-full flex items-center gap-2 px-3 py-2 text-xs text-left hover:bg-gray-50 transition-colors" style={item.myRsvp === 'maybe' ? 'color: hsl(355 68% 38%); font-weight: 600' : 'color: hsl(234 20% 30%)'}>
                                      <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/><circle cx="5" cy="12" r="1"/></svg>
                                      Maybe
                                    </button>
                                    <button onclick={() => setFeedRsvp(item.id, 'no')} class="w-full flex items-center gap-2 px-3 py-2 text-xs text-left hover:bg-gray-50 transition-colors" style={item.myRsvp === 'no' ? 'color: hsl(0 72% 51%); font-weight: 600' : 'color: hsl(234 20% 30%)'}>
                                      <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
                                      Can't go
                                    </button>
                                  </div>
                                {/if}
                              </div>
                            {/if}
                          </div>
                        </div>
                      {/if}

                    </div>
                  </div>
                </div>
              {/each}
            </div>
          {:else}
            <div class="rounded-xl bg-white p-8 text-center">
              <p class="text-sm text-muted-foreground">No recent activity in your groups.</p>
            </div>
          {/if}
        </div>
      {/if}

    </div>
  </div>

  <!-- Right: Event Calendar (desktop only) -->
  <div class="hidden md:flex flex-col w-80 shrink-0 overflow-hidden" style="background: hsl(234 20% 96%)">

    <!-- Sticky: calendar grid -->
    <div class="px-6 pt-5 pb-3 shrink-0">

      <!-- Calendar grid -->
      <div>
        <div class="flex items-center justify-between mb-2">
          <button onclick={prevMonth} class="p-0.5 rounded hover:bg-gray-100 transition-colors text-muted-foreground">
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
              <polyline points="15 18 9 12 15 6"/>
            </svg>
          </button>
          <span class="text-sm font-semibold text-foreground">{MONTHS[calendarMonth]} {calendarYear}</span>
          <button onclick={nextMonth} class="p-0.5 rounded hover:bg-gray-100 transition-colors text-muted-foreground">
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
              <polyline points="9 18 15 12 9 6"/>
            </svg>
          </button>
        </div>
        <!-- Day headers -->
        <div class="grid grid-cols-7 mb-0.5">
          {#each DAYS as d}
            <div class="text-center font-semibold uppercase tracking-wider py-0.5" style="font-size: 9px; color: hsl(234 12% 72%)">{d}</div>
          {/each}
        </div>
        <div class="grid grid-cols-7">
          {#each calendarCells as cell}
            {#if cell === null}
              <div class="h-7"></div>
            {:else}
              <div
                class="relative flex items-center justify-center h-7 select-none {cell.hasEvent ? 'cursor-pointer' : 'cursor-default'}"
                onclick={() => cell.hasEvent && scrollToDay(cell.day)}
              >
                <div class="flex items-center justify-center w-5 h-5 rounded-full transition-colors {cell.hasEvent && !cell.isToday ? 'hover:bg-amber-100' : ''}"
                  style="font-size: 11px; {cell.isToday
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
      </div>
    </div>

    <!-- Scrollable events list -->
    <div class="flex-1 overflow-y-auto px-6 pb-6 flex flex-col gap-3">
      {#if upcomingEvents.length === 0}
        <!-- Empty state -->
        <div class="py-6 flex flex-col items-center text-center">
          <div class="w-20 h-20 rounded-full bg-gray-100 flex items-center justify-center mb-3">
            <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="hsl(234 12% 72%)" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
              <rect x="3" y="4" width="18" height="18" rx="2" ry="2"/>
              <line x1="16" y1="2" x2="16" y2="6"/>
              <line x1="8" y1="2" x2="8" y2="6"/>
              <line x1="3" y1="10" x2="21" y2="10"/>
              <line x1="8" y1="14" x2="8" y2="14"/>
              <line x1="12" y1="14" x2="12" y2="14"/>
              <line x1="16" y1="14" x2="16" y2="14"/>
            </svg>
          </div>
          <p class="text-sm font-semibold text-foreground mb-1">No upcoming events</p>
          <p class="text-xs text-muted-foreground mb-4 max-w-[200px]">You don't have any events scheduled yet.</p>
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
          <div id="cal-event-{event.id}" class="bg-white rounded-xl">
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

              <!-- Meta: group + location + bring item -->
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
                {#if event.myBringItem}
                  <div class="flex items-center gap-1.5">
                    <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="hsl(234 12% 80%)" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                      <path d="M6 2L3 6v14a2 2 0 002 2h14a2 2 0 002-2V6l-3-4z"/>
                      <line x1="3" y1="6" x2="21" y2="6"/>
                      <path d="M16 10a4 4 0 01-8 0"/>
                    </svg>
                    <span class="text-xs text-muted-foreground">Bringing: <span class="font-medium">{event.myBringItem}</span></span>
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
                      >
                        +{extraRsvps}
                      </div>
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
</div>
