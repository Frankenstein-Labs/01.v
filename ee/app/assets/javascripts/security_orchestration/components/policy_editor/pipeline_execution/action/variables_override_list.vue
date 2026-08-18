<script>
import { isEmpty } from 'lodash-es';
import {
  GlAccordion,
  GlAccordionItem,
  GlButton,
  GlCollapsibleListbox,
  GlLink,
  GlIcon,
  GlSprintf,
} from '@gitlab/ui';
import { n__, s__, sprintf } from '~/locale';
import {
  ALLOW,
  ALLOW_DENY_LISTBOX_ITEMS,
  ALLOW_DENY_OPTIONS,
  DEFAULT_VARIABLES_OVERRIDE_STATE,
  DENY,
} from 'ee/security_orchestration/components/policy_editor/pipeline_execution/constants';
import { helpPagePath } from '~/helpers/help_page_helper';
import { doesVariablesOverrideHasValidStructure } from 'ee/security_orchestration/components/policy_editor/pipeline_execution/action/utils';
import VariablesOverrideModal from './variables_override_modal.vue';

export default {
  ALLOW_DENY_LISTBOX_ITEMS,
  HELP_PAGE_LINK: helpPagePath('user/application_security/policies/pipeline_execution_policies'),
  i18n: {
    allowList: s__('SecurityOrchestration|allowlist'),
    denyList: s__('SecurityOrchestration|denylist'),
    denyListText: s__('SecurityOrchestration|Edit denylist (%{variablesCount} %{variables})'),
    allowListText: s__('SecurityOrchestration|Edit allowlist (%{variablesCount} %{variables})'),
    header: s__('SecurityOrchestration|Variable option'),
    message: s__(
      'SecurityOrchestration|%{listType} attempts from %{linkStart}other settings%{linkEnd} to override variables when the policy runs, except the variables defined in the %{list}.',
    ),
    listTypeDefaultText: s__('SecurityOrchestration|Select list type'),
    validationErrorMessage: s__(
      'SecurityOrchestration|Variables override configuration has invalid structure.',
    ),
  },
  name: 'VariablesOverrideList',
  components: {
    GlAccordion,
    GlAccordionItem,
    GlButton,
    GlCollapsibleListbox,
    GlIcon,
    GlLink,
    GlSprintf,
    VariablesOverrideModal,
  },
  props: {
    variablesOverride: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  emits: ['select'],
  data() {
    return {
      accordionVisible: !isEmpty(this.variablesOverride),
    };
  },
  computed: {
    isDefaultState() {
      return isEmpty(this.variablesOverride);
    },
    doesVariablesOverrideHasValidStructure() {
      if (this.isDefaultState) {
        return true;
      }

      return doesVariablesOverrideHasValidStructure(this.variablesOverride);
    },
    buttonText() {
      const { denyListText, allowListText } = this.$options.i18n;
      const message = this.isVariablesOverrideAllowed ? denyListText : allowListText;
      const variablesCount = this.selectedExceptions.filter(Boolean).length;
      const variables = n__('variable', 'variables', variablesCount);

      return sprintf(message, {
        variablesCount,
        variables,
      });
    },
    listName() {
      return this.isVariablesOverrideAllowed
        ? this.$options.i18n.denyList
        : this.$options.i18n.allowList;
    },
    isVariablesOverrideAllowed() {
      return Boolean(this.variablesOverride.allowed);
    },
    selectedExceptions() {
      const { exceptions = [] } = this.variablesOverride || {};
      return Array.isArray(exceptions) && exceptions.length > 0 ? exceptions : [''];
    },
    allowedKey() {
      return this.isVariablesOverrideAllowed ? ALLOW : DENY;
    },
    toggleText() {
      return ALLOW_DENY_OPTIONS[this.allowedKey] || this.$options.i18n.listTypeDefaultText;
    },
  },
  methods: {
    showModal() {
      this.$refs.modal.showModalWindow();
    },
    emitChange(payload) {
      this.$emit('select', { ...this.variablesOverride, ...payload });
    },
    selectExceptions(exceptions) {
      this.emitChange({ exceptions });
    },
    selectListType(type) {
      this.emitChange({ allowed: type !== DENY, exceptions: [] });
    },
    toggleAccordion(visible) {
      if (this.isDefaultState && visible) {
        this.emitChange(DEFAULT_VARIABLES_OVERRIDE_STATE);
      }

      this.accordionVisible = visible;
    },
  },
};
</script>

<template>
  <div>
    <gl-accordion :header-level="3">
      <gl-accordion-item
        :title="$options.i18n.header"
        :visible="accordionVisible"
        @input="toggleAccordion"
      >
        <p class="gl-my-4">
          <gl-sprintf :message="$options.i18n.message">
            <template #listType>
              <gl-collapsible-listbox
                :selected="allowedKey"
                :items="$options.ALLOW_DENY_LISTBOX_ITEMS"
                :toggle-text="toggleText"
                @select="selectListType"
              />
            </template>
            <template #link="{ content }">
              <gl-link :href="$options.HELP_PAGE_LINK" target="_blank">
                {{ content }}
              </gl-link>
            </template>
            <template #list>
              <span>{{ listName }}</span>
            </template>
          </gl-sprintf>
        </p>

        <gl-button category="primary" variant="link" @click="showModal">
          {{ buttonText }}
        </gl-button>

        <variables-override-modal
          ref="modal"
          :exceptions="selectedExceptions"
          :is-variables-override-allowed="isVariablesOverrideAllowed"
          @select-exceptions="selectExceptions"
        />
      </gl-accordion-item>
    </gl-accordion>

    <div
      v-if="!doesVariablesOverrideHasValidStructure"
      class="gl-mt-3 gl-flex gl-items-center gl-gap-2"
      data-testid="validation-message"
    >
      <gl-icon name="error" variant="danger" />
      <p class="gl-m-0 gl-text-danger">{{ $options.i18n.validationErrorMessage }}</p>
    </div>
  </div>
</template>
