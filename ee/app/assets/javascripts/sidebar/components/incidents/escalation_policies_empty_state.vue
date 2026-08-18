<script>
import { GlButton } from '@gitlab/ui';
import { i18nPolicyText } from '../../constants';
import EscalationPolicyHelpState from './escalation_policy_help_state.vue';
import EscalationPolicyCollapsedState from './escalation_policy_collapsed_state.vue';

export default {
  name: 'EscalationPoliciesEmptyState',
  i18n: i18nPolicyText,
  components: {
    GlButton,
    EscalationPolicyCollapsedState,
    EscalationPolicyHelpState,
  },
  data() {
    return {
      showHelp: false,
    };
  },
  methods: {
    toggleHelpState() {
      this.showHelp = !this.showHelp;
    },
  },
};
</script>

<template>
  <div data-testid="escalation-policy-edit">
    <div class="hide-collapsed sidebar-help-wrap">
      <div class="gl-line-height-2 gl-mb-2 gl-flex gl-items-center gl-font-bold gl-text-default">
        <span>{{ $options.i18n.title }}</span>
        <gl-button
          :data-testid="showHelp ? 'close-help-button' : 'help-button'"
          category="tertiary"
          :icon="showHelp ? 'close' : 'question-o'"
          size="small"
          variant="link"
          class="gl-ml-auto"
          @click="toggleHelpState"
        />
      </div>

      <div data-testid="select-escalation-policy" class="hide-collapsed gl-leading-1">
        <span class="gl-text-subtle">
          {{ $options.i18n.none }}
        </span>
      </div>

      <escalation-policy-help-state v-if="showHelp" />
    </div>

    <escalation-policy-collapsed-state />
  </div>
</template>
