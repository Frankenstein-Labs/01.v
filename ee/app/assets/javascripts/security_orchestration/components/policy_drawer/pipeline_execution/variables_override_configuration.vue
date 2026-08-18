<script>
import { GlAccordion, GlAccordionItem } from '@gitlab/ui';
import { DEFAULT_VARIABLES_OVERRIDE_STATE } from 'ee/security_orchestration/components/policy_editor/pipeline_execution/constants';
import ToggleList from 'ee/security_orchestration/components/scope/toggle_list.vue';
import { s__ } from '~/locale';

export default {
  i18n: {
    allowListHeader: s__('SecurityOrchestration|Allowlist details'),
    denyListHeader: s__('SecurityOrchestration|Denylist details'),
    deniedMessageNoExceptions: s__(
      'SecurityOrchestration|Settings from outside of the policy cannot override variables when the policy runs.',
    ),
    deniedMessage: s__(
      'SecurityOrchestration|Settings from outside of the policy cannot override variables when the policy runs, except for the variables defined in the allowlist.',
    ),
    allowMessageNoExceptions: s__(
      'SecurityOrchestration|Settings from outside of the policy can override variables when the policy runs.',
    ),
    allowMessage: s__(
      'SecurityOrchestration|Settings from outside of the policy can override variables when the policy runs, except the variables defined in the denylist.',
    ),
  },
  name: 'VariablesOverrideList',
  components: {
    GlAccordion,
    GlAccordionItem,
    ToggleList,
  },
  props: {
    variablesOverride: {
      type: Object,
      required: false,
      default: () => DEFAULT_VARIABLES_OVERRIDE_STATE,
    },
  },
  computed: {
    isVariablesOverrideAllowed() {
      return this.variablesOverride.allowed;
    },
    exceptions() {
      return this.variablesOverride?.exceptions || [];
    },
    hasExceptions() {
      return this.exceptions.length > 0;
    },
    accordionTitle() {
      return this.isVariablesOverrideAllowed
        ? this.$options.i18n.denyListHeader
        : this.$options.i18n.allowListHeader;
    },
    header() {
      const allowMessage = this.hasExceptions
        ? this.$options.i18n.allowMessage
        : this.$options.i18n.allowMessageNoExceptions;
      const deniedMessage = this.hasExceptions
        ? this.$options.i18n.deniedMessage
        : this.$options.i18n.deniedMessageNoExceptions;

      return this.isVariablesOverrideAllowed ? allowMessage : deniedMessage;
    },
  },
};
</script>

<template>
  <div>
    <p class="gl-mb-2" data-testid="status-header">{{ header }}</p>

    <gl-accordion v-if="hasExceptions" :header-level="3">
      <gl-accordion-item :title="accordionTitle" visible>
        <toggle-list bullet-style :items="exceptions" />
      </gl-accordion-item>
    </gl-accordion>
  </div>
</template>
