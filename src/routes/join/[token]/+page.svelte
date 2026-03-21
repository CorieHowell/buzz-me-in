<script>
  import { supabase } from '$lib/supabase'
  import { page } from '$app/stores'
  import { goto } from '$app/navigation'
  import { onMount } from 'svelte'

  let token = $derived($page.params.token)
  let group = $state(null)
  let memberCount = $state(0)
  let loading = $state(true)
  let joining = $state(false)
  let error = $state('')
  let status = $state('preview')
  let currentUser = $state(null)
  let adminUserId = $state(null)

  onMount(async () => {
    const { data: groupData } = await supabase
      .from('groups')
      .select('id, name, description, approval_mode')
      .eq('invite_token', token)
      .eq('is_archived', false)
      .single()

    if (!groupData) { status = 'not_found'; loading = false; return }
    group = groupData

    const { count } = await supabase
      .from('group_members')
      .select('*', { count: 'exact', head: true })
      .eq('group_id', groupData.id)
    memberCount = count ?? 0

    // Get admin for notifications
    const { data: adminData } = await supabase
      .from('group_members')
      .select('user_id')
      .eq('group_id', groupData.id)
      .eq('role', 'admin')
      .single()
    adminUserId = adminData?.user_id ?? null

    const { data: { user } } = await supabase.auth.getUser()
    currentUser = user

    if (user) {
      const { data: existing } = await supabase
        .from('group_members')
        .select('role')
        .eq('group_id', groupData.id)
        .eq('user_id', user.id)
        .single()

      if (existing) { status = 'already_member'; loading = false; return }

      const { data: existingRequest } = await supabase
        .from('join_requests')
        .select('status')
        .eq('group_id', groupData.id)
        .eq('user_id', user.id)
        .single()

      if (existingRequest?.status === 'pending') { status = 'pending'; loading = false; return }
    }

    loading = false
  })

  async function handleJoin() {
    if (!currentUser) {
      sessionStorage.setItem('join_token', token)
      goto(`/auth/signup?next=/join/${token}`)
      return
    }

    joining = true
    error = ''

    // Get joiner's display name for notification
    const { data: joinerProfile } = await supabase
      .from('users')
      .select('display_name')
      .eq('id', currentUser.id)
      .single()
    const joinerName = joinerProfile?.display_name ?? 'Someone'

    if (group.approval_mode === 'open') {
      const { error: joinError } = await supabase
        .from('group_members')
        .insert({ group_id: group.id, user_id: currentUser.id, role: 'member' })

      if (joinError) { error = joinError.message; joining = false; return }

      // Notify admin of new member
      if (adminUserId && adminUserId !== currentUser.id) {
        await supabase.from('notifications').insert({
          user_id: adminUserId,
          type: 'new_member',
          body: `${joinerName} joined ${group.name}.`,
          link: `/groups/${group.id}/members`,
        })
      }

      status = 'joined'
    } else {
      const { error: reqError } = await supabase
        .from('join_requests')
        .insert({ group_id: group.id, user_id: currentUser.id, status: 'pending' })

      if (reqError) { error = reqError.message; joining = false; return }

      // Notify admin of join request
      if (adminUserId && adminUserId !== currentUser.id) {
        await supabase.from('notifications').insert({
          user_id: adminUserId,
          type: 'join_request',
          body: `${joinerName} requested to join ${group.name}.`,
          link: `/groups/${group.id}/members`,
        })
      }

      status = 'pending'
    }

    joining = false
  }

  function initials(name) {
    if (!name) return '?'
    return name.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2)
  }
</script>

<div class="min-h-screen bg-background flex items-center justify-center px-4">
  <div class="w-full max-w-sm">

    {#if loading}
      <div class="flex justify-center py-16">
        <div class="w-5 h-5 rounded-full border-2 border-muted animate-spin" style="border-top-color: hsl(234 26% 41%)"></div>
      </div>

    {:else if status === 'not_found'}
      <div class="text-center">
        <div class="w-16 h-16 rounded-2xl flex items-center justify-center mx-auto mb-4" style="background: hsl(234 40% 97%)">
          <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="hsl(234 26% 41%)" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
            <circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/>
          </svg>
        </div>
        <h1 class="text-xl font-semibold text-foreground mb-2">Link not found</h1>
        <p class="text-sm text-muted-foreground">This invite link may have expired or been revoked.</p>
        <a href="/" class="inline-block mt-6 text-sm font-medium" style="color: hsl(234 26% 41%)">Go home</a>
      </div>

    {:else if status === 'already_member'}
      <div class="text-center">
        <div class="w-16 h-16 rounded-2xl flex items-center justify-center mx-auto mb-4" style="background: hsl(234 40% 97%)">
          <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="hsl(234 26% 41%)" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
            <polyline points="20 6 9 17 4 12"/>
          </svg>
        </div>
        <h1 class="text-xl font-semibold text-foreground mb-2">You're already in</h1>
        <p class="text-sm text-muted-foreground mb-6">You're already a member of <span class="font-medium text-foreground">{group.name}</span>.</p>
        <button
          onclick={() => goto(`/groups/${group.id}`)}
          class="w-full py-2.5 rounded-xl text-sm font-semibold text-white"
          style="background: hsl(234 26% 41%)"
        >
          Go to group
        </button>
      </div>

    {:else if status === 'pending'}
      <div class="text-center">
        <div class="w-16 h-16 rounded-2xl flex items-center justify-center mx-auto mb-4" style="background: hsl(234 40% 97%)">
          <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="hsl(234 26% 41%)" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
            <circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/>
          </svg>
        </div>
        <h1 class="text-xl font-semibold text-foreground mb-2">Request sent</h1>
        <p class="text-sm text-muted-foreground">Your request to join <span class="font-medium text-foreground">{group.name}</span> is pending. You'll be notified when the admin approves it.</p>
      </div>

    {:else if status === 'joined'}
      <div class="text-center">
        <div class="w-16 h-16 rounded-2xl flex items-center justify-center mx-auto mb-4" style="background: hsl(234 40% 97%)">
          <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="hsl(234 26% 41%)" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
            <polyline points="20 6 9 17 4 12"/>
          </svg>
        </div>
        <h1 class="text-xl font-semibold text-foreground mb-2">You're in!</h1>
        <p class="text-sm text-muted-foreground mb-6">Welcome to <span class="font-medium text-foreground">{group.name}</span>.</p>
        <button
          onclick={() => goto(`/groups/${group.id}`)}
          class="w-full py-2.5 rounded-xl text-sm font-semibold text-white"
          style="background: hsl(234 26% 41%)"
        >
          Go to group
        </button>
      </div>

    {:else}
      <div class="text-center mb-8">
        <div class="w-16 h-16 rounded-2xl flex items-center justify-center mx-auto mb-4 text-xl font-bold text-white" style="background: hsl(234 26% 41%)">
          {initials(group.name)}
        </div>
        <h1 class="text-xl font-semibold text-foreground">{group.name}</h1>
        {#if group.description}
          <p class="text-sm text-muted-foreground mt-1">{group.description}</p>
        {/if}
        <p class="text-xs text-muted-foreground mt-2">{memberCount} {memberCount === 1 ? 'member' : 'members'}</p>
      </div>

      <div class="flex items-center gap-2 p-3 rounded-xl mb-6" style="background: hsl(234 40% 97%)">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="hsl(234 26% 41%)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          {#if group.approval_mode === 'open'}
            <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/>
          {:else}
            <rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>
          {/if}
        </svg>
        <p class="text-xs font-medium" style="color: hsl(234 26% 41%)">
          {group.approval_mode === 'open'
            ? "You'll join instantly"
            : 'Your request will be reviewed by the admin'}
        </p>
      </div>

      {#if error}
        <p class="text-sm text-destructive mb-4">{error}</p>
      {/if}

      <button
        onclick={handleJoin}
        disabled={joining}
        class="w-full py-2.5 rounded-xl text-sm font-semibold text-white transition-opacity disabled:opacity-60 mb-3"
        style="background: hsl(234 26% 41%)"
      >
        {#if joining}
          Joining…
        {:else if !currentUser}
          Sign up to join
        {:else if group.approval_mode === 'open'}
          Join group
        {:else}
          Request to join
        {/if}
      </button>

      {#if !currentUser}
        <p class="text-center text-xs text-muted-foreground">
          Already have an account?
          <a href="/auth/login?next=/join/{token}" class="font-medium" style="color: hsl(234 26% 41%)">Sign in</a>
        </p>
      {/if}

    {/if}
  </div>
</div>