<script setup lang="ts">
import App from './App.vue';
import type { HostDataProps, ChatEvents } from './types';
import { useCommunicationBridge } from './composables/useCommunicationBridge';

/** PROPS FROM HOST */
const props = defineProps<HostDataProps>();

/** EVENTS from the inner components to the host */
const emit = defineEmits<ChatEvents>();

/** Use the communication bridge composable */
const bridge = useCommunicationBridge<ChatEvents, HostDataProps>(props, emit, [
  'chat-hidden',
  'change-model',
  'thread-selected',
  'new-chat',
  'back-to-list',
  'delete-thread',
  'chat-cancel',
  'send-chat-prompt',
  'track-feedback',
  'chat-resize',
] as const);
</script>
<template>
  <App v-bind="bridge.forwardedProps.value" v-on="bridge.eventListeners" />
</template>
