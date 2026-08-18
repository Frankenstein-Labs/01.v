<script>
import { GlButton } from '@gitlab/ui';
import { eventHub, SHOW_SESSION } from 'ee/ai/events/panel';
import duoChatAvailableQuery from '../../graphql/duo_chat_available.query.graphql';

export default {
  name: 'ViewSessionButton',
  components: {
    GlButton,
  },
  props: {
    sessionId: {
      type: Number,
      required: true,
    },
  },
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
  methods: {
    openSession() {
      eventHub.$emit(SHOW_SESSION, { id: this.sessionId });
    },
  },
};
</script>

<template>
  <gl-button
    v-if="duoChatAvailable"
    category="tertiary"
    icon="session-ai"
    class="!gl-text-subtle"
    @click="openSession"
  >
    {{ s__('DuoAgentsPlatform|View session') }}
  </gl-button>
</template>
