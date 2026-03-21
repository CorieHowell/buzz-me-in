<script>
  import { supabase } from '$lib/supabase'
  import { page } from '$app/stores'
  import { goto } from '$app/navigation'
  import { onMount } from 'svelte'

  let groupId = $derived($page.params.id)
  let lists = $state([])
  let loading = $state(true)
  let currentUserId = $state(null)
  let currentUserRole = $state(null)
  let isAdmin = $derived(currentUserRole === 'admin' || currentUserRole === 'co_admin')

  let showNewList = $state(false)
  let newListName = $state('')
  let creatingList = $state(false)
  let expandedList = $state(null)
  let newItemInputs = $state({})
  let addingItem = $state(null)
  let upvoteLoading = $state(null)

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
    await loadLists()
    loading = false
  })

  async function loadLists() {
    const { data } = await supabase
      .from('group_lists')
      .select(`
        id, name, created_at,
        list_items(
          id, title, note, is_done, created_at, added_by,
          users(display_name),
          list_item_upvotes(user_id)
        )
      `)
      .eq('group_id', groupId)
      .order('created_at', { ascending: true })

    lists = (data ?? []).map(l => ({
      ...l,
      list_items: (l.list_items ?? []).map(item => ({
        ...item,
        upvote_count: item.list_item_upvotes?.length ?? 0,
        i_upvoted: item.list_item_upvotes?.some(u => u.user_id === currentUserId) ?? false,
      })).sort((a, b) => b.upvote_count - a.upvote_count || new Date(a.created_at) - new Date(b.created_at))
    }))
  }

  async function createList() {
    if (!newListName.trim()) return
    creatingList = true
    await supabase.from('group_lists').insert({
      group_id: groupId,
      name: newListName.trim(),
    })
    newListName = ''
    showNewList = false
    await loadLists()
    creatingList = false
  }

  async function deleteList(listId) {
    if (!confirm('Delete this list and all its items?')) return
    await supabase.from('group_lists').delete().eq('id', listId)
    if (expandedList === listId) expandedList = null
    await loadLists()
  }

  async function addItem(listId) {
    const title = newItemInputs[listId]?.trim()
    if (!title) return
    addingItem = listId
    await supabase.from('list_items').insert({
      list_id: listId,
      title,
      added_by: currentUserId,
    })
    newItemInputs[listId] = ''
    await loadLists()
    addingItem = null
  }

  async function toggleDone(itemId, isDone) {
    await supabase.from('list_items').update({ is_done: !isDone }).eq('id', itemId)
    await loadLists()
  }

  async function toggleUpvote(itemId, iUpvoted) {
    upvoteLoading = itemId
    if (iUpvoted) {
      await supabase.from('list_item_upvotes')
        .delete()
        .eq('item_id', itemId)
        .eq('user_id', currentUserId)
    } else {
      await supabase.from('list_item_upvotes')
        .insert({ item_id: itemId, user_id: currentUserId })
    }
    await loadLists()
    upvoteLoading = null
  }

  async function deleteItem(itemId) {
    await supabase.from('list_items').delete().eq('id', itemId)
    await loadLists()
  }
</script>

<div class="max-w-2xl mx-auto px-4 py-6">

  <div class="flex items-center justify-between mb-6">
    <h2 class="text-base font-semibold text-foreground">Lists</h2>
    {#if isAdmin}
      <button
        onclick={() => showNewList = !showNewList}
        class="px-4 py-2 rounded-xl text-sm font-semibold text-white"
        style="background: hsl(234 26% 41%)"
      >
        + New list
      </button>
    {/if}
  </div>

  {#if showNewList}
    <div class="rounded-xl border border-border p-4 mb-4">
      <p class="text-sm font-medium text-foreground mb-2">New list</p>
      <div class="flex gap-2">
        <input
          type="text"
          bind:value={newListName}
          placeholder="Books to read, Restaurants to try…"
          class="flex-1 px-3 py-2 rounded-lg border border-input bg-background text-sm focus:outline-none focus:ring-2 focus:ring-ring"
          onkeydown={(e) => e.key === 'Enter' && createList()}
        />
        <button
          onclick={createList}
          disabled={creatingList || !newListName.trim()}
          class="px-4 py-2 rounded-xl text-sm font-semibold text-white disabled:opacity-40"
          style="background: hsl(234 26% 41%)"
        >
          Create
        </button>
        <button
          onclick={() => showNewList = false}
          class="px-3 py-2 rounded-xl text-sm text-muted-foreground hover:bg-muted"
        >
          Cancel
        </button>
      </div>
    </div>
  {/if}

  {#if loading}
    <div class="flex flex-col gap-3">
      {#each [1,2] as _}
        <div class="rounded-xl border border-border p-4 animate-pulse">
          <div class="h-4 bg-muted rounded w-1/3 mb-3"></div>
          <div class="h-3 bg-muted rounded w-2/3"></div>
        </div>
      {/each}
    </div>

  {:else if lists.length === 0}
    <div class="text-center py-12 rounded-xl border border-border">
      <p class="text-sm text-muted-foreground mb-1">No lists yet</p>
      {#if isAdmin}
        <p class="text-xs text-muted-foreground">Create a list to track books, restaurants, ideas — anything your group wants.</p>
      {/if}
    </div>

  {:else}
    <div class="flex flex-col gap-3">
      {#each lists as list}
        {@const doneCount = list.list_items.filter(i => i.is_done).length}
        {@const totalCount = list.list_items.length}
        {@const isExpanded = expandedList === list.id}

        <div class="rounded-xl border border-border bg-background overflow-hidden">

          <button
            onclick={() => expandedList = isExpanded ? null : list.id}
            class="flex items-center gap-3 w-full px-4 py-3 text-left hover:bg-muted/30 transition-colors"
          >
            <div class="flex-1 min-w-0">
              <p class="text-sm font-semibold text-foreground">{list.name}</p>
              <p class="text-xs text-muted-foreground">{totalCount} items · {doneCount} done</p>
            </div>
            <div class="flex items-center gap-2 shrink-0">
              {#if isAdmin}
                <button
                  onclick={(e) => { e.stopPropagation(); deleteList(list.id) }}
                  class="p-1.5 rounded-lg hover:bg-muted transition-colors"
                  style="color: hsl(234 12% 52%)"
                >
                  <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14H6L5 6"/><path d="M9 6V4h6v2"/>
                  </svg>
                </button>
              {/if}
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="hsl(234 12% 52%)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"
                style="transform: rotate({isExpanded ? 90 : 0}deg); transition: transform 0.2s">
                <polyline points="9 18 15 12 9 6"/>
              </svg>
            </div>
          </button>

          {#if isExpanded}
            <div class="border-t border-border">

              {#if list.list_items.length === 0}
                <p class="text-sm text-muted-foreground px-4 py-3">No items yet — add the first one below.</p>
              {:else}
                <div class="flex flex-col">
                  {#each list.list_items as item}
                    <div class="flex items-start gap-3 px-4 py-3 border-b border-border last:border-0 {item.is_done ? 'opacity-50' : ''}">

                      <button
                        onclick={() => toggleDone(item.id, item.is_done)}
                        class="mt-0.5 w-4 h-4 rounded border-2 flex items-center justify-center shrink-0 transition-colors"
                        style={item.is_done
                          ? 'background: hsl(234 26% 41%); border-color: hsl(234 26% 41%)'
                          : 'border-color: hsl(234 20% 70%)'}
                      >
                        {#if item.is_done}
                          <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">
                            <polyline points="20 6 9 17 4 12"/>
                          </svg>
                        {/if}
                      </button>

                      <div class="flex-1 min-w-0">
                        <p class="text-sm text-foreground {item.is_done ? 'line-through' : ''}">{item.title}</p>
                        {#if item.note}
                          <p class="text-xs text-muted-foreground">{item.note}</p>
                        {/if}
                        <p class="text-xs text-muted-foreground mt-0.5">Added by {item.users?.display_name}</p>
                      </div>

                      <div class="flex items-center gap-1 shrink-0">
                        <button
                          onclick={() => toggleUpvote(item.id, item.i_upvoted)}
                          disabled={upvoteLoading === item.id}
                          class="flex items-center gap-1 px-2 py-1 rounded-lg transition-colors text-xs font-medium disabled:opacity-50"
                          style={item.i_upvoted
                            ? 'background: hsl(234 40% 97%); color: hsl(234 26% 41%)'
                            : 'color: hsl(234 12% 52%)'}
                          title={item.i_upvoted ? 'Remove upvote' : 'Upvote'}
                        >
                          <svg width="12" height="12" viewBox="0 0 24 24" fill={item.i_upvoted ? 'hsl(234 26% 41%)' : 'none'} stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <polyline points="18 15 12 9 6 15"/>
                          </svg>
                          {item.upvote_count}
                        </button>
                        {#if item.added_by === currentUserId || isAdmin}
                          <button
                            onclick={() => deleteItem(item.id)}
                            class="p-1.5 rounded-lg hover:bg-muted transition-colors"
                            style="color: hsl(234 12% 52%)"
                          >
                            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                              <line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
                            </svg>
                          </button>
                        {/if}
                      </div>
                    </div>
                  {/each}
                </div>
              {/if}

              <div class="flex gap-2 px-4 py-3 border-t border-border">
                <input
                  type="text"
                  bind:value={newItemInputs[list.id]}
                  placeholder="Add an item…"
                  class="flex-1 px-3 py-2 rounded-lg border border-input bg-background text-sm focus:outline-none focus:ring-2 focus:ring-ring"
                  onkeydown={(e) => e.key === 'Enter' && addItem(list.id)}
                />
                <button
                  onclick={() => addItem(list.id)}
                  disabled={addingItem === list.id || !newItemInputs[list.id]?.trim()}
                  class="px-4 py-2 rounded-xl text-sm font-semibold text-white disabled:opacity-40"
                  style="background: hsl(234 26% 41%)"
                >
                  Add
                </button>
              </div>

            </div>
          {/if}

        </div>
      {/each}
    </div>
  {/if}

</div>