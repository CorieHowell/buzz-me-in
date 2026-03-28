<script>
  import { supabase } from '$lib/supabase'
  import { page } from '$app/stores'
  import { goto } from '$app/navigation'
  import { onMount, getContext, tick } from 'svelte'

  const { clearBoardBadge } = getContext('groupLayout') ?? {}

  let groupId = $derived($page.params.id)
  let posts = $state([])
  let loading = $state(true)
  let currentUserId = $state(null)
  let currentUserRole = $state(null)
  let adminUserId = $state(null)
  let newPostTitle = $state('')
  let newPostBody = $state('')
  let posting = $state(false)
  let postError = $state('')
  let showComposer = $state(false)
  let composerTextareaEl = $state(null)
  let composerTitleEl = $state(null)
  let expandedPosts = $state(new Set())
  let replyBodies = $state({})
  let replyingTo = $state(null)
  let submittingReply = $state(false)
  let emojiPickerPostId = $state(null)
  let searchQuery = $state('')
  let searchOpen = $state(false)
  let searchInputEl = $state(null)

  let filteredPosts = $derived(
    searchQuery.trim() === ''
      ? posts
      : posts.filter(p =>
          p.body?.toLowerCase().includes(searchQuery.toLowerCase()) ||
          p.users?.display_name?.toLowerCase().includes(searchQuery.toLowerCase())
        )
  )

  async function openComposer() {
    showComposer = true
    await tick()
    ;(composerTitleEl ?? composerTextareaEl)?.focus()
  }

  function closeComposer() {
    showComposer = false
    newPostTitle = ''
    newPostBody = ''
    postError = ''
  }

  function openSearch() {
    searchOpen = true
    setTimeout(() => searchInputEl?.focus(), 50)
  }

  const EMOJI_OPTIONS = ['❤️', '👍', '😂', '😮', '🙌', '🔥']

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

    const { data: adminData } = await supabase
      .from('group_members')
      .select('user_id')
      .eq('group_id', groupId)
      .eq('role', 'admin')
      .single()

    adminUserId = adminData?.user_id ?? null

    await loadPosts()

    // Mark board as visited and clear badge
    if (typeof localStorage !== 'undefined') {
      localStorage.setItem(`board_last_visit_${groupId}`, Date.now().toString())
    }
    clearBoardBadge?.()
  })

  async function loadPosts() {
    loading = true
    const { data } = await supabase
      .from('posts')
      .select(`
        id, title, body, created_at, is_edited, is_deleted, is_announcement,
        author_id,
        users(display_name, avatar_url),
        post_reactions(emoji, user_id),
        replies:posts!parent_id(
          id, body, created_at, is_edited, is_deleted,
          author_id,
          users(display_name, avatar_url)
        )
      `)
      .eq('group_id', groupId)
      .is('parent_id', null)
      .eq('is_deleted', false)
      .order('created_at', { ascending: false })

    const mapped = (data ?? []).map(p => {
      const reactionMap = {}
      for (const r of p.post_reactions ?? []) {
        reactionMap[r.emoji] = (reactionMap[r.emoji] ?? 0) + 1
      }
      return {
        ...p,
        reactions: Object.entries(reactionMap).map(([emoji, count]) => ({ emoji, count })),
        myReaction: (p.post_reactions ?? []).find(r => r.user_id === currentUserId)?.emoji ?? null,
      }
    })

    posts = [
      ...mapped.filter(p => p.is_announcement),
      ...mapped.filter(p => !p.is_announcement),
    ]
    loading = false
  }

  async function submitPost() {
    if (!newPostBody.trim()) return
    posting = true
    postError = ''

    const { error } = await supabase
      .from('posts')
      .insert({
        group_id: groupId,
        author_id: currentUserId,
        title: newPostTitle.trim() || null,
        body: newPostBody.trim(),
      })

    if (error) { postError = error.message; posting = false; return }
    closeComposer()
    await loadPosts()
    posting = false
  }

  async function submitReply(parentId) {
    const body = replyBodies[parentId]?.trim()
    if (!body) return
    submittingReply = true

    const { error } = await supabase
      .from('posts')
      .insert({
        group_id: groupId,
        author_id: currentUserId,
        parent_id: parentId,
        body,
      })

    if (!error) {
      replyBodies[parentId] = ''
      replyingTo = null
      await loadPosts()
    }
    submittingReply = false
  }

  async function deletePost(postId) {
    if (!confirm('Delete this post?')) return
    await supabase
      .from('posts')
      .update({ is_deleted: true })
      .eq('id', postId)
    await loadPosts()
  }

  async function pinPost(postId, currentlyPinned) {
    await supabase
      .from('posts')
      .update({ is_announcement: !currentlyPinned })
      .eq('id', postId)
    await loadPosts()
  }

  async function toggleReaction(postId, emoji) {
    emojiPickerPostId = null
    const post = posts.find(p => p.id === postId)
    if (!post) return
    const prevMyReaction = post.myReaction

    posts = posts.map(p => {
      if (p.id !== postId) return p
      let reactions = [...(p.reactions ?? [])]
      let myReaction = p.myReaction
      if (myReaction) {
        reactions = reactions.map(r => r.emoji === myReaction ? { ...r, count: r.count - 1 } : r).filter(r => r.count > 0)
      }
      if (myReaction !== emoji) {
        const existing = reactions.find(r => r.emoji === emoji)
        reactions = existing
          ? reactions.map(r => r.emoji === emoji ? { ...r, count: r.count + 1 } : r)
          : [...reactions, { emoji, count: 1 }]
        myReaction = emoji
      } else {
        myReaction = null
      }
      return { ...p, reactions, myReaction }
    })

    await supabase.from('post_reactions').delete().eq('post_id', postId).eq('user_id', currentUserId)
    if (prevMyReaction !== emoji) {
      await supabase.from('post_reactions').insert({ post_id: postId, user_id: currentUserId, emoji })
    }
  }

  function toggleReplies(postId) {
    const next = new Set(expandedPosts)
    if (next.has(postId)) next.delete(postId)
    else next.add(postId)
    expandedPosts = next
  }

  function openReplyComposer(postId) {
    replyingTo = replyingTo === postId ? null : postId
    if (replyingTo === postId) {
      const next = new Set(expandedPosts)
      next.add(postId)
      expandedPosts = next
    }
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

  function initials(name) {
    if (!name) return '?'
    return name.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2)
  }

  let isAdmin = $derived(currentUserRole === 'admin' || currentUserRole === 'co_admin')
</script>

<div class="flex flex-col">

  <!-- Section header (desktop only) -->
  <header class="hidden md:flex shrink-0 items-center justify-between px-6 py-4 bg-background border-b border-border sticky top-0 z-10 gap-3">
    <h1 class="text-lg font-bold tracking-tight shrink-0" style="color: hsl(267.7 52.54% 9%)">Message Board</h1>
    <div class="flex items-center gap-2">
      <div class="relative">
        <svg class="absolute left-2.5 top-1/2 -translate-y-1/2 pointer-events-none" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="hsl(234 12% 52%)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/>
        </svg>
        <input
          type="search"
          bind:value={searchQuery}
          placeholder="Search posts…"
          class="pl-8 pr-3 py-1.5 rounded-full text-sm border border-input bg-background focus:outline-none focus:ring-2 focus:ring-ring w-36"
        />
      </div>
      <button
        onclick={openComposer}
        class="px-4 py-1.5 rounded-full text-sm font-semibold text-white shrink-0"
        style="background: hsl(234 26% 41%)"
      >New post</button>
    </div>
  </header>

  <!-- Mobile sticky footer action bar (above bottom tab bar) -->
  <div class="fixed bottom-16 inset-x-0 z-40 md:hidden bg-white border-t border-border/60 px-4 py-2.5 flex items-center gap-2.5">
    {#if searchOpen}
      <!-- Expanded search takes over the full bar -->
      <div class="relative flex-1 flex items-center gap-2">
        <div class="relative flex-1">
          <svg class="absolute left-3 top-1/2 -translate-y-1/2 pointer-events-none" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="hsl(234 12% 52%)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/>
          </svg>
          <input
            bind:this={searchInputEl}
            type="search"
            bind:value={searchQuery}
            placeholder="Search posts…"
            class="pl-8 pr-3 py-2 rounded-full text-sm border border-input bg-gray-50 focus:outline-none focus:ring-2 focus:ring-ring w-full"
          />
        </div>
        <button onclick={() => { searchOpen = false; searchQuery = '' }} class="text-sm font-medium shrink-0" style="color: hsl(234 26% 41%)">Cancel</button>
      </div>
    {:else}
      <!-- Default: search icon + full-width new post button -->
      <button
        onclick={openSearch}
        class="p-2 rounded-full hover:bg-gray-100 transition-colors shrink-0"
        style="color: hsl(234 12% 52%)"
        aria-label="Search"
      >
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/>
        </svg>
      </button>
      <button
        onclick={openComposer}
        class="flex-1 py-2 rounded-full text-sm font-semibold text-white"
        style="background: hsl(234 26% 41%)"
      >New post</button>
    {/if}
  </div>

  <!-- New post composer -->
  {#if showComposer}
    <!-- Desktop modal -->
    <button class="hidden md:block fixed inset-0 z-40 bg-black/30" onclick={closeComposer} tabindex="-1" aria-hidden="true"></button>
    <div class="hidden md:block fixed inset-x-4 top-20 z-50 max-w-xl mx-auto rounded-2xl bg-white p-5" style="box-shadow: 0 8px 32px rgba(0,0,0,0.18)">
      <div class="flex items-center justify-between mb-3">
        <h2 class="text-sm font-semibold text-foreground">New post</h2>
        <button onclick={closeComposer} class="p-1 rounded-lg hover:bg-muted transition-colors" style="color: hsl(234 12% 52%)">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
          </svg>
        </button>
      </div>
      <input
        bind:value={newPostTitle}
        placeholder="Title (optional)"
        class="w-full text-sm font-semibold text-foreground bg-gray-50 rounded-xl px-3 py-2.5 placeholder:text-muted-foreground placeholder:font-normal focus:outline-none focus:ring-2 focus:ring-ring mb-2"
      />
      <textarea
        bind:this={composerTextareaEl}
        bind:value={newPostBody}
        placeholder="Write something to the group…"
        rows="4"
        class="w-full text-sm text-foreground bg-gray-50 rounded-xl px-3 py-2.5 placeholder:text-muted-foreground resize-none focus:outline-none focus:ring-2 focus:ring-ring"
      ></textarea>
      {#if postError}
        <p class="text-xs text-destructive mt-1">{postError}</p>
      {/if}
      <div class="flex items-center justify-end mt-3">
        <button
          onclick={submitPost}
          disabled={posting || !newPostBody.trim()}
          class="px-4 py-1.5 rounded-lg text-sm font-semibold text-white transition-opacity disabled:opacity-40"
          style="background: hsl(234 26% 41%)"
        >
          {posting ? 'Posting…' : 'Post'}
        </button>
      </div>
    </div>

    <!-- Mobile full-screen takeover -->
    <div class="md:hidden fixed inset-0 z-50 bg-white flex flex-col">
      <!-- Header -->
      <div class="shrink-0 flex items-center justify-between px-4 border-b border-border" style="padding-top: 14px; padding-bottom: 14px">
        <button onclick={closeComposer} class="text-sm font-medium" style="color: hsl(234 12% 52%)">Cancel</button>
        <span class="text-lg font-bold text-foreground">New post</span>
        <button
          onclick={submitPost}
          disabled={posting || !newPostBody.trim()}
          class="text-sm font-semibold transition-opacity disabled:opacity-30"
          style="color: hsl(234 26% 41%)"
        >{posting ? 'Posting…' : 'Post'}</button>
      </div>

      <!-- Compose area -->
      <div class="flex-1 flex flex-col px-4 pt-4 pb-4 gap-0 overflow-y-auto">
        <input
          bind:this={composerTitleEl}
          bind:value={newPostTitle}
          placeholder="Title (optional)"
          autofocus
          class="w-full text-xl font-bold text-foreground placeholder:text-muted-foreground placeholder:font-normal focus:outline-none pb-3 border-b border-border/40"
        />
        <textarea
          bind:this={composerTextareaEl}
          bind:value={newPostBody}
          placeholder="Write something to the group…"
          class="flex-1 w-full text-base text-foreground placeholder:text-muted-foreground resize-none focus:outline-none pt-3 min-h-[200px]"
        ></textarea>
        {#if postError}
          <p class="text-xs text-destructive">{postError}</p>
        {/if}
      </div>
    </div>
  {/if}

  <div class="max-w-2xl mx-auto px-4 py-5 w-full pb-16 md:pb-5">

  {#if loading}
    <div class="flex flex-col gap-3">
      {#each [1,2,3] as _}
        <div class="rounded-xl p-4 animate-pulse" style="background: hsl(220 14% 96%)">
          <div class="flex items-center gap-2 mb-3">
            <div class="w-8 h-8 rounded-full bg-gray-200 shrink-0"></div>
            <div class="h-3 bg-gray-200 rounded w-24"></div>
          </div>
          <div class="h-4 bg-gray-200 rounded w-3/4 mb-2"></div>
          <div class="h-3 bg-gray-200 rounded w-1/2"></div>
        </div>
      {/each}
    </div>

  {:else if posts.length === 0}
    <div class="text-center py-16">
      <div class="w-12 h-12 rounded-full flex items-center justify-center mx-auto mb-3" style="background: hsl(234 40% 94%)">
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="hsl(234 26% 41%)" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
          <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
        </svg>
      </div>
      <p class="text-sm font-medium text-foreground mb-1">No posts yet</p>
      <p class="text-xs text-muted-foreground">Be the first to write something to the group.</p>
    </div>

  {:else}
    <div class="flex flex-col gap-3">
      {#each filteredPosts as post}
        {@const visibleReplies = (post.replies ?? []).filter(r => !r.is_deleted)}
        {@const isExpanded = expandedPosts.has(post.id)}
        {@const isOwner = post.author_id === currentUserId}

        <div class="rounded-xl bg-white flex overflow-hidden">

          {#if post.is_announcement}
            <!-- Left stripe with pin icon (matches event card pattern) -->
            <div class="flex flex-col items-center ml-3 my-3 shrink-0 gap-1">
              <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="hsl(234 26% 41%)" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                <line x1="12" y1="17" x2="12" y2="22"/>
                <path d="M5 17h14v-1.76a2 2 0 0 0-1.11-1.79l-1.78-.9A2 2 0 0 1 15 10.76V6h1a2 2 0 0 0 0-4H8a2 2 0 0 0 0 4h1v4.76a2 2 0 0 1-1.11 1.79l-1.78.9A2 2 0 0 0 5 15.24Z"/>
              </svg>
              <div class="w-1 flex-1 rounded-full" style="background: hsl(234 26% 41%)"></div>
            </div>
          {/if}

          <div class="flex-1 min-w-0 p-4">

            <!-- Post header -->
            <div class="flex items-center justify-between mb-2.5">
              <div class="flex items-center gap-2 min-w-0">
                {#if post.users?.avatar_url}
                  <img src={post.users.avatar_url} alt={post.users.display_name} class="w-8 h-8 rounded-full object-cover shrink-0" />
                {:else}
                  <div class="w-8 h-8 rounded-full flex items-center justify-center text-xs font-semibold text-white shrink-0" style="background: hsl(234 26% 41%)">
                    {initials(post.users?.display_name)}
                  </div>
                {/if}
                <div class="min-w-0">
                  <span class="text-sm font-semibold text-foreground">{post.users?.display_name}</span>
                  <span class="text-xs text-muted-foreground ml-1.5">{timeAgo(post.created_at)}</span>
                  {#if post.is_edited}
                    <span class="text-xs text-muted-foreground"> · Edited</span>
                  {/if}
                </div>
              </div>

              {#if isOwner || isAdmin}
                <div class="flex items-center gap-0.5 shrink-0 ml-2">
                  {#if isAdmin}
                    <button
                      onclick={() => pinPost(post.id, post.is_announcement)}
                      class="p-1.5 rounded-lg hover:bg-black/5 transition-colors"
                      style={post.is_announcement ? 'color: hsl(234 26% 41%)' : 'color: hsl(234 12% 62%)'}
                      title={post.is_announcement ? 'Unpin' : 'Pin'}
                    >
                      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <line x1="12" y1="17" x2="12" y2="22"/>
                        <path d="M5 17h14v-1.76a2 2 0 0 0-1.11-1.79l-1.78-.9A2 2 0 0 1 15 10.76V6h1a2 2 0 0 0 0-4H8a2 2 0 0 0 0 4h1v4.76a2 2 0 0 1-1.11 1.79l-1.78.9A2 2 0 0 0 5 15.24Z"/>
                      </svg>
                    </button>
                  {/if}
                  <button
                    onclick={() => deletePost(post.id)}
                    class="p-1.5 rounded-lg hover:bg-black/5 transition-colors"
                    style="color: hsl(234 12% 62%)"
                    title="Delete"
                  >
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                      <polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14H6L5 6"/><path d="M10 11v6"/><path d="M14 11v6"/><path d="M9 6V4h6v2"/>
                    </svg>
                  </button>
                </div>
              {/if}
            </div>

            <!-- Post title + body -->
            {#if post.title}
              <p class="font-bold leading-snug mb-1" style="font-size: 16px; color: hsl(267.7 52.54% 9%)">{post.title}</p>
            {/if}
            <p class="text-sm text-foreground whitespace-pre-wrap leading-relaxed">{post.body}</p>

            <!-- Reactions + action bar -->
            <div class="flex items-center gap-1.5 flex-wrap mt-3 pt-3 border-t border-black/5">
              {#each (post.reactions ?? []) as r}
                <button
                  onclick={() => toggleReaction(post.id, r.emoji)}
                  class="flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-medium transition-colors"
                  style={post.myReaction === r.emoji
                    ? 'background: hsl(234 40% 94%); color: hsl(234 26% 41%); border: 1px solid hsl(234 26% 80%)'
                    : 'background: white; color: hsl(220 9% 40%); border: 1px solid transparent'}
                >{r.emoji} {r.count}</button>
              {/each}

              <!-- Emoji picker -->
              <div class="relative">
                <button
                  onclick={() => emojiPickerPostId = emojiPickerPostId === post.id ? null : post.id}
                  class="flex items-center justify-center w-7 h-7 rounded-full hover:bg-black/5 transition-colors"
                  style="color: hsl(220 9% 55%)"
                  title="Add reaction"
                >
                  <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                    <circle cx="12" cy="12" r="10"/>
                    <path d="M8 14s1.5 2 4 2 4-2 4-2"/>
                    <line x1="9" y1="9" x2="9.01" y2="9"/>
                    <line x1="15" y1="9" x2="15.01" y2="9"/>
                  </svg>
                </button>
                {#if emojiPickerPostId === post.id}
                  <button class="fixed inset-0 z-40 cursor-default" onclick={() => emojiPickerPostId = null} tabindex="-1" aria-hidden="true"></button>
                  <div class="absolute left-0 bottom-full mb-1.5 flex gap-1 bg-white rounded-xl border border-border px-2 py-1.5 z-50" style="box-shadow: 0 4px 20px rgba(0,0,0,0.12)">
                    {#each EMOJI_OPTIONS as emoji}
                      <button onclick={() => toggleReaction(post.id, emoji)} class="text-lg hover:scale-125 transition-transform leading-none p-0.5">{emoji}</button>
                    {/each}
                  </div>
                {/if}
              </div>

              <!-- Reply actions -->
              <div class="flex items-center gap-2 ml-auto">
                {#if visibleReplies.length > 0}
                  <button
                    onclick={() => toggleReplies(post.id)}
                    class="flex items-center gap-1 text-xs font-medium transition-colors"
                    style={isExpanded ? 'color: hsl(234 26% 41%)' : 'color: hsl(220 9% 55%)'}
                  >
                    <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                      <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
                    </svg>
                    {visibleReplies.length} {visibleReplies.length === 1 ? 'reply' : 'replies'}
                    <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" class="transition-transform {isExpanded ? 'rotate-180' : ''}">
                      <polyline points="6 9 12 15 18 9"/>
                    </svg>
                  </button>
                {/if}
                <button
                  onclick={() => openReplyComposer(post.id)}
                  class="text-xs font-medium transition-colors"
                  style={replyingTo === post.id ? 'color: hsl(234 26% 41%)' : 'color: hsl(220 9% 55%)'}
                >
                  Reply
                </button>
              </div>
            </div>

            <!-- Replies -->
            {#if isExpanded && visibleReplies.length > 0}
              <div class="mt-3 pl-3 border-l-2 flex flex-col gap-3" style="border-color: hsl(234 40% 85%)">
                {#each visibleReplies as reply}
                  <div>
                    <div class="flex items-center gap-2 mb-1">
                      {#if reply.users?.avatar_url}
                        <img src={reply.users.avatar_url} alt={reply.users.display_name} class="w-6 h-6 rounded-full object-cover shrink-0" />
                      {:else}
                        <div class="w-6 h-6 rounded-full flex items-center justify-center text-white shrink-0" style="background: hsl(234 26% 41%); font-size: 9px">
                          {initials(reply.users?.display_name)}
                        </div>
                      {/if}
                      <span class="text-xs font-semibold text-foreground">{reply.users?.display_name}</span>
                      <span class="text-xs text-muted-foreground">{timeAgo(reply.created_at)}</span>
                      {#if reply.is_edited}
                        <span class="text-xs text-muted-foreground"> · Edited</span>
                      {/if}
                      {#if reply.author_id === currentUserId || isAdmin}
                        <button
                          onclick={() => deletePost(reply.id)}
                          class="ml-auto p-1 rounded hover:bg-black/5 transition-colors"
                          style="color: hsl(234 12% 62%)"
                        >
                          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14H6L5 6"/><path d="M9 6V4h6v2"/>
                          </svg>
                        </button>
                      {/if}
                    </div>
                    <p class="text-sm text-foreground pl-8 whitespace-pre-wrap leading-relaxed">{reply.body}</p>
                  </div>
                {/each}
              </div>
            {/if}

            <!-- Reply composer -->
            {#if replyingTo === post.id}
              <div class="mt-3 pl-3 border-l-2" style="border-color: hsl(234 40% 85%)">
                <textarea
                  bind:value={replyBodies[post.id]}
                  placeholder="Write a reply…"
                  rows="2"
                  class="w-full text-sm text-foreground bg-white rounded-lg px-3 py-2 placeholder:text-muted-foreground resize-none focus:outline-none focus:ring-2 focus:ring-ring"
                ></textarea>
                <div class="flex gap-2 mt-2">
                  <button
                    onclick={() => submitReply(post.id)}
                    disabled={submittingReply || !replyBodies[post.id]?.trim()}
                    class="px-3 py-1.5 rounded-lg text-xs font-semibold text-white disabled:opacity-40"
                    style="background: hsl(234 26% 41%)"
                  >
                    {submittingReply ? 'Posting…' : 'Reply'}
                  </button>
                  <button
                    onclick={() => replyingTo = null}
                    class="px-3 py-1.5 rounded-lg text-xs font-medium text-muted-foreground hover:bg-black/5"
                  >
                    Cancel
                  </button>
                </div>
              </div>
            {/if}

          </div>
        </div>
      {/each}
    </div>
  {/if}

  <!-- Anonymous suggestion box link — non-admins only -->
  {#if adminUserId && adminUserId !== currentUserId}
    <div class="mt-6 pt-4 border-t border-border text-center">
      <a
        href="/groups/{groupId}/suggest"
        class="inline-flex items-center gap-1.5 text-xs text-muted-foreground hover:text-foreground transition-colors"
      >
        <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
        </svg>
        Send an anonymous suggestion to the admin
      </a>
    </div>
  {/if}

  </div>
</div>
