<script>
import { markRaw } from 'vue';
import {
  eventHub,
  DUO_CHAT_REGISTER_EMPTY_STATE_HEADER,
  DUO_CHAT_REQUEST_EMPTY_STATE_HEADER,
} from '../../events/panel';

export default {
  name: 'DuoChatEmptyStateHeader',
  data() {
    return {
      registeredSlots: [],
    };
  },
  computed: {
    activeSlot() {
      return this.registeredSlots[this.registeredSlots.length - 1] ?? null;
    },
  },
  created() {
    eventHub.$on(DUO_CHAT_REGISTER_EMPTY_STATE_HEADER, this.onRegister);
    eventHub.$emit(DUO_CHAT_REQUEST_EMPTY_STATE_HEADER);
  },
  beforeDestroy() {
    eventHub.$off(DUO_CHAT_REGISTER_EMPTY_STATE_HEADER, this.onRegister);
  },
  methods: {
    onRegister({ id, component, props }) {
      this.registeredSlots = this.registeredSlots.filter((slot) => slot.id !== id);

      if (component) {
        this.registeredSlots.push({ id, component: markRaw(component), props });
      }
    },
  },
};
</script>

<template>
  <div>
    <component :is="activeSlot.component" v-if="activeSlot" v-bind="activeSlot.props" />
    <template v-else>
      <h2 class="gl-heading-2 gl-mb-0">
        {{ s__('DuoAgenticChat|GitLab Duo Agent Platform') }}
      </h2>
      <p class="gl-text-subtle">
        {{
          s__(
            'DuoAgenticChat|Collaborate with AI agents to accomplish tasks and answer questions, or use a multi-agent flow to solve a complex problem.',
          )
        }}
      </p>
    </template>
  </div>
</template>
