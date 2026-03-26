<script>
  import { supabase } from '$lib/supabase'

  let email = $state('')
  let loading = $state(false)
  let error = $state('')
  let sent = $state(false)

  async function handleSubmit() {
    if (!email.trim()) { error = 'Please enter your email.'; return }

    loading = true
    error = ''

    const { error: authError } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: `${window.location.origin}/auth/reset-password`
    })

    if (authError) {
      error = authError.message
      loading = false
      return
    }

    sent = true
    loading = false
  }
</script>

<div class="min-h-screen relative flex flex-col items-center justify-center overflow-hidden px-4 py-8" style="background-color: var(--color-header);">

  <!-- Background blobs -->
  <div class="absolute top-10 right-0 w-[32rem] h-[32rem] rounded-full pointer-events-none"
    style="background: var(--color-accent); opacity: 0.08; filter: blur(90px); transform: translate(20%, -20%);"></div>
  <div class="absolute bottom-0 left-0 w-72 h-72 rounded-full pointer-events-none"
    style="background: var(--color-accent-soft); opacity: 0.08; filter: blur(70px);"></div>

  <!-- Wordmark -->
  <div class="relative z-10 mb-8">
    <a href="/auth/login">
      <span class="font-bold text-3xl leading-none tracking-tight">
        <span style="color: hsl(234 65% 82%)">buzz</span><span style="color: hsl(35 100% 72%)">me</span><span style="color: hsl(235 45% 78%)">in</span>
      </span>
    </a>
  </div>

  <div class="relative z-10 w-full max-w-sm">

    {#if sent}
      <div class="text-center">
        <p class="text-2xl mb-2">📬</p>
        <h1 class="text-lg font-bold mb-2" style="color: white;">Check your email</h1>
        <p class="text-sm mb-6" style="color: rgba(255,255,255,0.6);">
          We sent a reset link to <strong style="color: white">{email}</strong>. Click it to set a new password.
        </p>
        <a href="/auth/login" class="text-sm hover:underline" style="color: var(--color-accent)">Back to sign in</a>
      </div>
    {:else}
      <h1 class="text-lg font-bold mb-1" style="color: white;">Forgot your password?</h1>
      <p class="text-sm mb-6" style="color: rgba(255,255,255,0.6);">Enter your email and we'll send you a reset link.</p>

      <form onsubmit={(e) => { e.preventDefault(); handleSubmit() }} class="flex flex-col gap-3">
        <input
          type="email"
          bind:value={email}
          placeholder="Email"
          class="w-full px-4 py-3 rounded-xl text-sm outline-none transition"
          style="background: rgba(255,255,255,0.1); color: white; border: 1px solid rgba(255,255,255,0.18);"
        />

        {#if error}
          <p class="text-sm" style="color: var(--color-accent-soft)">{error}</p>
        {/if}

        <button
          type="submit"
          disabled={loading}
          class="w-full py-3 rounded-xl text-sm font-bold transition-opacity disabled:opacity-60"
          style="background: var(--color-accent); color: var(--color-accent-foreground);"
        >
          {loading ? 'Sending…' : 'Send reset link'}
        </button>
      </form>

      <p class="text-center text-sm mt-6">
        <a href="/auth/login" class="hover:underline" style="color: rgba(255,255,255,0.5)">Back to sign in</a>
      </p>
    {/if}

  </div>
</div>
