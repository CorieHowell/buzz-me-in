<script>
  import { supabase } from '$lib/supabase'
  import { goto } from '$app/navigation'
  import { onMount } from 'svelte'

  let groups = $state([])
  let loading = $state(true)
  let currentUserId = $state(null)
  let actionLoading = $state(null)

  onMount(async () => {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) { goto('/auth/login'); return }
    currentUserId = user.id
    await loadGroups()
    loading = false
  })

  async function loadGroups() {
    const { data } = await supabase
      .from('group_members')
      .select('role, is_favorited, joined_at, groups(id, name, description, avatar_url)')
      .eq('user_id', currentUserId)
      .order('is_favorited', { ascending: false })
      .order('joined_at', { ascending: true })

    groups = (data ?? []).map(m => ({
      ...m.groups,
      role: m.role,
      is_favorited: m.is_favorited,
    }))
  }

  async function toggleFavorite(groupId, current) {
    actionLoading = groupId
    await supabase
      .from('group_members')
      .update({ is_favorited: !current })
      .eq('group_id', groupId)
      .eq('user_id', currentUserId)
    await loadGroups()
    actionLoading = null
  }

  async function leaveGroup(groupId, groupName, role) {
    if (role === 'admin') {
      alert('You are the admin of this group. Transfer admin rights to another member before leaving, or delete the group from group settings.')
      return
    }
    if (!confirm(`Leave ${groupName}? You'll need a new invite link to rejoin.`)) return
    actionLoading = groupId
    await supabase
      .from('group_members')
      .delete()
      .eq('group_id', groupId)
      .eq('user_id', currentUserId)
    await loadGroups()
    actionLoading = null
  }

  function initials(name) {
    if (!name) return '?'
    return name.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2)
  }

  let favorited = $derived(groups.filter(g => g.is_favorited))
  let unfavorited = $derived(groups.filter(g => !g.is_favorited))
</script>

<div class="max-w-2xl mx-auto px-4 py-6">

  <div class="flex items-center justify-between mb-6">
    <h1 class="text-xl font-semibold text-foreground">Manage groups</h1>
    <a
      href="/groups/new"
      class="px-4 py-2 rounded-xl text-sm font-semibold text-white"
      style="background: hsl(234 26% 41%)"
    >
      + New group
    </a>
  </div>

  {#if loading}
    <div class="flex flex-col gap-3">
      {#each [1,2,3] as _}
        <div class="rounded-xl border border-border p-4 animate-pulse">
          <div class="flex items-center gap-3">
            <div class="w-10 h-10 rounded-xl bg-muted shrink-0"></div>
            <div class="flex-1">
              <div class="h-4 bg-muted rounded w-1/3 mb-2"></div>
              <div class="h-3 bg-muted rounded w-1/2"></div>
            </div>
          </div>
        </div>
      {/each}
    </div>

  {:else if groups.length === 0}
    <div class="flex flex-col items-center justify-center text-center py-16">
      <div class="w-16 h-16 rounded-2xl flex items-center justify-center mb-4" style="background: hsl(234 40% 97%)">
        <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="hsl(234 26% 41%)" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
          <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
          <circle cx="9" cy="7" r="4"/>
          <path d="M23 21v-2a4 4 0 0 0-3-3.87"/>
          <path d="M16 3.13a4 4 0 0 1 0 7.75"/>
        </svg>
      </div>
      <h2 class="text-base font-semibold text-foreground mb-1">No groups yet</h2>
      <p class="text-sm text-muted-foreground mb-6 max-w-xs">Create your first group and invite your people.</p>
      <a href="/groups/new" class="px-5 py-2.5 rounded-xl text-sm font-semibold text-white" style="background: hsl(234 26% 41%)">
        Create a group
      </a>
    </div>

  {:else}

    <!-- Favorited groups -->
    {#if favorited.length > 0}
      <div class="mb-2">
        <p class="text-xs font-semibold uppercase tracking-wider text-muted-foreground px-1 mb-2">Pinned</p>
        <div class="flex flex-col gap-2">
          {#each favorited as group}
            <div class="flex items-center gap-3 rounded-xl border border-border bg-background p-3">
              <button onclick={() => goto(`/groups/${group.id}`)} class="flex items-center gap-3 flex-1 min-w-0 text-left">
                {#if group.avatar_url}
                  <img src={group.avatar_url} alt={group.name} class="w-10 h-10 rounded-full shrink-0 object-cover" />
                {:else}
                  <div class="w-10 h-10 rounded-full flex items-center justify-center text-sm font-bold text-white shrink-0" style="background: hsl(234 26% 41%)">
                    {initials(group.name)}
                  </div>
                {/if}
                <div class="flex-1 min-w-0">
                  <div class="flex items-center gap-2">
                    <p class="text-sm font-semibold text-foreground truncate">{group.name}</p>
                    {#if group.role !== 'member'}
                      <span class="text-xs px-2 py-0.5 rounded-full shrink-0" style="background: hsl(234 40% 97%); color: hsl(234 26% 41%)">
                        {group.role === 'admin' ? 'Admin' : 'Co-admin'}
                      </span>
                    {/if}
                  </div>
                  {#if group.description}
                    <p class="text-xs text-muted-foreground truncate mt-0.5">{group.description}</p>
                  {/if}
                </div>
              </button>
              <div class="flex items-center gap-1 shrink-0">
                <button
                  onclick={() => toggleFavorite(group.id, group.is_favorited)}
                  disabled={actionLoading === group.id}
                  class="p-2 rounded-lg hover:bg-muted transition-colors disabled:opacity-50"
                  title="Unpin"
                >
                  <svg width="15" height="15" viewBox="0 0 24 24" fill="hsl(234 26% 41%)" stroke="hsl(234 26% 41%)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/>
                  </svg>
                </button>
                {#if group.role !== 'admin'}
                  <button
                    onclick={() => leaveGroup(group.id, group.name, group.role)}
                    disabled={actionLoading === group.id}
                    class="p-2 rounded-lg hover:bg-muted transition-colors disabled:opacity-50 text-xs font-medium"
                    style="color: hsl(234 12% 52%)"
                    title="Leave group"
                  >
                    <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                      <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/>
                      <polyline points="16 17 21 12 16 7"/>
                      <line x1="21" y1="12" x2="9" y2="12"/>
                    </svg>
                  </button>
                {/if}
              </div>
            </div>
          {/each}
        </div>
      </div>
    {/if}

    <!-- All other groups -->
    {#if unfavorited.length > 0}
      <div>
        {#if favorited.length > 0}
          <p class="text-xs font-semibold uppercase tracking-wider text-muted-foreground px-1 mb-2 mt-4">All groups</p>
        {/if}
        <div class="flex flex-col gap-2">
          {#each unfavorited as group}
            <div class="flex items-center gap-3 rounded-xl border border-border bg-background p-3">
              <button onclick={() => goto(`/groups/${group.id}`)} class="flex items-center gap-3 flex-1 min-w-0 text-left">
                {#if group.avatar_url}
                  <img src={group.avatar_url} alt={group.name} class="w-10 h-10 rounded-full shrink-0 object-cover" />
                {:else}
                  <div class="w-10 h-10 rounded-full flex items-center justify-center text-sm font-bold text-white shrink-0" style="background: hsl(234 26% 41%)">
                    {initials(group.name)}
                  </div>
                {/if}
                <div class="flex-1 min-w-0">
                  <div class="flex items-center gap-2">
                    <p class="text-sm font-semibold text-foreground truncate">{group.name}</p>
                    {#if group.role !== 'member'}
                      <span class="text-xs px-2 py-0.5 rounded-full shrink-0" style="background: hsl(234 40% 97%); color: hsl(234 26% 41%)">
                        {group.role === 'admin' ? 'Admin' : 'Co-admin'}
                      </span>
                    {/if}
                  </div>
                  {#if group.description}
                    <p class="text-xs text-muted-foreground truncate mt-0.5">{group.description}</p>
                  {/if}
                </div>
              </button>
              <div class="flex items-center gap-1 shrink-0">
                <button
                  onclick={() => toggleFavorite(group.id, group.is_favorited)}
                  disabled={actionLoading === group.id}
                  class="p-2 rounded-lg hover:bg-muted transition-colors disabled:opacity-50"
                  title="Pin to top"
                >
                  <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="hsl(234 12% 52%)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/>
                  </svg>
                </button>
                {#if group.role !== 'admin'}
                  <button
                    onclick={() => leaveGroup(group.id, group.name, group.role)}
                    disabled={actionLoading === group.id}
                    class="p-2 rounded-lg hover:bg-muted transition-colors disabled:opacity-50"
                    style="color: hsl(234 12% 52%)"
                    title="Leave group"
                  >
                    <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                      <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/>
                      <polyline points="16 17 21 12 16 7"/>
                      <line x1="21" y1="12" x2="9" y2="12"/>
                    </svg>
                  </button>
                {/if}
              </div>
            </div>
          {/each}
        </div>
      </div>
    {/if}

  {/if}
</div>