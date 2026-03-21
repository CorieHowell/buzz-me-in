<script>
  import { supabase } from '$lib/supabase'
  import { goto } from '$app/navigation'
  import logo from '$lib/assets/BuzzLogo.png'

  let email = $state('')
  let password = $state('')
  let displayName = $state('')
  let loading = $state(false)
  let error = $state('')

  async function handleSignup() {
    if (!displayName.trim()) { error = 'Please enter your name.'; return }
    if (!email.trim()) { error = 'Please enter your email.'; return }
    if (password.length < 8) { error = 'Password must be at least 8 characters.'; return }

    loading = true
    error = ''

    const { data, error: authError } = await supabase.auth.signUp({
      email,
      password,
      options: { data: { display_name: displayName } }
    })

    if (authError) {
      error = authError.message
      loading = false
      return
    }

    if (data.user) {
      await supabase.from('users').upsert({
        id: data.user.id,
        email,
        display_name: displayName,
      })
      goto('/home')
    }

    loading = false
  }

  async function handleGoogle() {
    const { error: authError } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: { redirectTo: `${window.location.origin}/home` }
    })
    if (authError) error = authError.message
  }
</script>

<div class="min-h-screen bg-background flex items-center justify-center px-4">
  <div class="w-full max-w-sm">

    <!-- Logo / wordmark -->
    <div class="text-center mb-8">
      <div class="flex items-center justify-center mb-4">
        <img src={logo} alt="Buzz Me In" class="h-12" />
      </div>
      <h1 class="text-2xl font-semibold text-foreground">Create your account</h1>
      <p class="text-sm text-muted-foreground mt-1">Join your groups, off social media.</p>
    </div>

    <!-- Google button -->
    <button
      onclick={handleGoogle}
      class="w-full flex items-center justify-center gap-3 px-4 py-2.5 rounded-xl border border-border bg-white hover:bg-muted transition-colors text-sm font-medium text-foreground mb-4"
    >
      <svg width="18" height="18" viewBox="0 0 24 24"><path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4"/><path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/><path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" fill="#FBBC05"/><path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/></svg>
      Continue with Google
    </button>

    <!-- Divider -->
    <div class="flex items-center gap-3 mb-4">
      <div class="flex-1 h-px bg-border"></div>
      <span class="text-xs text-muted-foreground">or</span>
      <div class="flex-1 h-px bg-border"></div>
    </div>

    <!-- Form -->
    <form onsubmit={(e) => { e.preventDefault(); handleSignup() }} class="flex flex-col gap-3">

      <div class="flex flex-col gap-1.5">
        <label for="name" class="text-sm font-medium text-foreground">Your name</label>
        <input
          id="name"
          type="text"
          bind:value={displayName}
          placeholder="Jamie Lerner"
          class="w-full px-3 py-2.5 rounded-xl border border-input bg-background text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-ring transition"
        />
      </div>

      <div class="flex flex-col gap-1.5">
        <label for="email" class="text-sm font-medium text-foreground">Email</label>
        <input
          id="email"
          type="email"
          bind:value={email}
          placeholder="you@example.com"
          class="w-full px-3 py-2.5 rounded-xl border border-input bg-background text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-ring transition"
        />
      </div>

      <div class="flex flex-col gap-1.5">
        <label for="password" class="text-sm font-medium text-foreground">Password</label>
        <input
          id="password"
          type="password"
          bind:value={password}
          placeholder="8+ characters"
          class="w-full px-3 py-2.5 rounded-xl border border-input bg-background text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-ring transition"
        />
      </div>

      {#if error}
        <p class="text-sm text-destructive">{error}</p>
      {/if}

      <button
        type="submit"
        disabled={loading}
        class="w-full py-2.5 rounded-xl text-sm font-semibold text-white transition-opacity disabled:opacity-60 mt-1"
        style="background: hsl(234 26% 41%)"
      >
        {loading ? 'Creating account…' : 'Create account'}
      </button>
    </form>

    <!-- Sign in link -->
    <p class="text-center text-sm text-muted-foreground mt-6">
      Already have an account?
      <a href="/auth/login" class="font-medium" style="color: hsl(234 26% 41%)">Sign in</a>
    </p>

  </div>
</div>