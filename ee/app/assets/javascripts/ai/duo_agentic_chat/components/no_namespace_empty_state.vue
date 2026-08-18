<script>
import { GlButton } from '@gitlab/ui';
import { s__ } from '~/locale';
import TanukiAiIcon from '../../shared/widgets/tanuki_ai_icon.vue';

export default {
  name: 'NoNamespaceEmptyState',
  components: {
    GlButton,
    TanukiAiIcon,
  },
  i18n: {
    bodyWithClassicFallback: s__(
      'DuoAgenticChat|To use Chat, select a default namespace in your user profile preferences. Alternatively, turn off the Agentic toggle to return to non-agentic Chat.',
    ),
    bodyWithoutClassicFallback: s__(
      'DuoAgenticChat|To use Chat, select a default namespace in your user profile preferences.',
    ),
  },
  props: {
    preferencesPath: {
      type: String,
      required: false,
      default: '',
    },
    isClassicAvailable: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['return-to-classic'],
  computed: {
    bodyText() {
      return this.isClassicAvailable
        ? this.$options.i18n.bodyWithClassicFallback
        : this.$options.i18n.bodyWithoutClassicFallback;
    },
  },
};
</script>

<template>
  <div
    class="gl-flex gl-w-full gl-flex-col gl-items-start gl-gap-4 gl-py-8"
    data-testid="no-namespace-empty-state"
  >
    <tanuki-ai-icon />
    <h2 class="gl-my-0 gl-text-size-h2">
      {{ s__('DuoAgenticChat|GitLab Duo Agentic Chat is unavailable') }}
    </h2>
    <p class="gl-text-subtle">
      {{ bodyText }}
    </p>
    <div class="gl-flex gl-gap-2">
      <gl-button
        v-if="preferencesPath"
        variant="confirm"
        category="primary"
        :href="preferencesPath"
        target="_blank"
        data-testid="go-to-preferences-button"
      >
        {{ s__('DuoAgenticChat|Select default namespace') }}
      </gl-button>
      <gl-button
        v-if="isClassicAvailable"
        variant="default"
        category="primary"
        @click="$emit('return-to-classic')"
      >
        {{ s__('DuoAgenticChat|Return to non-agentic Chat') }}
      </gl-button>
    </div>
  </div>
</template>
