<script>
  import { supabase } from '$lib/supabase'
  import { page } from '$app/stores'
  import { goto } from '$app/navigation'
  import { onMount } from 'svelte'

  let groupId = $derived($page.params.id)
  let posts = $state([])
  let loading = $state(true)
  let currentUserId = $state(null)
  let currentUserRole = $state(null)
  let adminUserId = $state(null)
  let newPostBody = $state('')
  let posting = $state(false)
  let postError = $state('')
  let expandedPosts = $state(new Set())
  let replyBodies = $state({})
  let replyingTo = $state(null)
  let submittingReply = $state(false)

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

    // Get admin for suggestion box
    const { data: adminData } = await supabase
      .from('group_members')
      .select('user_id')
      .eq('group_id', groupId)
      .eq('role', 'admin')
      .single()

    adminUserId = adminData?.user_id ?? null

    await loadPosts()
  })

  async function loadPosts() {
    loading = true
    const { data } = await supabase
      .from('posts')
      .select(`
        id, body, created_at, is_edited, is_deleted, is_announcement,
        author_id,
        users(display_name, avatar_url),
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

    posts = data ?? []
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
        body: newPostBody.trim(),
      })

    if (error) { postError = error.message; posting = false; return }
    newPostBody = ''
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

  function toggleReplies(postId) {
    const next = new Set(expandedPosts)
    if (next.has(postId)) next.delete(postId)
    else next.add(postId)
    expandedPosts = next
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

<div class="max-w-2xl mx-auto px-4 py-6">

  <!-- New post composer -->
  <div class="rounded-xl border border-border p-4 mb-6">
    <textarea
      bind:value={newPostBody}
      placeholder="Write something to the group…"
      rows="3"
      class="w-full text-sm text-foreground bg-transparent placeholder:text-muted-foreground resize-none focus:outline-none"
    ></textarea>
    {#if postError}
      <p class="text-xs text-destructive mt-1">{postError}</p>
    {/if}
    <div class="flex justify-end mt-2">
      <button
        onclick={submitPost}
        disabled={posting || !newPostBody.trim()}
        class="px-4 py-2 rounded-xl text-sm font-semibold text-white transition-opacity disabled:opacity-40"
        style="background: hsl(234 26% 41%)"
      >
        {posting ? 'Posting…' : 'Post'}
      </button>
    </div>
  </div>

  {#if loading}
    <div class="flex flex-col gap-3">
      {#each [1,2,3] as _}
        <div class="rounded-xl border border-border p-4 animate-pulse">
          <div class="h-3 bg-muted rounded w-1/4 mb-3"></div>
          <div class="h-4 bg-muted rounded w-3/4 mb-2"></div>
          <div class="h-3 bg-muted rounded w-1/2"></div>
        </div>
      {/each}
    </div>

  {:else if posts.length === 0}
    <div class="text-center py-12">
      <p class="text-sm text-muted-foreground">No posts yet. Be the first to write something!</p>
    </div>

  {:else}
    <div class="flex flex-col gap-3">
      {#each posts as post}
        {@const visibleReplies = (post.replies ?? []).filter(r => !r.is_deleted)}
        {@const isExpanded = expandedPosts.has(post.id)}
        {@const isOwner = post.author_id === currentUserId}

        <div class="rounded-xl border bg-background p-4"
          style={post.is_announcement ? 'border-color: hsl(234 26% 41%)' : 'border-color: hsl(234 20% 88%)'}>

          {#if post.is_announcement}
            <div class="flex items-center gap-1.5 mb-2">
              <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="hsl(234 26% 41%)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <line x1="12" y1="17" x2="12" y2="22"/>
                <path d="M5 17h14v-1.76a2 2 0 0 0-1.11-1.79l-1.78-.9A2 2 0 0 1 15 10.76V6h1a2 2 0 0 0 0-4H8a2 2 0 0 0 0 4h1v4.76a2 2 0 0 1-1.11 1.79l-1.78.9A2 2 0 0 0 5 15.24Z"/>
              </svg>
              <span class="text-xs font-semibold" style="color: hsl(234 26% 41%)">Pinned</span>
            </div>
          {/if}

          <!-- Post header -->
          <div class="flex items-center justify-between mb-2">
            <div class="flex items-center gap-2">
              {#if post.users?.avatar_url}
                <img src={post.users.avatar_url} alt={post.users.display_name} class="w-7 h-7 rounded-full object-cover shrink-0" />
              {:else}
                <div class="w-7 h-7 rounded-full flex items-center justify-center text-xs font-semibold text-white shrink-0" style="background: hsl(234 26% 41%)">
                  {initials(post.users?.display_name)}
                </div>
              {/if}
              <span class="text-sm font-medium text-foreground">{post.users?.display_name}</span>
              <span class="text-xs text-muted-foreground">{timeAgo(post.created_at)}</span>
              {#if post.is_edited}
                <span class="text-xs text-muted-foreground">· Edited</span>
              {/if}
            </div>

            {#if isOwner || isAdmin}
              <div class="flex items-center gap-1">
                {#if isAdmin}
                  <button
                    onclick={() => pinPost(post.id, post.is_announcement)}
                    class="p-1.5 rounded-lg hover:bg-muted transition-colors"
                    style="color: hsl(234 12% 52%)"
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
                  class="p-1.5 rounded-lg hover:bg-muted transition-colors"
                  style="color: hsl(234 12% 52%)"
                  title="Delete"
                >
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14H6L5 6"/><path d="M10 11v6"/><path d="M14 11v6"/><path d="M9 6V4h6v2"/>
                  </svg>
                </button>
              </div>
            {/if}
          </div>

          <!-- Post body -->
          <p class="text-sm text-foreground whitespace-pre-wrap mb-3">{post.body}</p>

          <!-- Reply count + toggle -->
          <div class="flex items-center gap-3">
            <button
              onclick={() => replyingTo = replyingTo === post.id ? null : post.id}
              class="text-xs font-medium transition-colors"
              style="color: hsl(234 26% 41%)"
            >
              Reply
            </button>
            {#if visibleReplies.length > 0}
              <button
                onclick={() => toggleReplies(post.id)}
                class="text-xs text-muted-foreground hover:text-foreground transition-colors"
              >
                {isExpanded ? 'Hide' : `${visibleReplies.length} ${visibleReplies.length === 1 ? 'reply' : 'replies'}`}
              </button>
            {/if}
          </div>

          <!-- Replies -->
          {#if isExpanded && visibleReplies.length > 0}
            <div class="mt-3 pl-4 border-l-2 flex flex-col gap-3" style="border-color: hsl(234 40% 90%)">
              {#each visibleReplies as reply}
                <div>
                  <div class="flex items-center gap-2 mb-1">
                    {#if reply.users?.avatar_url}
                      <img src={reply.users.avatar_url} alt={reply.users.display_name} class="w-5 h-5 rounded-full object-cover shrink-0" />
                    {:else}
                      <div class="w-5 h-5 rounded-full flex items-center justify-center text-white shrink-0" style="background: hsl(234 26% 41%); font-size: 9px">
                        {initials(reply.users?.display_name)}
                      </div>
                    {/if}
                    <span class="text-xs font-medium text-foreground">{reply.users?.display_name}</span>
                    <span class="text-xs text-muted-foreground">{timeAgo(reply.created_at)}</span>
                    {#if reply.is_edited}
                      <span class="text-xs text-muted-foreground">· Edited</span>
                    {/if}
                    {#if reply.author_id === currentUserId || isAdmin}
                      <button
                        onclick={() => deletePost(reply.id)}
                        class="ml-auto p-1 rounded hover:bg-muted transition-colors"
                        style="color: hsl(234 12% 52%)"
                      >
                        <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                          <polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14H6L5 6"/><path d="M9 6V4h6v2"/>
                        </svg>
                      </button>
                    {/if}
                  </div>
                  <p class="text-sm text-foreground pl-7 whitespace-pre-wrap">{reply.body}</p>
                </div>
              {/each}
            </div>
          {/if}

          <!-- Reply composer -->
          {#if replyingTo === post.id}
            <div class="mt-3 pl-4 border-l-2" style="border-color: hsl(234 40% 90%)">
              <textarea
                bind:value={replyBodies[post.id]}
                placeholder="Write a reply…"
                rows="2"
                class="w-full text-sm text-foreground bg-muted rounded-lg px-3 py-2 placeholder:text-muted-foreground resize-none focus:outline-none focus:ring-2 focus:ring-ring"
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
                  class="px-3 py-1.5 rounded-lg text-xs font-medium text-muted-foreground hover:bg-muted"
                >
                  Cancel
                </button>
              </div>
            </div>
          {/if}

        </div>
      {/each}
    </div>
  {/if}

  <!-- Anonymous suggestion box link — non-admins only -->
  {#if adminUserId && adminUserId !== currentUserId}
    <div class="mt-6 pt-4 border-t border-border text-center">
      <a
        href="/groups/{groupId}/suggest"
        class="text-xs text-muted-foreground hover:underline"
      >
        Send an anonymous suggestion to the admin
      </a>
    </div>
  {/if}

</div>