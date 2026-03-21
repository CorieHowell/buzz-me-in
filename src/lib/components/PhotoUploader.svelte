<script>
  import { supabase } from '$lib/supabase'

  /**
   * bucket      — Supabase storage bucket name (e.g. 'avatars', 'group-avatars')
   * pathPrefix  — folder path inside the bucket (e.g. userId or groupId)
   * value       — bindable current public URL (null if no image)
   * shape       — 'circle' | 'square'
   * size        — 'sm' (48px) | 'md' (64px) | 'lg' (96px)
   */
  let { bucket, pathPrefix, value = $bindable(null), shape = 'circle', size = 'md', onchange } = $props()

  let uploading = $state(false)
  let error = $state('')
  let fileInput = $state(null)

  const sizes = { sm: 'w-12 h-12', md: 'w-16 h-16', lg: 'w-24 h-24' }
  let shapeClass = $derived(shape === 'circle' ? 'rounded-full' : 'rounded-2xl')
  let sizeClass = $derived(sizes[size] ?? sizes.md)

  async function handleFileChange(e) {
    const file = e.target.files?.[0]
    if (!file) return
    if (!file.type.startsWith('image/')) { error = 'Please select an image file.'; return }
    if (file.size > 5 * 1024 * 1024) { error = 'Image must be under 5MB.'; return }

    error = ''
    uploading = true

    // Remove old file if it lives in our bucket
    if (value) {
      const oldPath = extractPath(value)
      if (oldPath) await supabase.storage.from(bucket).remove([oldPath])
    }

    const ext = file.name.split('.').pop()
    const path = `${pathPrefix}/${Date.now()}.${ext}`

    const { error: uploadError } = await supabase.storage
      .from(bucket)
      .upload(path, file, { upsert: true })

    if (uploadError) { error = uploadError.message; uploading = false; return }

    const { data: { publicUrl } } = supabase.storage.from(bucket).getPublicUrl(path)
    value = publicUrl
    uploading = false
    if (fileInput) fileInput.value = ''
    onchange?.(publicUrl)
  }

  async function removePhoto() {
    if (!value) return
    const path = extractPath(value)
    if (path) await supabase.storage.from(bucket).remove([path])
    value = null
    onchange?.(null)
  }

  function extractPath(url) {
    try {
      const marker = `/storage/v1/object/public/${bucket}/`
      const idx = url.indexOf(marker)
      return idx === -1 ? null : decodeURIComponent(url.slice(idx + marker.length))
    } catch { return null }
  }
</script>

<div class="flex flex-col items-start gap-1">
  <div class="relative inline-block group">

    <!-- Image or placeholder -->
    <div class="{sizeClass} {shapeClass} overflow-hidden flex items-center justify-center shrink-0"
      style="background: hsl(234 20% 92%)">
      {#if value}
        <img src={value} alt="Photo" class="w-full h-full object-cover" />
      {:else}
        <svg width="40%" height="40%" viewBox="0 0 24 24" fill="none"
          stroke="hsl(234 12% 62%)" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
          <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
          <circle cx="12" cy="7" r="4"/>
        </svg>
      {/if}
    </div>

    <!-- Hover overlay -->
    {#if uploading}
      <div class="{sizeClass} {shapeClass} absolute inset-0 bg-black/50 flex items-center justify-center">
        <div class="w-5 h-5 rounded-full border-2 border-white border-t-transparent animate-spin"></div>
      </div>
    {:else}
      <div class="{sizeClass} {shapeClass} absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center gap-1.5">
        <button type="button" onclick={() => fileInput?.click()}
          class="p-1.5 rounded-full bg-white/90 hover:bg-white transition-colors"
          title={value ? 'Change photo' : 'Upload photo'}>
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none"
            stroke="hsl(234 26% 41%)" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>
            <polyline points="17 8 12 3 7 8"/>
            <line x1="12" y1="3" x2="12" y2="15"/>
          </svg>
        </button>
        {#if value}
          <button type="button" onclick={removePhoto}
            class="p-1.5 rounded-full bg-white/90 hover:bg-white transition-colors"
            title="Remove photo">
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none"
              stroke="hsl(0 72% 51%)" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
              <line x1="18" y1="6" x2="6" y2="18"/>
              <line x1="6" y1="6" x2="18" y2="18"/>
            </svg>
          </button>
        {/if}
      </div>
    {/if}

    <input bind:this={fileInput} type="file" accept="image/*" class="hidden" onchange={handleFileChange} />
  </div>

  {#if error}
    <p class="text-xs text-destructive">{error}</p>
  {/if}
</div>
