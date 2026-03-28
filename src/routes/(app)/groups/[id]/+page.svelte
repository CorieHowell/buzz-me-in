<script>
  import { page } from '$app/stores'
  import { goto } from '$app/navigation'
  import { onMount } from 'svelte'

  let groupId = $derived($page.params.id)

  onMount(() => {
    goto(`/groups/${groupId}/board`, { replaceState: true })
  })
</script>
