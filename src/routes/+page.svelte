<script>
  import { onMount } from 'svelte'

  let heroEmail = $state('')
  let ctaEmail = $state('')
  let submitted = $state(false)
  let loading = $state(false)
  let errorMsg = $state('')
  let navScrolled = $state(false)

  onMount(() => {
    const handleScroll = () => {
      navScrolled = window.scrollY > 60
    }
    window.addEventListener('scroll', handleScroll, { passive: true })
    return () => window.removeEventListener('scroll', handleScroll)
  })

  async function joinWaitlist(email) {
    if (!email || !email.includes('@')) {
      errorMsg = 'Please enter a valid email address.'
      return
    }
    loading = true
    errorMsg = ''

    try {
      const res = await fetch('/api/waitlist', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: email.toLowerCase().trim() })
      })
      const data = await res.json()
      if (!res.ok) {
        errorMsg = data.error || 'Something went wrong. Try again?'
      } else {
        submitted = true
      }
    } catch {
      errorMsg = 'Something went wrong. Try again?'
    }

    loading = false
  }

  const features = [
    {
      icon: '📅',
      title: 'Events & RSVPs',
      desc: "Plan events, collect RSVPs, and always know who's coming. Recurring events, rotating hosts, guest passes."
    },
    {
      icon: '🗓️',
      title: 'Availability Picker',
      desc: "Propose a few dates, let members vote, watch the best one surface. No more 'I can't that day' threads."
    },
    {
      icon: '🛍️',
      title: 'Bring List',
      desc: "Members claim what they're bringing. No duplicates, no chaos. Unless four bottles of wine is the plan."
    },
    {
      icon: '💬',
      title: 'Message Board',
      desc: 'Threaded discussions that stay organized. Post updates, share links, ask questions. Without the noise.'
    },
    {
      icon: '🧠',
      title: 'Group Memory',
      desc: "Every event, bring list, and recap — automatically saved. No screenshots, no searching back through texts."
    },
    {
      icon: '🔒',
      title: 'Private & Invite-Only',
      desc: 'No algorithms. No ads. No randoms. Your group is yours. Invite only, off social media, on your terms.'
    }
  ]

  const painPoints = [
    {
      emoji: '😩',
      title: 'The group text spiral',
      desc: 'The bring list is buried under 847 messages. Someone definitely brought two bags of chips again.'
    },
    {
      emoji: '🙄',
      title: 'The Facebook problem',
      desc: "You joined Facebook to stay connected, not to explain to your aunt why your book club needs a private group."
    },
    {
      emoji: '📧',
      title: 'The email chain nightmare',
      desc: 'Reply All. Reply All. Reply All. "Does 7pm still work?" 14 responses later, still no answer.'
    }
  ]

  const steps = [
    {
      step: '01',
      title: 'Create your group',
      desc: "Give it a name, set up your invite link, and you're live. Takes two minutes, less time than composing a group text.",
      color: 'var(--color-accent)',
      textColor: 'var(--color-accent-foreground)'
    },
    {
      step: '02',
      title: 'Invite your crew',
      desc: 'Share a link or QR code. Members join instantly or request to join. You decide. No app download required.',
      color: 'var(--color-accent-soft)',
      textColor: 'white'
    },
    {
      step: '03',
      title: 'Show up and enjoy',
      desc: 'Post events, fill the bring list, chat on the board. Everything stays organized so you can focus on a good time.',
      color: 'var(--color-secondary)',
      textColor: 'white'
    }
  ]

  const personas = [
    { emoji: '📚', label: 'Book Clubs', desc: 'Monthly reads, rotating hosts, zero Facebook drama.' },
    { emoji: '🧘', label: 'Wellness Groups', desc: 'Yoga, run clubs, meditation. Show up, feel good, stay accountable.' },
    { emoji: '🍷', label: 'Dinner Clubs', desc: "Who's hosting, who's bringing what. All handled." },
    { emoji: '🥾', label: 'Hiking Crews', desc: "Plan the next trail, rally the group, track who's in." },
    { emoji: '🎨', label: 'Hobby Groups', desc: 'Any recurring group with a shared passion and a need to organize.' },
    { emoji: '👯', label: 'Friend Groups', desc: "The crew that's been trying to schedule a dinner for six months." }
  ]

  const freeFeatures = [
    'Up to 2 groups',
    'Event planner & RSVPs',
    'Bring list',
    'Message board with threads',
    'Polls',
    'Member profiles & DMs',
    '6 months of group archive'
  ]

  const proFeatures = [
    'Everything in Free',
    'Unlimited groups',
    'Full event archive (forever)',
    'Photo attachments',
    'Calendar export',
    'Custom group URL',
    'Co-admin role'
  ]
</script>

<svelte:head>
  <title>Buzz Me In — Private Group Coordination, Off Social Media</title>
  <meta name="description" content="The private, social-media-free home base for your book club, dinner crew, hiking group, or any small group that loves showing up together." />
</svelte:head>

<!-- ── NAV ── -->
<nav
  class="fixed top-0 left-0 right-0 z-50 transition-all duration-300"
  style={navScrolled
    ? 'background: white; box-shadow: 0 2px 16px rgba(0,0,0,0.08);'
    : 'background: transparent;'}
>
  <div class="max-w-6xl mx-auto px-6 py-4 flex items-center justify-between">
    <div class="flex items-center">
      <span class="font-bold text-2xl leading-none tracking-tight">
        {#if navScrolled}
          <span style="color: hsl(234 65% 38%)">buzz</span><span style="color: hsl(35 100% 50%)">me</span><span style="color: hsl(235 45% 48%)">in</span>
        {:else}
          <span style="color: hsl(234 65% 82%)">buzz</span><span style="color: hsl(35 100% 72%)">me</span><span style="color: hsl(235 45% 78%)">in</span>
        {/if}
      </span>
    </div>
    <a
      href="#waitlist"
      class="px-5 py-2.5 rounded-full text-sm font-semibold transition-all duration-200 hover:scale-105"
      style={navScrolled
        ? 'background: var(--color-accent); color: var(--color-accent-foreground);'
        : 'background: rgba(255,255,255,0.15); color: white; border: 1.5px solid rgba(255,255,255,0.35); backdrop-filter: blur(8px);'}
    >
      Get Early Access
    </a>
  </div>
</nav>

<!-- ── HERO ── -->
<section
  class="relative min-h-screen flex items-center overflow-hidden pt-20"
  style="background-color: var(--color-header);"
>
  <!-- Decorative background blobs -->
  <div
    class="absolute top-10 right-0 w-[32rem] h-[32rem] rounded-full pointer-events-none"
    style="background: var(--color-accent); opacity: 0.08; filter: blur(90px); transform: translate(20%, -20%);"
  ></div>
  <div
    class="absolute bottom-0 left-0 w-72 h-72 rounded-full pointer-events-none"
    style="background: var(--color-accent-soft); opacity: 0.08; filter: blur(70px);"
  ></div>

  <div class="max-w-6xl mx-auto px-6 py-20 grid lg:grid-cols-2 gap-16 items-center relative z-10 w-full">
    <!-- Left: copy + form -->
    <div>
      <div
        class="inline-flex items-center gap-2 px-4 py-1.5 rounded-full text-sm font-semibold mb-8"
        style="background: rgba(255,255,255,0.08); color: var(--color-accent); border: 1px solid rgba(255,255,255,0.12);"
      >
        Coming soon, join the waitlist
      </div>

      <h1 class="text-5xl lg:text-6xl font-extrabold text-white leading-[1.1] mb-6">
        Your group deserves<br />
        <span style="color: var(--color-accent);">better</span> than<br />
        a group text.
      </h1>

      <p class="text-lg leading-relaxed mb-10" style="color: rgba(255,255,255,0.68);">
        Buzz Me In is the private, social-media-free home base for your book club,
        dinner crew, hiking group, any small group that loves showing up together.
      </p>

      {#if submitted}
        <div
          class="inline-flex items-center gap-4 px-7 py-5 rounded-2xl"
          style="background: rgba(255,255,255,0.08); border: 1px solid rgba(255,255,255,0.15);"
        >
          <span class="text-3xl">🎉</span>
          <div>
            <p class="text-white font-bold text-lg">You're on the list!</p>
            <p style="color: rgba(255,255,255,0.55); font-size: 0.875rem;">We'll buzz you the moment we launch.</p>
          </div>
        </div>
      {:else}
        <form
          onsubmit={(e) => { e.preventDefault(); joinWaitlist(heroEmail) }}
          class="flex gap-2 flex-col sm:flex-row max-w-md"
        >
          <input
            type="email"
            bind:value={heroEmail}
            placeholder="your@email.com"
            required
            class="hero-input flex-1 px-4 py-4 rounded-xl text-sm font-medium outline-none transition-all"
            style="background: rgba(255,255,255,0.1); color: white;"
          />
          <button
            type="submit"
            disabled={loading}
            class="px-6 py-4 rounded-xl font-bold text-sm whitespace-nowrap transition-all duration-200 hover:opacity-90 hover:scale-105 disabled:opacity-60"
            style="background: var(--color-accent); color: var(--color-accent-foreground);"
          >
            {loading ? 'Joining...' : 'Buzz Me In'}
          </button>
        </form>
        {#if errorMsg}
          <p class="mt-2 text-sm" style="color: var(--color-accent-soft);">{errorMsg}</p>
        {/if}
        <p class="mt-3 text-xs" style="color: rgba(255,255,255,0.35);">
          No spam. Just a buzz when we're ready.
        </p>
      {/if}
    </div>

    <!-- Right: illustration -->
    <div class="flex justify-center lg:justify-end">
      <img
        src="/cast-of-characters.png"
        alt="Friends heading out to their group meetup"
        class="w-full max-w-lg"
      />
    </div>
  </div>

  <!-- Scroll hint -->
  <div class="absolute bottom-8 left-1/2 -translate-x-1/2 flex flex-col items-center gap-2 pointer-events-none">
    <span class="text-white text-xs tracking-widest uppercase" style="opacity: 0.3;">scroll</span>
    <div class="w-px h-8" style="background: rgba(255,255,255,0.2);"></div>
  </div>
</section>

<!-- ── PAIN POINTS ── -->
<section class="py-24 bg-white">
  <div class="max-w-5xl mx-auto px-6">
    <div class="text-center mb-16">
      <h2 class="text-4xl font-extrabold mb-4" style="color: var(--color-header);">
        Sound familiar?
      </h2>
      <p class="text-lg" style="color: var(--color-muted-foreground);">
        You love your group. The coordination? A different story.
      </p>
    </div>

    <div class="grid md:grid-cols-3 gap-6">
      {#each painPoints as pain}
        <div
          class="p-8 rounded-2xl"
          style="background: var(--color-surface-purple);"
        >
          <div class="text-4xl mb-5">{pain.emoji}</div>
          <h3 class="font-bold text-lg mb-3" style="color: var(--color-header);">{pain.title}</h3>
          <p class="text-sm leading-relaxed" style="color: var(--color-muted-foreground);">{pain.desc}</p>
        </div>
      {/each}
    </div>

    <div class="text-center mt-14">
      <p class="text-xl font-semibold" style="color: var(--color-primary);">
          Your group text has had enough.
          <span style="color: var(--color-accent-soft);">So have you.</span>
        </p>
    </div>
  </div>
</section>

<!-- ── FEATURES ── -->
<section class="py-24" style="background: var(--color-surface-purple);">
  <div class="max-w-6xl mx-auto px-6">
    <div class="text-center mb-16">
      <h2 class="text-4xl font-extrabold mb-4" style="color: var(--color-header);">
        Everything your group needs.<br />
        <span style="color: var(--color-secondary);">Nothing you don't.</span>
      </h2>
      <p class="text-lg max-w-2xl mx-auto" style="color: var(--color-muted-foreground);">
        No bloat, no noise. Just the tools your group actually uses.
      </p>
    </div>

    <div class="grid sm:grid-cols-2 lg:grid-cols-3 gap-6">
      {#each features as feature}
        <div
          class="p-7 rounded-2xl bg-white"
        >
          <div
            class="rounded-xl flex items-center justify-center text-2xl mb-5"
            style="background: var(--color-surface-amber); width: 3.25rem; height: 3.25rem;"
          >
            {feature.icon}
          </div>
          <h3 class="font-bold text-lg mb-2" style="color: var(--color-header);">{feature.title}</h3>
          <p class="text-sm leading-relaxed" style="color: var(--color-muted-foreground);">{feature.desc}</p>
        </div>
      {/each}
    </div>
  </div>
</section>

<!-- ── HOW IT WORKS ── -->
<section class="bg-white">
  <div class="max-w-5xl mx-auto px-6 py-24 text-center">
    <div class="mb-16">
      <h2 class="text-4xl font-extrabold mb-4" style="color: var(--color-header);">
        Up and running in minutes.
      </h2>
      <p class="text-lg" style="color: var(--color-muted-foreground);">
        Your group could be set up before your next meeting.
      </p>
    </div>

    <div class="flex flex-col md:flex-row items-center md:items-start justify-center gap-0 w-full max-w-3xl mx-auto">
      {#each steps as step, i}
        <div class="flex-1 text-center px-4">
          <h3 class="font-extrabold text-xl mb-2 whitespace-nowrap" style="color: var(--color-primary);">{step.title}</h3>
          <p class="text-sm leading-relaxed" style="color: var(--color-muted-foreground);">{step.desc}</p>
        </div>
        {#if i < steps.length - 1}
          <!-- horizontal line on md+, vertical line on mobile -->
          <div class="flex-shrink-0 flex items-center justify-center md:self-start md:mt-3">
            <div class="md:hidden w-px h-8 my-6" style="background: var(--color-primary); opacity: 0.25;"></div>
            <div class="hidden md:block h-px w-8" style="background: var(--color-primary); opacity: 0.25;"></div>
          </div>
        {/if}
      {/each}
    </div>
  </div>
</section>

<!-- ── WHO IT'S FOR ── -->
<section class="overflow-hidden" style="background-color: var(--color-header);">
  <div class="grid md:grid-cols-2 items-center">

    <!-- Left: text + cards -->
    <div class="py-24 px-6 md:pl-16 xl:pl-24 max-w-2xl md:max-w-none">
      <h2 class="text-4xl font-extrabold text-white mb-4">
        Built for groups like yours.
      </h2>
      <p class="text-lg mb-12" style="color: rgba(255,255,255,0.55);">
        Any small group with a rhythm. Any group that shows up.
      </p>

      <!-- Persona cards -->
      <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {#each personas as persona}
          <div
            class="p-5 rounded-2xl text-center"
            style="background: rgba(255,255,255,0.06);"
          >
            <div class="text-3xl mb-3">{persona.emoji}</div>
            <h3 class="font-bold text-white mb-1.5 text-sm">{persona.label}</h3>
            <p class="text-xs leading-relaxed" style="color: rgba(255,255,255,0.45);">{persona.desc}</p>
          </div>
        {/each}
      </div>
    </div>

    <!-- Right: illustration, flush to edge -->
    <div class="flex items-end justify-end h-full">
      <img
        src="/cast-of-characters2.png"
        alt="Friends buzzing into a building"
        class="w-full object-cover object-left"
      />
    </div>

  </div>
</section>

<!-- ── PRICING ── -->
<section class="py-24" style="background: var(--color-surface-amber);">
  <div class="max-w-4xl mx-auto px-6">
    <div class="text-center mb-14">
      <h2 class="text-4xl font-extrabold mb-4" style="color: var(--color-header);">
        Simple, honest pricing.
      </h2>
      <p class="text-lg" style="color: var(--color-muted-foreground);">
        Free forever for most groups. Upgrade when you want more.
      </p>
    </div>

    <div class="grid md:grid-cols-2 gap-8 items-start">
      <!-- Free tier -->
      <div class="p-8 rounded-3xl bg-white">
        <p class="text-sm font-bold uppercase tracking-wider mb-3" style="color: var(--color-secondary);">Buzz Free</p>
        <div class="flex items-end gap-1 mb-1">
          <span class="text-5xl font-black" style="color: var(--color-header);">$0</span>
        </div>
        <p class="text-sm mb-8" style="color: var(--color-muted-foreground);">No credit card. Ever.</p>

        <ul class="space-y-3 mb-8">
          {#each freeFeatures as item}
            <li class="flex items-center gap-3 text-sm" style="color: var(--color-foreground);">
              <span class="font-bold" style="color: var(--color-secondary);">✓</span>
              {item}
            </li>
          {/each}
        </ul>

        <a
          href="#waitlist"
          class="block w-full py-3.5 rounded-xl text-center font-semibold text-sm transition-all duration-200 hover:opacity-80"
          style="background: var(--color-surface-purple); color: var(--color-primary);"
        >
          Join the Waitlist
        </a>
      </div>

      <!-- Pro tier -->
      <div
        class="p-8 rounded-3xl text-white"
        style="background: var(--color-header);"
      >
        <p class="text-sm font-bold uppercase tracking-wider mb-3" style="color: var(--color-accent);">Buzz Pro</p>
        <div class="flex items-end gap-1 mb-1">
          <span class="text-5xl font-black text-white">$5</span>
          <span class="text-base pb-1" style="color: rgba(255,255,255,0.5);">/month</span>
        </div>
        <p class="text-sm mb-8" style="color: rgba(255,255,255,0.4);">or $49/year, 2 months free</p>

        <ul class="space-y-3 mb-8">
          {#each proFeatures as item}
            <li class="flex items-center gap-3 text-sm text-white">
              <span class="font-bold" style="color: var(--color-accent);">✓</span>
              {item}
            </li>
          {/each}
        </ul>

        <a
          href="#waitlist"
          class="block w-full py-3.5 rounded-xl text-center font-bold text-sm transition-all duration-200 hover:opacity-90"
          style="background: var(--color-accent); color: var(--color-accent-foreground);"
        >
          Get Early Access
        </a>
      </div>
    </div>

    <p class="text-center text-sm mt-8" style="color: var(--color-muted-foreground);">
      Early adopters get special launch pricing. Join the waitlist to lock it in.
    </p>
  </div>
</section>

<!-- ── WAITLIST CTA ── -->
<section id="waitlist" class="py-28 relative overflow-hidden" style="background: var(--color-primary);">
  <div
    class="absolute inset-0 pointer-events-none"
    style="background: radial-gradient(ellipse at 50% 0%, rgba(255,255,255,0.06) 0%, transparent 70%);"
  ></div>
  <div
    class="absolute bottom-0 right-0 w-96 h-96 rounded-full pointer-events-none"
    style="background: var(--color-accent-soft); opacity: 0.1; filter: blur(80px); transform: translate(30%, 30%);"
  ></div>

  <div class="max-w-2xl mx-auto px-6 text-center relative z-10">
    <div class="text-5xl mb-6">🔔</div>
    <h2 class="text-4xl font-extrabold text-white mb-5">
      Your group is out there.<br />Let's get you set up.
    </h2>
    <p class="text-lg mb-10" style="color: rgba(255,255,255,0.65);">
      Buzz Me In is launching soon. Drop your email and we'll buzz you the moment
      it's ready — plus early adopter pricing, just for being early.
    </p>

    {#if submitted}
      <div
        class="inline-flex flex-col items-center gap-3 px-12 py-9 rounded-3xl"
        style="background: rgba(255,255,255,0.08); border: 1px solid rgba(255,255,255,0.15);"
      >
        <div class="text-4xl">🎉</div>
        <p class="text-white font-extrabold text-xl">You're on the list!</p>
        <p style="color: rgba(255,255,255,0.6);">We'll buzz you when we launch. Tell your group!</p>
      </div>
    {:else}
      <form
        onsubmit={(e) => { e.preventDefault(); joinWaitlist(ctaEmail) }}
        class="flex flex-col sm:flex-row gap-3 max-w-md mx-auto"
      >
        <input
          type="email"
          bind:value={ctaEmail}
          placeholder="your@email.com"
          required
          class="cta-input flex-1 px-5 py-4 rounded-xl text-sm font-medium outline-none"
          style="background: rgba(255,255,255,0.12); color: white;"
        />
        <button
          type="submit"
          disabled={loading}
          class="px-7 py-4 rounded-xl font-bold text-sm whitespace-nowrap transition-all duration-200 hover:opacity-90 hover:scale-105 disabled:opacity-60"
          style="background: var(--color-accent); color: var(--color-accent-foreground);"
        >
          {loading ? 'Joining...' : 'Buzz Me In'}
        </button>
      </form>
      {#if errorMsg}
        <p class="mt-3 text-sm" style="color: var(--color-accent-soft);">{errorMsg}</p>
      {/if}
      <p class="mt-4 text-xs" style="color: rgba(255,255,255,0.3);">No spam. Unsubscribe anytime.</p>
    {/if}
  </div>
</section>

<!-- ── FOOTER ── -->
<footer style="background: var(--color-header);" class="py-12">
  <div class="max-w-6xl mx-auto px-6">
    <div class="flex flex-col md:flex-row items-center justify-between gap-6">
      <span class="font-bold text-2xl leading-none tracking-tight">
        <span style="color: hsl(234 65% 82%)">buzz</span><span style="color: hsl(35 100% 72%)">me</span><span style="color: hsl(235 45% 78%)">in</span>
      </span>
      <p class="text-sm text-center" style="color: rgba(255,255,255,0.3);">
        Private group coordination for groups that actually show up.
      </p>
      <a
        href="#waitlist"
        class="text-sm transition-colors hover:opacity-100"
        style="color: rgba(255,255,255,0.4);"
      >
        Get Early Access →
      </a>
    </div>
    <div
      class="mt-8 pt-8 text-center text-xs"
      style="border-top: 1px solid rgba(255,255,255,0.07); color: rgba(255,255,255,0.2);"
    >
      © 2026 Buzz Me In. All rights reserved.
    </div>
  </div>
</footer>

<style>
  .hero-input::placeholder,
  .cta-input::placeholder {
    color: rgba(255, 255, 255, 0.35);
  }
</style>