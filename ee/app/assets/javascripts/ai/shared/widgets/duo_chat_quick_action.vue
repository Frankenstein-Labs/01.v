<script>
import { GlButton } from '@gitlab/ui';
import { eventHub, QUEUE_CHAT_COMMAND, SHOW_NEW_CHAT } from 'ee/ai/events/panel';
import {
  subscribeToEvent,
  DUO_CHAT_TOOL_COMPLETED_EVENT,
} from 'ee/ai/duo_agentic_chat/events/event_hub';
import { InternalEvents } from '~/tracking';
import duoChatAvailableQuery from '../../graphql/duo_chat_available.query.graphql';

export default {
  name: 'DuoChatQuickAction',
  components: {
    GlButton,
  },
  mixins: [InternalEvents.mixin()],
  props: {
    buttonText: {
      type: String,
      required: true,
    },
    resourceId: {
      type: String,
      required: true,
    },
    trackingInfo: {
      type: Object,
      required: true,
      validator: (val) => {
        // Two words minimum, snake_case. One word events are
        // often not descriptive enough, so we enforce two words.
        return /^[a-z]+(_[a-z]+)+$/.test(val.label);
      },
    },
    command: {
      type: Object,
      required: true,
      validator(value) {
        return Boolean(value?.agenticPrompt || value?.agent);
      },
    },
    buttonOptions: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    classicQuickAction: {
      type: String,
      required: false,
      default: null,
      validator: (val) => val === null || val.startsWith('/'),
    },
  },
  emits: ['click', 'duo-tool-completed', 'chat-opened'],
  apollo: {
    duoChatAvailable: {
      query: duoChatAvailableQuery,
      update(data) {
        return data?.currentUser?.duoChatAvailable ?? false;
      },
      error() {
        this.duoChatAvailable = false;
      },
    },
  },
  data() {
    return {
      duoChatAvailable: false,
    };
  },
  mounted() {
    this.toolCompletedSubscription = subscribeToEvent(
      DUO_CHAT_TOOL_COMPLETED_EVENT,
      this.onToolCompleted,
    );
  },
  beforeDestroy() {
    this.toolCompletedSubscription.dispose();
  },
  methods: {
    onToolCompleted(payload) {
      this.$emit('duo-tool-completed', payload);
    },
    async onClick() {
      this.$emit('click');
      this.trackEvent('click_duo_quick_action', this.trackingInfo);

      eventHub.$emit(SHOW_NEW_CHAT);

      eventHub.$emit(QUEUE_CHAT_COMMAND, {
        ...this.command,
        question: this.classicQuickAction || this.command.agenticPrompt,
        resourceId: this.resourceId,
      });

      this.$emit('chat-opened');
    },
  },
};
</script>
<template>
  <gl-button
    v-if="duoChatAvailable"
    v-bind="{ icon: 'tanuki-ai', ...buttonOptions }"
    @click="onClick"
    >{{ buttonText }}</gl-button
  >
</template>
