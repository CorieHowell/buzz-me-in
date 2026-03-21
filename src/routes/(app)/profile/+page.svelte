<script>
  import { supabase } from '$lib/supabase'
  import { goto } from '$app/navigation'
  import { onMount } from 'svelte'
  import PhotoUploader from '$lib/components/PhotoUploader.svelte'

  let profile = $state(null)
  let avatarUrl = $state(null)
  let userId = $state(null)
  let loading = $state(true)
  let saving = $state(false)
  let saved = $state(false)
  let error = $state('')
  let editing = $state(false)
  let groupCount = $state(0)
  let eventCount = $state(0)
  let memberSince = $state('')
  let groups = $state([])

  let displayName = $state('')
  let city = $state('')
  let stateVal = $state('')
  let bio = $state('')
  let instagramHandle = $state('')
  let twitterHandle = $state('')
  let websiteUrl = $state('')
  let hideGroups = $state(false)

  onMount(async () => {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) { goto('/auth/login'); return }
    userId = user.id

    const { data } = await supabase
      .from('users')
      .select('*')
      .eq('id', user.id)
      .single()

    profile = data
    avatarUrl = data?.avatar_url ?? null
    displayName = data?.display_name ?? ''
    city = data?.city ?? ''
    stateVal = data?.state ?? ''
    bio = data?.bio ?? ''
    instagramHandle = data?.instagram_handle ?? ''
    twitterHandle = data?.twitter_handle ?? ''
    websiteUrl = data?.website_url ?? ''
    hideGroups = data?.hide_groups ?? false
    memberSince = new Date(data?.created_at).toLocaleDateString('en-US', { month: 'short', year: 'numeric' })

    const { count: gCount } = await supabase
      .from('group_members')
      .select('*', { count: 'exact', head: true })
      .eq('user_id', user.id)
    groupCount = gCount ?? 0

    const { count: eCount } = await supabase
      .from('event_rsvps')
      .select('*', { count: 'exact', head: true })
      .eq('user_id', user.id)
      .eq('status', 'going')
    eventCount = eCount ?? 0

    const { data: groupData } = await supabase
      .from('group_members')
      .select('role, groups(id, name)')
      .eq('user_id', user.id)
      .order('joined_at', { ascending: true })
    groups = groupData ?? []

    loading = false
  })

  async function saveAvatarUrl(url) {
    if (!userId) return
    await supabase.from('users').update({ avatar_url: url }).eq('id', userId)
  }

  async function saveProfile() {
    saving = true
    error = ''
    const { data: { user } } = await supabase.auth.getUser()
    const { error: updateError } = await supabase
      .from('users')
      .update({
        display_name: displayName.trim(),
        city: city.trim() || null,
        state: stateVal.trim() || null,
        bio: bio.trim() || null,
        instagram_handle: instagramHandle.trim() || null,
        twitter_handle: twitterHandle.trim() || null,
        website_url: websiteUrl.trim() || null,
        hide_groups: hideGroups,
      })
      .eq('id', user.id)

    if (updateError) { error = updateError.message; saving = false; return }
    profile = { ...profile, display_name: displayName, hide_groups: hideGroups }
    saved = true
    editing = false
    setTimeout(() => saved = false, 2000)
    saving = false
  }

  async function signOut() {
    await supabase.auth.signOut()
    goto('/auth/login')
  }

  function initials(name) {
    if (!name) return '?'
    return name.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2)
  }
</script>

<div class="max-w-lg mx-auto px-4 py-6">

  {#if loading}
    <div class="flex flex-col gap-4 animate-pulse">
      <div class="flex items-center gap-4">
        <div class="w-16 h-16 rounded-full bg-muted shrink-0"></div>
        <div class="flex-1">
          <div class="h-5 bg-muted rounded w-1/3 mb-2"></div>
          <div class="h-3 bg-muted rounded w-1/4"></div>
        </div>
      </div>
    </div>

  {:else}

    <!-- Avatar + name -->
    <div class="flex items-center gap-4 mb-6">
      <PhotoUploader
        bucket="avatars"
        pathPrefix={userId}
        bind:value={avatarUrl}
        shape="circle"
        size="lg"
        onchange={saveAvatarUrl}
      />
      <div class="flex-1 min-w-0">
        <h1 class="text-xl font-semibold text-foreground">{profile?.display_name}</h1>
        {#if profile?.city}
          <p class="text-sm text-muted-foreground">{profile.city}{profile.state ? `, ${profile.state}` : ''}</p>
        {/if}
      </div>
      <button
        onclick={() => editing = !editing}
        class="px-4 py-2 rounded-xl text-sm font-medium border transition-colors"
        style={editing
          ? 'border-color: hsl(234 26% 41%); color: hsl(234 26% 41%); background: hsl(234 40% 97%)'
          : 'border-color: hsl(234 20% 88%); color: hsl(234 12% 52%)'}
      >
        {editing ? 'Cancel' : 'Edit'}
      </button>
    </div>

    <!-- Stat cards -->
    <div class="grid grid-cols-3 gap-3 mb-6">
      {#if !profile?.hide_groups}
        <div class="rounded-xl border border-border p-3 flex flex-col items-center justify-end min-h-[72px]" style="background: hsl(234 40% 97%)">
          <p class="text-2xl font-bold leading-none" style="color: hsl(234 26% 41%)">{groupCount}</p>
          <p class="text-xs text-muted-foreground mt-1">Groups</p>
        </div>
      {/if}
      <div class="rounded-xl border border-border p-3 flex flex-col items-center justify-end min-h-[72px] {profile?.hide_groups ? 'col-span-2' : ''}">
        <p class="text-2xl font-bold leading-none text-foreground">{eventCount}</p>
        <p class="text-xs text-muted-foreground mt-1">Events attended</p>
      </div>
      <div class="rounded-xl border border-border p-3 flex flex-col items-center justify-end min-h-[72px]">
        <p class="font-bold leading-none text-foreground" style="font-size: 1rem; line-height: 1.4">{memberSince}</p>
        <p class="text-xs text-muted-foreground mt-1">Member since</p>
      </div>
    </div>

    {#if !editing}

      <!-- View mode -->
      {#if profile?.bio}
        <div class="mb-4">
          <p class="text-sm text-foreground">{profile.bio}</p>
        </div>
      {/if}

      {#if profile?.instagram_handle || profile?.twitter_handle || profile?.website_url}
        <div class="flex flex-col gap-2 mb-6">
          {#if profile?.instagram_handle}
            <a href="https://instagram.com/{profile.instagram_handle}" target="_blank" rel="noopener"
              class="flex items-center gap-2 text-sm" style="color: hsl(234 26% 41%)">
              <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                <rect x="2" y="2" width="20" height="20" rx="5" ry="5"/><path d="M16 11.37A4 4 0 1 1 12.63 8 4 4 0 0 1 16 11.37z"/><line x1="17.5" y1="6.5" x2="17.51" y2="6.5"/>
              </svg>
              @{profile.instagram_handle}
            </a>
          {/if}
          {#if profile?.twitter_handle}
            <a href="https://twitter.com/{profile.twitter_handle}" target="_blank" rel="noopener"
              class="flex items-center gap-2 text-sm" style="color: hsl(234 26% 41%)">
              <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                <path d="M23 3a10.9 10.9 0 0 1-3.14 1.53 4.48 4.48 0 0 0-7.86 3v1A10.66 10.66 0 0 1 3 4s-4 9 5 13a11.64 11.64 0 0 1-7 2c9 5 20 0 20-11.5a4.5 4.5 0 0 0-.08-.83A7.72 7.72 0 0 0 23 3z"/>
              </svg>
              @{profile.twitter_handle}
            </a>
          {/if}
          {#if profile?.website_url}
            <a href={profile.website_url} target="_blank" rel="noopener"
              class="flex items-center gap-2 text-sm truncate" style="color: hsl(234 26% 41%)">
              <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                <circle cx="12" cy="12" r="10"/><line x1="2" y1="12" x2="22" y2="12"/><path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"/>
              </svg>
              {profile.website_url.replace(/^https?:\/\//, '')}
            </a>
          {/if}
        </div>
      {/if}

      <!-- Groups list -->
      {#if !profile?.hide_groups && groups.length > 0}
        <div class="mb-6">
          <p class="text-xs font-semibold uppercase tracking-wider text-muted-foreground mb-3">Groups</p>
          <div class="flex flex-col gap-2">
            {#each groups as membership}
              <a href="/groups/{membership.groups?.id}"
                class="flex items-center gap-3 rounded-xl border border-border p-3 hover:bg-muted/30 transition-colors">
                <div class="w-8 h-8 rounded-lg flex items-center justify-center text-xs font-bold text-white shrink-0" style="background: hsl(234 26% 41%)">
                  {initials(membership.groups?.name)}
                </div>
                <p class="text-sm font-medium text-foreground flex-1 truncate">{membership.groups?.name}</p>
                {#if membership.role !== 'member'}
                  <span class="text-xs px-2 py-0.5 rounded-full shrink-0" style="background: hsl(234 40% 97%); color: hsl(234 26% 41%)">
                    {membership.role === 'admin' ? 'Admin' : 'Co-admin'}
                  </span>
                {/if}
              </a>
            {/each}
          </div>
        </div>
      {/if}

      <div class="border-t border-border pt-5">
        <button onclick={signOut} class="flex items-center gap-2 text-sm font-medium text-destructive">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
            <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/>
            <polyline points="16 17 21 12 16 7"/>
            <line x1="21" y1="12" x2="9" y2="12"/>
          </svg>
          Sign out
        </button>
      </div>

    {:else}

      <!-- Edit mode -->
      <div class="flex flex-col gap-4">

        <div class="flex flex-col gap-1.5">
          <label class="text-sm font-medium text-foreground">Display name</label>
          <input type="text" bind:value={displayName} maxlength="60"
            class="w-full px-3 py-2.5 rounded-xl border border-input bg-background text-sm focus:outline-none focus:ring-2 focus:ring-ring" />
        </div>

        <div class="grid grid-cols-2 gap-3">
          <div class="flex flex-col gap-1.5">
            <label class="text-sm font-medium text-foreground">City</label>
            <input type="text" bind:value={city} placeholder="Phoenix"
              class="w-full px-3 py-2.5 rounded-xl border border-input bg-background text-sm focus:outline-none focus:ring-2 focus:ring-ring" />
          </div>
          <div class="flex flex-col gap-1.5">
            <label class="text-sm font-medium text-foreground">State</label>
            <input type="text" bind:value={stateVal} placeholder="AZ" maxlength="2"
              class="w-full px-3 py-2.5 rounded-xl border border-input bg-background text-sm focus:outline-none focus:ring-2 focus:ring-ring" />
          </div>
        </div>

        <div class="flex flex-col gap-1.5">
          <label class="text-sm font-medium text-foreground">Bio <span class="text-muted-foreground font-normal">(optional)</span></label>
          <textarea bind:value={bio} placeholder="A little about you…" rows="2" maxlength="200"
            class="w-full px-3 py-2.5 rounded-xl border border-input bg-background text-sm focus:outline-none focus:ring-2 focus:ring-ring resize-none"></textarea>
        </div>

        <div class="flex flex-col gap-1.5">
          <label class="text-sm font-medium text-foreground">Instagram</label>
          <div class="flex items-center gap-2">
            <span class="text-sm text-muted-foreground">@</span>
            <input type="text" bind:value={instagramHandle} placeholder="yourhandle"
              class="flex-1 px-3 py-2.5 rounded-xl border border-input bg-background text-sm focus:outline-none focus:ring-2 focus:ring-ring" />
          </div>
        </div>

        <div class="flex flex-col gap-1.5">
          <label class="text-sm font-medium text-foreground">Twitter / X</label>
          <div class="flex items-center gap-2">
            <span class="text-sm text-muted-foreground">@</span>
            <input type="text" bind:value={twitterHandle} placeholder="yourhandle"
              class="flex-1 px-3 py-2.5 rounded-xl border border-input bg-background text-sm focus:outline-none focus:ring-2 focus:ring-ring" />
          </div>
        </div>

        <div class="flex flex-col gap-1.5">
          <label class="text-sm font-medium text-foreground">Website</label>
          <input type="url" bind:value={websiteUrl} placeholder="https://yoursite.com"
            class="w-full px-3 py-2.5 rounded-xl border border-input bg-background text-sm focus:outline-none focus:ring-2 focus:ring-ring" />
        </div>

        <label class="flex items-start gap-3 p-4 rounded-xl border border-border cursor-pointer">
          <input type="checkbox" bind:checked={hideGroups} class="mt-0.5 accent-[hsl(234,26%,41%)]" />
          <div>
            <p class="text-sm font-medium text-foreground">Hide my groups from my profile</p>
            <p class="text-xs text-muted-foreground mt-0.5">Other members won't see which groups you belong to. Your group count stat will also be hidden.</p>
          </div>
        </label>

        {#if error}
          <p class="text-sm text-destructive">{error}</p>
        {/if}

        <button onclick={saveProfile} disabled={saving}
          class="w-full py-2.5 rounded-xl text-sm font-semibold text-white transition-opacity disabled:opacity-60"
          style="background: hsl(234 26% 41%)">
          {saving ? 'Saving…' : saved ? '✓ Saved' : 'Save profile'}
        </button>

      </div>

    {/if}

  {/if}
</div>