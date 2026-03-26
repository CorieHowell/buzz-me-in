<script>
  import { supabase } from '$lib/supabase'
  import { goto } from '$app/navigation'

  let email = $state('')
  let password = $state('')
  let loading = $state(false)
  let error = $state('')

  async function handleLogin() {
    if (!email.trim()) { error = 'Please enter your email.'; return }
    if (!password) { error = 'Please enter your password.'; return }

    loading = true
    error = ''

    const { error: authError } = await supabase.auth.signInWithPassword({ email, password })

    if (authError) {
      error = authError.message
      loading = false
      return
    }

    goto('/home')
  }

  async function handleGoogle() {
    const { error: authError } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: { redirectTo: `${window.location.origin}/home` }
    })
    if (authError) error = authError.message
  }
</script>

<div class="min-h-screen relative overflow-hidden" style="background-color: var(--color-header);">

  <!-- Background blobs -->
  <div class="absolute top-10 right-0 w-[32rem] h-[32rem] rounded-full pointer-events-none"
    style="background: var(--color-accent); opacity: 0.08; filter: blur(90px); transform: translate(20%, -20%);"></div>
  <div class="absolute bottom-0 left-0 w-72 h-72 rounded-full pointer-events-none"
    style="background: var(--color-accent-soft); opacity: 0.08; filter: blur(70px);"></div>

  <!-- Desktop: wordmark top-left -->
  <div class="hidden md:block absolute top-8 left-10 z-10">
    <span class="font-bold text-2xl leading-none tracking-tight">
      <span style="color: hsl(234 65% 82%)">buzz</span><span style="color: hsl(35 100% 72%)">me</span><span style="color: hsl(235 45% 78%)">in</span>
    </span>
  </div>

  <!-- Mobile layout -->
  <div class="md:hidden flex flex-col items-center justify-center min-h-screen px-4 py-8">

    <!-- Wordmark -->
    <div class="relative z-10 mb-1">
      <span class="font-bold text-3xl leading-none tracking-tight">
        <span style="color: hsl(234 65% 82%)">buzz</span><span style="color: hsl(35 100% 72%)">me</span><span style="color: hsl(235 45% 78%)">in</span>
      </span>
    </div>

    <!-- Illustration -->
    <div class="w-full max-w-[260px] mb-4">
      <img src="/cast-of-characters.png" alt="Friends heading out to their group meetup" class="w-full" />
    </div>

    <!-- Form -->
    <div class="w-full max-w-sm">
      <form onsubmit={(e) => { e.preventDefault(); handleLogin() }} class="flex flex-col gap-3">
        <input id="email" type="email" bind:value={email} placeholder="Email"
          class="w-full px-4 py-3 rounded-xl text-sm outline-none transition"
          style="background: rgba(255,255,255,0.1); color: white; border: 1px solid rgba(255,255,255,0.18);" />
        <input id="password" type="password" bind:value={password} placeholder="Password"
          class="w-full px-4 py-3 rounded-xl text-sm outline-none transition"
          style="background: rgba(255,255,255,0.1); color: white; border: 1px solid rgba(255,255,255,0.18);" />
        {#if error}
          <p class="text-sm" style="color: var(--color-accent-soft)">{error}</p>
        {/if}
        <button type="submit" disabled={loading}
          class="w-full py-3 rounded-xl text-sm font-bold transition-opacity disabled:opacity-60 mt-1"
          style="background: var(--color-accent); color: var(--color-accent-foreground);">
          {loading ? 'Signing in…' : 'Sign in'}
        </button>
      </form>
      <div class="text-center mt-3">
        <a href="/auth/forgot-password" class="text-xs hover:underline" style="color: var(--color-accent)">Forgot password?</a>
      </div>
      <p class="text-center text-sm mt-5" style="color: rgba(255,255,255,0.5)">
        Don't have an account?
        <a href="/auth/signup" class="font-semibold hover:underline" style="color: var(--color-accent)">Create one</a>
      </p>
      <div class="flex items-center gap-3 mt-6 mb-4">
        <div class="flex-1 h-px" style="background: rgba(255,255,255,0.15)"></div>
        <span class="text-xs" style="color: rgba(255,255,255,0.4)">or</span>
        <div class="flex-1 h-px" style="background: rgba(255,255,255,0.15)"></div>
      </div>
      <div class="flex justify-center">
        <button onclick={handleGoogle}
          class="flex items-center justify-center gap-2 px-4 py-2 rounded-xl text-xs font-medium transition-colors"
          style="background: rgba(255,255,255,0.1); color: rgba(255,255,255,0.7); border: 1px solid rgba(255,255,255,0.18);">
          <svg width="15" height="15" viewBox="0 0 24 24"><path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4"/><path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/><path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" fill="#FBBC05"/><path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/></svg>
          Continue with Google
        </button>
      </div>
    </div>
  </div>

  <!-- Desktop layout -->
  <div class="hidden md:flex min-h-screen items-center justify-center" style="gap: 80px;">

    <!-- Left: form -->
    <div class="flex flex-col justify-center w-full max-w-sm">
        <h1 class="text-2xl font-bold mb-1" style="color: white;">Welcome back</h1>
        <p class="text-sm mb-8" style="color: rgba(255,255,255,0.5);">Sign in to your account.</p>

        <form onsubmit={(e) => { e.preventDefault(); handleLogin() }} class="flex flex-col gap-3">
          <input id="email-desktop" type="email" bind:value={email} placeholder="Email"
            class="w-full px-4 py-3 rounded-xl text-sm outline-none transition"
            style="background: rgba(255,255,255,0.1); color: white; border: 1px solid rgba(255,255,255,0.18);" />
          <input id="password-desktop" type="password" bind:value={password} placeholder="Password"
            class="w-full px-4 py-3 rounded-xl text-sm outline-none transition"
            style="background: rgba(255,255,255,0.1); color: white; border: 1px solid rgba(255,255,255,0.18);" />
          {#if error}
            <p class="text-sm" style="color: var(--color-accent-soft)">{error}</p>
          {/if}
          <button type="submit" disabled={loading}
            class="w-full py-3 rounded-xl text-sm font-bold transition-opacity disabled:opacity-60 mt-1"
            style="background: var(--color-accent); color: var(--color-accent-foreground);">
            {loading ? 'Signing in…' : 'Sign in'}
          </button>
        </form>

        <div class="text-center mt-3">
          <a href="/auth/forgot-password" class="text-xs hover:underline" style="color: var(--color-accent)">Forgot password?</a>
        </div>

        <p class="text-center text-sm mt-5" style="color: rgba(255,255,255,0.5)">
          Don't have an account?
          <a href="/auth/signup" class="font-semibold hover:underline" style="color: var(--color-accent)">Create one</a>
        </p>

        <div class="flex items-center gap-3 mt-6 mb-4">
          <div class="flex-1 h-px" style="background: rgba(255,255,255,0.15)"></div>
          <span class="text-xs" style="color: rgba(255,255,255,0.4)">or</span>
          <div class="flex-1 h-px" style="background: rgba(255,255,255,0.15)"></div>
        </div>

        <div class="flex justify-center">
          <button onclick={handleGoogle}
            class="flex items-center justify-center gap-2 px-4 py-2 rounded-xl text-xs font-medium transition-colors"
            style="background: rgba(255,255,255,0.1); color: rgba(255,255,255,0.7); border: 1px solid rgba(255,255,255,0.18);">
            <svg width="15" height="15" viewBox="0 0 24 24"><path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4"/><path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/><path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" fill="#FBBC05"/><path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/></svg>
            Continue with Google
          </button>
        </div>
    </div>

    <!-- Right: illustration -->
    <div class="flex items-center justify-center pb-12">
      <img src="/cast-of-characters.png" alt="Friends heading out to their group meetup"
        class="object-contain" style="width: 480px; max-height: 67vh;" />
    </div>

  </div>
</div>
