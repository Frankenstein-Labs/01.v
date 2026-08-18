<script setup lang="ts">
import HelloWorld from './components/HelloWorld.vue';
import type { HostDataProps, ChatEvents } from '@/types';

const props = defineProps<HostDataProps>();

const emit = defineEmits<ChatEvents>();
</script>

<template>
  <div>
    <img :alt="`${props.userName}'s avatar`" :src="props.avatarUrl" />
    <div>
      <h2>The list of the available models:</h2>
      <ul>
        <li
          v-for="model in props.models"
          :key="model.value"
          @click="emit('change-model', model.value)"
        >
          {{ model.text }}
        </li>
      </ul>
    </div>
    <HelloWorld :msg="`Welcome to the Frontend Island, ${props.userName}`" />
  </div>
</template>

<style scoped>
.logo {
  height: 6em;
  padding: 1.5em;
  will-change: filter;
  transition: filter 300ms;
}
.logo:hover {
  filter: drop-shadow(0 0 2em #646cffaa);
}
.logo.vue:hover {
  filter: drop-shadow(0 0 2em #42b883aa);
}
</style>
