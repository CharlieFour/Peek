<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { supabase } from './supabase'

const logs = ref([])

onMounted(async () => {
  const { data, error } = await supabase
    .from('logs')
    .select('*')
    .order('timestamp', { ascending: false })

  if (error) console.error(error)
  else logs.value = data
})
</script>

<template>
  <div class="p-6 text-white">
    <h1 class="text-2xl mb-4">Activity Logs</h1>
    <div v-if="logs.length === 0">No logs found.</div>
    <ul v-else>
      <li v-for="log in logs" :key="log.id" class="mb-2">
        {{ log.timestamp }} - {{ log.username }} - {{ log.activity }}
      </li>
    </ul>
  </div>
</template>

<style scoped>
body {
  background: #111;
  color: #eee;
}
</style>