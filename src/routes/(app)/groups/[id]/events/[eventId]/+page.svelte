<script>
  import { supabase } from '$lib/supabase'
  import { page } from '$app/stores'
  import { goto } from '$app/navigation'
  import { onMount } from 'svelte'

  let groupId = $derived($page.params.id)
  let eventId = $derived($page.params.eventId)

  let event = $state(null)
  let host = $state(null)
  let rsvps = $state([])
  let myRsvp = $state(null)
  let bringItems = $state([])
  let dateOptions = $state([])
  let myDateResponses = $state(new Set())
  let loading = $state(true)
  let currentUserId = $state(null)
  let currentUserRole = $state(null)
  let rsvpLoading = $state(false)
  let newItemName = $state('')
  let newItemNote = $state('')
  let newItemQty = $state(1)
  let addingItem = $state(false)
  let showAddItem = $state(false)
  let error = $state('')

  onMount(async () => {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) { goto('/auth/login'); return }
    currentUserId = user.id

    const { data: membership } = await supabase
      .from('group_members')
      .select('role')
      .eq('group_id', groupId)
      .eq('user_id', user.id)
      .single()
    currentUserRole = membership?.role ?? null

    await loadEvent()
    loading = false
  })

  async function loadEvent() {
    const { data } = await supabase
      .from('events')
      .select('*, users(display_name)')
      .eq('id', eventId)
      .single()
    event = data
    host = data?.users

    const { data: rsvpData } = await supabase
      .from('event_rsvps')
      .select('user_id, status, users(display_name)')
      .eq('event_id', eventId)
    rsvps = rsvpData ?? []
    myRsvp = rsvps.find(r => r.user_id === currentUserId)?.status ?? null

    const { data: items } = await supabase
      .from('bring_list_items')
      .select('*, users(display_name), bring_list_claims(user_id, users(display_name))')
      .eq('event_id', eventId)
      .order('created_at', { ascending: true })
    bringItems = items ?? []

    if (event?.status === 'pending_date') {
      const { data: opts } = await supabase
        .from('event_date_options')
        .select('*, event_date_responses(user_id, available)')
        .eq('event_id', eventId)
        .order('candidate_date', { ascending: true })
      dateOptions = opts ?? []

      const myResponses = new Set()
      dateOptions.forEach(opt => {
        if (opt.event_date_responses?.find(r => r.user_id === currentUserId && r.available)) {
          myResponses.add(opt.id)
        }
      })
      myDateResponses = myResponses
    }
  }

  async function setRsvp(status) {
    rsvpLoading = true
    const existing = rsvps.find(r => r.user_id === currentUserId)
    if (existing) {
      await supabase.from('event_rsvps').update({ status, updated_at: new Date().toISOString() })
        .eq('event_id', eventId).eq('user_id', currentUserId)
    } else {
      await supabase.from('event_rsvps').insert({ event_id: eventId, user_id: currentUserId, status })
    }
    await loadEvent()
    rsvpLoading = false
  }

  async function toggleDateResponse(optionId) {
    const currently = myDateResponses.has(optionId)
    const existing = dateOptions
      .find(o => o.id === optionId)
      ?.event_date_responses
      ?.find(r => r.user_id === currentUserId)

    if (existing) {
      await supabase.from('event_date_responses')
        .update({ available: !currently })
        .eq('option_id', optionId).eq('user_id', currentUserId)
    } else {
      await supabase.from('event_date_responses')
        .insert({ option_id: optionId, user_id: currentUserId, available: true })
    }
    await loadEvent()
  }

  async function claimItem(itemId) {
    const item = bringItems.find(i => i.id === itemId)
    const alreadyClaimed = item?.bring_list_claims?.find(c => c.user_id === currentUserId)
    if (alreadyClaimed) {
      await supabase.from('bring_list_claims').delete()
        .eq('item_id', itemId).eq('user_id', currentUserId)
    } else {
      await supabase.from('bring_list_claims').insert({ item_id: itemId, user_id: currentUserId })
    }
    await loadEvent()
  }

  async function addItem() {
    if (!newItemName.trim()) return
    addingItem = true
    const { error: e } = await supabase.from('bring_list_items').insert({
      event_id: eventId,
      name: newItemName.trim(),
      note: newItemNote.trim() || null,
      quantity: newItemQty,
      added_by: currentUserId,
    })
    if (!e) {
      await supabase.from('bring_list_claims').insert({ item_id: (await supabase.from('bring_list_items').select('id').eq('event_id', eventId).eq('name', newItemName.trim()).order('created_at', { ascending: false }).limit(1).single()).data?.id, user_id: currentUserId })
      newItemName = ''; newItemNote = ''; newItemQty = 1
      showAddItem = false
      await loadEvent()
    }
    addingItem = false
  }

  async function confirmDate(optionId) {
    const option = dateOptions.find(o => o.id === optionId)
    if (!option) return
    await supabase.from('events').update({
      event_date: option.candidate_date,
      status: 'confirmed'
    }).eq('id', eventId)
    await loadEvent()
  }

  function formatDate(dateStr) {
    return new Date(dateStr).toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' })
  }

  function formatTime(dateStr) {
    return new Date(dateStr).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })
  }

  function formatShortDate(dateStr) {
    return new Date(dateStr).toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' })
  }

  let goingCount = $derived(rsvps.filter(r => r.status === 'going').length)
  let notGoingCount = $derived(rsvps.filter(r => r.status === 'not_going').length)
  let isAdmin = $derived(currentUserRole === 'admin' || currentUserRole === 'co_admin')
  let claimedCount = $derived(bringItems.reduce((sum, item) => sum + (item.bring_list_claims?.length ?? 0), 0))
  let totalSlots = $derived(bringItems.reduce((sum, item) => sum + item.quantity, 0))
</script>

<div class="max-w-2xl mx-auto px-4 py-6">
  {#if loading}
    <div class="flex flex-col gap-3">
      {#each [1,2,3] as _}
        <div class="rounded-xl border border-border p-4 animate-pulse">
          <div class="h-4 bg-muted rounded w-1/2 mb-2"></div>
          <div class="h-3 bg-muted rounded w-1/3"></div>
        </div>
      {/each}
    </div>

  {:else if event}

    <!-- Event header -->
    <div class="mb-6">
      <div class="flex items-start justify-between">
        <h2 class="text-xl font-semibold text-foreground">{event.title}</h2>
        {#if isAdmin}
          <a href="/groups/{groupId}/events/{eventId}/edit"
            class="p-2 rounded-lg hover:bg-muted transition-colors shrink-0"
            style="color: hsl(234 12% 52%)">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
              <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/>
              <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/>
            </svg>
          </a>
        {/if}
      </div>

      {#if event.status === 'pending_date'}
        <span class="inline-block mt-1 text-xs px-2 py-0.5 rounded-full font-medium" style="background: hsl(35 100% 97%); color: hsl(35 80% 40%)">
          Picking a date
        </span>
      {:else}
        <p class="text-sm text-muted-foreground mt-1">{formatDate(event.event_date)} at {formatTime(event.event_date)}</p>
      {/if}

      {#if event.location}
        <p class="text-sm text-muted-foreground flex items-center gap-1.5 mt-1">
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/>
          </svg>
          {event.location}
        </p>
      {/if}

      {#if host}
        <p class="text-xs text-muted-foreground mt-1">Hosted by {host.display_name}</p>
      {/if}

      {#if event.description}
        <p class="text-sm text-foreground mt-3">{event.description}</p>
      {/if}
    </div>

    <!-- Date picker (pending_date) -->
    {#if event.status === 'pending_date'}
      <div class="rounded-xl border border-border p-4 mb-4">
        <h3 class="text-sm font-semibold text-foreground mb-3">Which dates work for you?</h3>
        <div class="flex flex-col gap-2">
          {#each dateOptions as option}
            {@const responseCount = option.event_date_responses?.filter(r => r.available).length ?? 0}
            {@const myResponse = myDateResponses.has(option.id)}
            <div class="flex items-center gap-3">
              <button
                onclick={() => toggleDateResponse(option.id)}
                class="flex-1 flex items-center justify-between px-3 py-2.5 rounded-lg border text-sm transition-colors"
                style={myResponse
                  ? 'border-color: hsl(234 26% 41%); background: hsl(234 40% 97%); color: hsl(234 26% 41%)'
                  : 'border-color: hsl(234 20% 88%); color: hsl(234 20% 40%)'}
              >
                <span class="font-medium">{formatShortDate(option.candidate_date)}</span>
                <span class="text-xs">{responseCount} available</span>
              </button>
              {#if isAdmin}
                <button
                  onclick={() => confirmDate(option.id)}
                  class="px-3 py-2 rounded-lg text-xs font-semibold text-white shrink-0"
                  style="background: hsl(234 26% 41%)"
                >
                  Confirm
                </button>
              {/if}
            </div>
          {/each}
        </div>
      </div>

    {:else}
      <!-- RSVP -->
      <div class="rounded-xl border border-border p-4 mb-4">
        <div class="flex items-center justify-between mb-3">
          <h3 class="text-sm font-semibold text-foreground">Are you going?</h3>
          <p class="text-xs text-muted-foreground">{goingCount} going · {notGoingCount} not going</p>
        </div>
        <div class="flex gap-2">
          <button
            onclick={() => setRsvp('going')}
            disabled={rsvpLoading}
            class="flex-1 py-2.5 rounded-xl text-sm font-semibold transition-all"
            style={myRsvp === 'going'
              ? 'background: hsl(234 26% 41%); color: white'
              : 'background: hsl(234 40% 97%); color: hsl(234 26% 41%)'}
          >
            Going
          </button>
          <button
            onclick={() => setRsvp('not_going')}
            disabled={rsvpLoading}
            class="flex-1 py-2.5 rounded-xl text-sm font-semibold transition-all border"
            style={myRsvp === 'not_going'
              ? 'background: hsl(234 20% 88%); color: hsl(234 20% 30%); border-color: hsl(234 20% 70%)'
              : 'border-color: hsl(234 20% 88%); color: hsl(234 12% 52%)'}
          >
            Can't make it
          </button>
        </div>

        {#if rsvps.filter(r => r.status === 'going').length > 0}
          <div class="mt-3 pt-3 border-t border-border">
            <p class="text-xs text-muted-foreground mb-1">Going</p>
            <div class="flex flex-wrap gap-1.5">
              {#each rsvps.filter(r => r.status === 'going') as rsvp}
                <span class="text-xs px-2 py-1 rounded-full" style="background: hsl(234 40% 97%); color: hsl(234 26% 41%)">
                  {rsvp.users?.display_name}
                </span>
              {/each}
            </div>
          </div>
        {/if}
      </div>
    {/if}

    <!-- Bring list -->
    <div class="rounded-xl border border-border p-4">
      <div class="flex items-center justify-between mb-3">
        <h3 class="text-sm font-semibold text-foreground">Bring list</h3>
        <p class="text-xs text-muted-foreground">{claimedCount}/{totalSlots} claimed</p>
      </div>

      {#if bringItems.length === 0 && !showAddItem}
        <p class="text-sm text-muted-foreground mb-3">Nothing on the list yet.</p>
      {/if}

      <div class="flex flex-col gap-2 mb-3">
        {#each bringItems as item}
          {@const claimed = item.bring_list_claims ?? []}
          {@const myClaim = claimed.find(c => c.user_id === currentUserId)}
          {@const openSlots = item.quantity - claimed.length}

          <div class="flex items-start gap-3 py-2 border-b border-border last:border-0">
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2">
                <p class="text-sm font-medium text-foreground">{item.name}</p>
                {#if item.quantity > 1}
                  <span class="text-xs text-muted-foreground">×{item.quantity}</span>
                {/if}
              </div>
              {#if item.note}
                <p class="text-xs text-muted-foreground">{item.note}</p>
              {/if}
              {#if claimed.length > 0}
                <div class="flex flex-wrap gap-1 mt-1">
                  {#each claimed as c}
                    <span class="text-xs px-1.5 py-0.5 rounded-full" style="background: hsl(234 40% 97%); color: hsl(234 26% 41%)">{c.users?.display_name}</span>
                  {/each}
                  {#if openSlots > 0}
                    <span class="text-xs px-1.5 py-0.5 rounded-full border border-dashed" style="border-color: hsl(234 20% 70%); color: hsl(234 12% 52%)">{openSlots} open</span>
                  {/if}
                </div>
              {/if}
            </div>

            {#if !item.is_locked}
              <button
                onclick={() => claimItem(item.id)}
                class="px-3 py-1.5 rounded-lg text-xs font-semibold shrink-0 transition-all"
                style={myClaim
                  ? 'background: hsl(234 20% 88%); color: hsl(234 20% 40%)'
                  : openSlots > 0
                    ? 'background: hsl(234 26% 41%); color: white'
                    : 'background: hsl(234 20% 88%); color: hsl(234 12% 52%); opacity: 0.5; pointer-events: none'}
                disabled={!myClaim && openSlots === 0}
              >
                {myClaim ? 'Unclaim' : openSlots > 0 ? 'Claim' : 'Full'}
              </button>
            {/if}
          </div>
        {/each}
      </div>

      <!-- Add item form -->
      {#if showAddItem}
        <div class="flex flex-col gap-2 pt-2 border-t border-border">
          <input type="text" bind:value={newItemName} placeholder="Item name"
            class="w-full px-3 py-2 rounded-lg border border-input bg-background text-sm focus:outline-none focus:ring-2 focus:ring-ring" />
          <input type="text" bind:value={newItemNote} placeholder="Note (optional)"
            class="w-full px-3 py-2 rounded-lg border border-input bg-background text-sm focus:outline-none focus:ring-2 focus:ring-ring" />
          <div class="flex items-center gap-2">
            <label class="text-xs text-muted-foreground shrink-0">Quantity</label>
            <input type="number" bind:value={newItemQty} min="1" max="20"
              class="w-16 px-2 py-1.5 rounded-lg border border-input bg-background text-sm focus:outline-none focus:ring-2 focus:ring-ring" />
          </div>
          <div class="flex gap-2 mt-1">
            <button onclick={addItem} disabled={addingItem || !newItemName.trim()}
              class="px-4 py-2 rounded-xl text-sm font-semibold text-white disabled:opacity-40"
              style="background: hsl(234 26% 41%)">
              {addingItem ? 'Adding…' : 'Add'}
            </button>
            <button onclick={() => showAddItem = false}
              class="px-4 py-2 rounded-xl text-sm font-medium text-muted-foreground hover:bg-muted">
              Cancel
            </button>
          </div>
        </div>
      {:else}
        <button
          onclick={() => showAddItem = true}
          class="text-sm font-medium"
          style="color: hsl(234 26% 41%)"
        >
          + Add item
        </button>
      {/if}
    </div>

  {/if}
</div>