<script>
  import { supabase } from '$lib/supabase'
  import { page } from '$app/stores'
  import { goto } from '$app/navigation'
  import { onMount } from 'svelte'

  let groupId = $derived($page.params.id)
  let members = $state([])
  let pendingRequests = $state([])
  let loading = $state(true)
  let currentUserId = $state(null)
  let currentUserRole = $state(null)
  let actionLoading = $state(null)

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
    await loadMembers()
    loading = false
  })

  async function loadMembers() {
    const { data } = await supabase
      .from('group_members')
      .select('user_id, role, joined_at, users(display_name, avatar_url, city, state)')
      .eq('group_id', groupId)
      .order('joined_at', { ascending: true })

    members = data ?? []

    if (currentUserRole === 'admin' || currentUserRole === 'co_admin') {
      const { data: requests } = await supabase
        .from('join_requests')
        .select('id, user_id, requested_at, users(display_name, avatar_url)')
        .eq('group_id', groupId)
        .eq('status', 'pending')
        .order('requested_at', { ascending: true })
      pendingRequests = requests ?? []
    }
  }

  async function approveRequest(requestId, userId) {
    actionLoading = requestId
    await supabase.from('join_requests')
      .update({ status: 'approved', actioned_at: new Date().toISOString() })
      .eq('id', requestId)
    await supabase.from('group_members').insert({
      group_id: groupId, user_id: userId, role: 'member',
    })
    await loadMembers()
    actionLoading = null
  }

  async function declineRequest(requestId) {
    actionLoading = requestId
    await supabase.from('join_requests')
      .update({ status: 'declined', actioned_at: new Date().toISOString() })
      .eq('id', requestId)
    await loadMembers()
    actionLoading = null
  }

  async function changeRole(userId, newRole) {
    actionLoading = userId
    await supabase.from('group_members')
      .update({ role: newRole })
      .eq('group_id', groupId)
      .eq('user_id', userId)
    await loadMembers()
    actionLoading = null
  }

  async function removeMember(userId) {
    if (!confirm('Remove this member from the group?')) return
    actionLoading = userId
    await supabase.from('group_members')
      .delete()
      .eq('group_id', groupId)
      .eq('user_id', userId)
    await loadMembers()
    actionLoading = null
  }

  function timeAgo(dateStr) {
    const days = Math.floor((Date.now() - new Date(dateStr).getTime()) / 86400000)
    if (days === 0) return 'today'
    if (days === 1) return 'yesterday'
    if (days < 30) return `${days}d ago`
    const months = Math.floor(days / 30)
    if (months < 12) return `${months}mo ago`
    return `${Math.floor(months / 12)}y ago`
  }

  function initials(name) {
    if (!name) return '?'
    return name.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2)
  }

  let isAdmin = $derived(currentUserRole === 'admin' || currentUserRole === 'co_admin')
</script>

<div class="flex flex-col">

  <!-- Section header -->
  <header class="shrink-0 flex items-center justify-between px-6 py-5 bg-background border-b border-border sticky top-0 z-10">
    <h1 class="text-xl font-bold tracking-tight" style="color: hsl(267.7 52.54% 9%)">Members</h1>
    <a
      href="/groups/{groupId}/invite"
      class="px-4 py-2 rounded-full text-sm font-semibold text-white"
      style="background: hsl(234 26% 41%)"
    >
      Invite
    </a>
  </header>

  <div class="max-w-2xl mx-auto px-4 py-6 w-full">

  {#if loading}
    <div class="flex flex-col gap-3">
      {#each [1,2,3] as _}
        <div class="rounded-xl bg-white p-4 animate-pulse">
          <div class="flex items-center gap-3">
            <div class="w-10 h-10 rounded-full bg-muted shrink-0"></div>
            <div class="flex-1">
              <div class="h-4 bg-muted rounded w-1/3 mb-2"></div>
              <div class="h-3 bg-muted rounded w-1/4"></div>
            </div>
          </div>
        </div>
      {/each}
    </div>

  {:else}

    <!-- Pending requests -->
    {#if isAdmin && pendingRequests.length > 0}
      <div class="mb-6">
        <h3 class="text-xs font-semibold uppercase tracking-wider text-muted-foreground mb-3">
          Pending requests ({pendingRequests.length})
        </h3>
        <div class="flex flex-col gap-2">
          {#each pendingRequests as request}
            <div class="flex items-center gap-3 rounded-xl border p-4" style="border-color: hsl(234 26% 41%); background: hsl(234 40% 97%)">
              {#if request.users?.avatar_url}
                <img src={request.users.avatar_url} alt={request.users.display_name} class="w-10 h-10 rounded-full object-cover shrink-0" />
              {:else}
                <div class="w-10 h-10 rounded-full flex items-center justify-center text-sm font-semibold text-white shrink-0" style="background: hsl(234 26% 41%)">
                  {initials(request.users?.display_name)}
                </div>
              {/if}
              <div class="flex-1 min-w-0">
                <p class="text-sm font-semibold text-foreground">{request.users?.display_name}</p>
                <p class="text-xs text-muted-foreground">Requested {timeAgo(request.requested_at)}</p>
              </div>
              <div class="flex gap-2 shrink-0">
                <button
                  onclick={() => approveRequest(request.id, request.user_id)}
                  disabled={actionLoading === request.id}
                  class="px-3 py-1.5 rounded-lg text-xs font-semibold text-white disabled:opacity-50"
                  style="background: hsl(234 26% 41%)"
                >
                  Approve
                </button>
                <button
                  onclick={() => declineRequest(request.id)}
                  disabled={actionLoading === request.id}
                  class="px-3 py-1.5 rounded-lg text-xs font-medium border disabled:opacity-50"
                  style="border-color: hsl(234 20% 88%); color: hsl(234 12% 52%)"
                >
                  Decline
                </button>
              </div>
            </div>
          {/each}
        </div>
      </div>
    {/if}

    <!-- Invite card — admin only -->
    {#if isAdmin}
      <a
        href="/groups/{groupId}/invite"
        class="flex items-center gap-3 rounded-xl p-4 mb-5 hover:opacity-90 transition-opacity"
        style="background: hsl(234 20% 91%)"
      >
        <div class="w-9 h-9 rounded-full flex items-center justify-center shrink-0" style="background: hsl(234 26% 41%)">
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/>
            <path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/>
          </svg>
        </div>
        <div class="flex-1 min-w-0">
          <p class="text-sm font-semibold text-foreground">Invite members</p>
          <p class="text-xs text-muted-foreground">Share a link or QR code</p>
        </div>
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="hsl(234 12% 52%)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <polyline points="9 18 15 12 9 6"/>
        </svg>
      </a>
    {/if}

    <!-- Members list -->
    <div class="flex items-center justify-between mb-3">
      <h3 class="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
        Members ({members.length})
      </h3>
    </div>

    <div class="flex flex-col gap-2">
      {#each members as member}
        {@const isMe = member.user_id === currentUserId}
        {@const isMemberAdmin = member.role === 'admin'}

        <div class="flex items-center gap-3 rounded-xl bg-white p-4">
          {#if member.users?.avatar_url}
            <img src={member.users.avatar_url} alt={member.users.display_name} class="w-10 h-10 rounded-full object-cover shrink-0" />
          {:else}
            <div class="w-10 h-10 rounded-full flex items-center justify-center text-sm font-semibold text-white shrink-0" style="background: hsl(234 26% 41%)">
              {initials(member.users?.display_name)}
            </div>
          {/if}

          <div class="flex-1 min-w-0">
            <div class="flex items-center gap-2">
              <p class="text-sm font-semibold text-foreground truncate">
                {member.users?.display_name}{isMe ? ' (you)' : ''}
              </p>
              {#if member.role !== 'member'}
                <span class="text-xs px-2 py-0.5 rounded-full shrink-0 font-medium" style="background: hsl(234 40% 97%); color: hsl(234 26% 41%)">
                  {member.role === 'admin' ? 'Admin' : 'Co-admin'}
                </span>
              {/if}
            </div>
            {#if member.users?.city}
              <p class="text-xs text-muted-foreground">{member.users.city}{member.users.state ? `, ${member.users.state}` : ''}</p>
            {/if}

            <!-- Anonymous suggestion link — only show to non-admins, next to admin row -->
            {#if isMemberAdmin && !isAdmin && !isMe}
              <a
                href="/groups/{groupId}/suggest"
                class="text-xs mt-1 inline-block"
                style="color: hsl(234 26% 41%)"
              >
                Send anonymous suggestion
              </a>
            {/if}
          </div>

          <!-- Actions -->
          <div class="flex items-center gap-1 shrink-0">
            <!-- Message button — everyone except yourself -->
            {#if !isMe}
              <a
                href="/messages/{member.user_id}"
                class="p-2 rounded-lg hover:bg-muted transition-colors"
                style="color: hsl(234 12% 52%)"
                title="Send message"
              >
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                  <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
                </svg>
              </a>
            {/if}

            <!-- Admin actions -->
            {#if isAdmin && !isMe && !isMemberAdmin}
              {#if member.role === 'member'}
                <button
                  onclick={() => changeRole(member.user_id, 'co_admin')}
                  disabled={actionLoading === member.user_id}
                  class="p-2 rounded-lg hover:bg-muted transition-colors disabled:opacity-50"
                  style="color: hsl(234 12% 52%)"
                  title="Make co-admin"
                >
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/>
                  </svg>
                </button>
              {:else if member.role === 'co_admin'}
                <button
                  onclick={() => changeRole(member.user_id, 'member')}
                  disabled={actionLoading === member.user_id}
                  class="p-2 rounded-lg hover:bg-muted transition-colors disabled:opacity-50"
                  style="color: hsl(234 12% 52%)"
                  title="Remove co-admin"
                >
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/>
                    <line x1="2" y1="2" x2="22" y2="22"/>
                  </svg>
                </button>
              {/if}
              <button
                onclick={() => removeMember(member.user_id)}
                disabled={actionLoading === member.user_id}
                class="p-2 rounded-lg hover:bg-muted transition-colors disabled:opacity-50"
                style="color: hsl(234 12% 52%)"
                title="Remove member"
              >
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                  <path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
                  <circle cx="8.5" cy="7" r="4"/>
                  <line x1="18" y1="8" x2="23" y2="13"/>
                  <line x1="23" y1="8" x2="18" y2="13"/>
                </svg>
              </button>
            {/if}
          </div>
        </div>
      {/each}
    </div>

  {/if}
  </div>
</div>