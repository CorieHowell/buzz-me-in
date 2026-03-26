<script>
  import { supabase } from '$lib/supabase'
  import { goto } from '$app/navigation'

  let password = $state('')
  let confirm = $state('')
  let loading = $state(false)
  let error = $state('')

  async function handleReset() {
    if (password.length < 8) { error = 'Password must be at least 8 characters.'; return }
    if (password !== confirm) { error = 'Passwords don\'t match.'; return }

    loading = true
    error = ''

    const { error: authError } = await supabase.auth.updateUser({ password })

    if (authError) {
      error = authError.message
      loading = false
      return
    }

    goto('/home')
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
    <span class="font-bold text-3xl leading-none tracking-tight">
      <span style="color: hsl(234 65% 82%)">buzz</span><span style="color: hsl(35 100% 72%)">me</span><span style="color: hsl(235 45% 78%)">in</span>
    </span>
  </div>

  <div class="relative z-10 w-full max-w-sm">

    <h1 class="text-lg font-bold mb-1" style="color: white;">Set a new password</h1>
    <p class="text-sm mb-6" style="color: rgba(255,255,255,0.6);">Choose something you'll remember.</p>

    <form onsubmit={(e) => { e.preventDefault(); handleReset() }} class="flex flex-col gap-3">
      <input
        type="password"
        bind:value={password}
        placeholder="New password"
        class="w-full px-4 py-3 rounded-xl text-sm outline-none transition"
        style="background: rgba(255,255,255,0.1); color: white; border: 1px solid rgba(255,255,255,0.18);"
      />
      <input
        type="password"
        bind:value={confirm}
        placeholder="Confirm password"
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
        {loading ? 'Saving…' : 'Update password'}
      </button>
    </form>

  </div>
</div>
