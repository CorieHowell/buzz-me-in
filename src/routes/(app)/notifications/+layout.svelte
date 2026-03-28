<script>
  import { page } from '$app/stores'

  let currentType = $derived($page.url.searchParams.get('type') ?? 'all')

  const filterItems = [
    { key: 'all',      label: 'All' },
    { key: 'mentions', label: 'Mentions' },
    { key: 'replies',  label: 'Replies' },
    { key: 'events',   label: 'Events' },
    { key: 'polls',    label: 'Polls' },
  ]
</script>

<!-- Desktop: filter nav + content outlet -->
<div class="hidden md:flex h-full">

  <aside class="w-44 shrink-0 border-r border-border flex flex-col bg-background overflow-y-auto">
    <div class="px-4 py-4 border-b border-border shrink-0">
      <p class="text-sm font-semibold text-foreground">Notifications</p>
    </div>

    <nav class="flex flex-col gap-0.5 p-2">
      {#each filterItems as item}
        <a
          href="/notifications{item.key === 'all' ? '' : `?type=${item.key}`}"
          class="px-3 py-2 rounded-lg text-sm font-medium transition-colors"
          style={currentType === item.key
            ? 'background: hsl(234 40% 97%); color: hsl(234 26% 41%)'
            : 'color: hsl(234 12% 52%)'}
        >
          {item.label}
        </a>
      {/each}
    </nav>
  </aside>

  <main class="flex-1 overflow-y-auto min-w-0">
    <slot />
  </main>
</div>

<!-- Mobile: full-width slot only -->
<div class="md:hidden flex flex-col h-full">
  <slot />
</div>
