<script>
  import { getContext } from 'svelte'
  import { goto } from '$app/navigation'

  const ctx = getContext('messagesContext')
</script>

<!-- Desktop: "Select a conversation" placeholder -->
<div class="hidden md:flex h-full items-center justify-center">
  <div class="text-center">
    <div class="w-16 h-16 rounded-2xl flex items-center justify-center mx-auto mb-4" style="background: hsl(234 40% 97%)">
      <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="hsl(234 26% 41%)" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
        <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
      </svg>
    </div>
    <h2 class="text-base font-semibold text-foreground mb-1">Your messages</h2>
    <p class="text-sm text-muted-foreground max-w-xs mx-auto">Select a conversation from the sidebar to get started.</p>
  </div>
</div>

<!-- Mobile: full conversation list -->
<div class="md:hidden w-full px-4 py-6">

  <h1 class="text-xl font-semibold text-foreground mb-6">Messages</h1>

  {#if ctx.loading}
    <div class="flex flex-col gap-3">
      {#each [1,2,3] as _}
        <div class="flex items-center gap-3 p-4 rounded-xl border border-border animate-pulse">
          <div class="w-10 h-10 rounded-full bg-muted shrink-0"></div>
          <div class="flex-1">
            <div class="h-4 bg-muted rounded w-1/3 mb-2"></div>
            <div class="h-3 bg-muted rounded w-2/3"></div>
          </div>
        </div>
      {/each}
    </div>

  {:else if ctx.conversations.length === 0}
    <div class="text-center py-16">
      <div class="w-16 h-16 rounded-2xl flex items-center justify-center mx-auto mb-4" style="background: hsl(234 40% 97%)">
        <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="hsl(234 26% 41%)" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
          <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
        </svg>
      </div>
      <h2 class="text-base font-semibold text-foreground mb-1">No messages yet</h2>
      <p class="text-sm text-muted-foreground max-w-xs mx-auto">You can message any member of your groups directly from the Members tab.</p>
    </div>

  {:else}
    <div class="flex flex-col gap-2">
      {#each ctx.conversations as conv (conv.key)}
        {@const isMenuOpen = ctx.openMenuId === conv.key}
        {@const isMuted = ctx.mutedIds.has(conv.key)}

        <div
          class="relative flex items-center rounded-xl border transition-colors"
          style={conv.unread && !isMuted
            ? 'border-color: hsl(234 26% 41%); background: hsl(234 40% 97%)'
            : 'border-color: hsl(234 20% 88%)'}
        >
          <!-- Main clickable area -->
          <button
            onclick={() => ctx.handleConvClick(conv)}
            class="flex items-center gap-3 pl-4 py-4 flex-1 min-w-0 text-left hover:bg-muted/20 rounded-l-xl transition-colors"
          >
            <!-- Avatar -->
            <div class="relative shrink-0">
              {#if !conv.isAnonymous && conv.otherAvatarUrl}
                <img src={conv.otherAvatarUrl} alt={conv.otherName} class="w-10 h-10 rounded-full object-cover" />
              {:else}
                <div
                  class="w-10 h-10 rounded-full flex items-center justify-center text-sm font-semibold text-white"
                  style="background: {conv.isAnonymous ? 'hsl(234 12% 52%)' : 'hsl(234 26% 41%)'}"
                >
                  {conv.isAnonymous ? '?' : ctx.initials(conv.otherName)}
                </div>
              {/if}
              {#if isMuted}
                <div class="absolute -bottom-0.5 -right-0.5 w-4 h-4 rounded-full bg-muted border border-background flex items-center justify-center">
                  <svg width="9" height="9" viewBox="0 0 24 24" fill="none" stroke="hsl(234 12% 52%)" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                    <line x1="1" y1="1" x2="23" y2="23"/>
                    <path d="M9 9v3a3 3 0 0 0 5.12 2.12M15 9.34V4a3 3 0 0 0-5.94-.6"/>
                    <path d="M17 16.95A7 7 0 0 1 5 12v-2m14 0v2a7 7 0 0 1-.11 1.23"/>
                    <line x1="12" y1="19" x2="12" y2="23"/>
                    <line x1="8" y1="23" x2="16" y2="23"/>
                  </svg>
                </div>
              {/if}
            </div>

            <!-- Text content -->
            <div class="flex-1 min-w-0">
              <p class="text-sm font-semibold text-foreground"
                style={isMuted ? 'color: hsl(234 12% 52%)' : ''}>{conv.otherName}</p>
              <p class="text-sm text-muted-foreground truncate">{conv.lastMessage}</p>
            </div>
          </button>

          <!-- Right side: time + unread dot + kabob -->
          <div class="flex items-center gap-2 pr-2 pl-2 shrink-0">
            <div class="flex flex-col items-end gap-1">
              <span class="text-xs text-muted-foreground">{ctx.timeAgo(conv.lastTime)}</span>
              {#if conv.unread && !isMuted}
                <div class="w-2 h-2 rounded-full" style="background: hsl(35 100% 62%)"></div>
              {:else}
                <div class="w-2 h-2"></div>
              {/if}
            </div>

            <!-- Kabob button -->
            <button
              onclick={(e) => ctx.toggleMenu(e, conv.key)}
              class="p-1.5 rounded-lg hover:bg-muted transition-colors shrink-0"
              style="color: hsl(234 12% 52%)"
              title="More options"
            >
              <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor" stroke="none">
                <circle cx="12" cy="5" r="1.5"/>
                <circle cx="12" cy="12" r="1.5"/>
                <circle cx="12" cy="19" r="1.5"/>
              </svg>
            </button>
          </div>

          <!-- Dropdown menu -->
          {#if isMenuOpen}
            <button class="fixed inset-0 z-40 cursor-default" onclick={() => ctx.toggleMenu({ stopPropagation: () => {} }, conv.key)} tabindex="-1" aria-hidden="true"></button>
            <div class="absolute right-2 top-full mt-1 w-44 bg-white rounded-xl border border-border py-1 z-50"
              style="box-shadow: 0 8px 24px rgba(0,0,0,0.13)">

              {#if conv.unread}
                <button
                  onclick={() => ctx.markRead(conv)}
                  class="flex items-center gap-2.5 w-full px-3 py-2 text-sm text-foreground hover:bg-muted transition-colors"
                >
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <polyline points="20 6 9 17 4 12"/>
                  </svg>
                  Mark as read
                </button>
              {/if}

              <button
                onclick={() => ctx.toggleMute(conv)}
                class="flex items-center gap-2.5 w-full px-3 py-2 text-sm text-foreground hover:bg-muted transition-colors"
              >
                {#if isMuted}
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/>
                    <path d="M13.73 21a2 2 0 0 1-3.46 0"/>
                  </svg>
                  Unmute
                {:else}
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <line x1="1" y1="1" x2="23" y2="23"/>
                    <path d="M9 9v3a3 3 0 0 0 5.12 2.12M15 9.34V4a3 3 0 0 0-5.94-.6"/>
                    <path d="M17 16.95A7 7 0 0 1 5 12v-2m14 0v2a7 7 0 0 1-.11 1.23"/>
                    <line x1="12" y1="19" x2="12" y2="23"/>
                    <line x1="8" y1="23" x2="16" y2="23"/>
                  </svg>
                  Mute
                {/if}
              </button>

              {#if !conv.isAnonymous}
                <button
                  onclick={() => { goto(`/profile/${conv.otherId}`); ctx.toggleMenu({ stopPropagation: () => {} }, conv.key) }}
                  class="flex items-center gap-2.5 w-full px-3 py-2 text-sm text-foreground hover:bg-muted transition-colors"
                >
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
                    <circle cx="12" cy="7" r="4"/>
                  </svg>
                  View profile
                </button>
              {/if}

              <div class="my-1 border-t border-border"></div>

              <button
                onclick={() => ctx.deleteConv(conv)}
                class="flex items-center gap-2.5 w-full px-3 py-2 text-sm hover:bg-muted transition-colors"
                style="color: hsl(0 72% 51%)"
              >
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                  <polyline points="3 6 5 6 21 6"/>
                  <path d="M19 6l-1 14H6L5 6"/>
                  <path d="M10 11v6"/><path d="M14 11v6"/>
                  <path d="M9 6V4h6v2"/>
                </svg>
                Delete
              </button>
            </div>
          {/if}
        </div>
      {/each}
    </div>
  {/if}

</div>
