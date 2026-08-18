<script>
import { difference } from 'lodash-es';
import { GlButton, GlModal } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import VariablesSelector from 'ee/security_orchestration/components/policy_editor/pipeline_execution/action/variables_selector.vue';
import { FLAT_LIST_OPTIONS } from 'ee/security_orchestration/components/policy_editor/scan_execution/action/scan_filters/ci_variable_constants';

export default {
  ACTION_CANCEL: { text: __('Cancel') },
  i18n: {
    newVariableButtonText: s__('SecurityOrchestration|Add another variable'),
    allowListTitle: s__('SecurityOrchestration|Edit allowlist'),
    denyListTitle: s__('SecurityOrchestration|Edit denylist'),
    denyListButton: s__('SecurityOrchestration|Save denylist'),
    allowListButton: s__('SecurityOrchestration|Save allowlist'),
    tableHeaderAllowList: s__('SecurityOrchestration|Variables that can be overridden:'),
    tableHeaderDenyList: s__('SecurityOrchestration|Variables that cannot be overridden:'),
    tableSubheader: s__('SecurityOrchestration|Key'),
  },
  name: 'VariablesOverrideModal',
  components: {
    GlButton,
    GlModal,
    VariablesSelector,
  },
  props: {
    exceptions: {
      type: Array,
      required: false,
      default: () => [],
    },
    isVariablesOverrideAllowed: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['select-exceptions'],
  data() {
    return {
      /**
       * Important to use spread
       * Otherwise this.exceptions would
       * be updated by reference
       */
      items: [...this.exceptions],
      initialState: [...this.exceptions],
    };
  },
  computed: {
    unselectedItems() {
      return difference(FLAT_LIST_OPTIONS, this.items);
    },
    tableHeader() {
      return this.isVariablesOverrideAllowed
        ? this.$options.i18n.tableHeaderDenyList
        : this.$options.i18n.tableHeaderAllowList;
    },
    modalTitle() {
      return this.isVariablesOverrideAllowed
        ? this.$options.i18n.denyListTitle
        : this.$options.i18n.allowListTitle;
    },
    primaryAction() {
      return {
        text: this.isVariablesOverrideAllowed
          ? this.$options.i18n.denyListButton
          : this.$options.i18n.allowListButton,
        attributes: {
          variant: 'confirm',
        },
      };
    },
    hasEmptyPlaceholder() {
      return this.selectedExceptions.includes('');
    },
    selectedExceptions() {
      return this.items.length > 0 ? this.items : [''];
    },
    duplicatesCounter() {
      return this.selectedExceptions.reduce((acc, current) => {
        acc[current] = (acc[current] || 0) + 1;
        return acc;
      }, {});
    },
  },
  watch: {
    exceptions(exceptions) {
      this.items = exceptions;
    },
  },
  methods: {
    setInitialState() {
      this.initialState = [...this.exceptions];
    },
    isDuplicate(variable) {
      return this.duplicatesCounter[variable] > 1;
    },
    addVariableSelector() {
      this.items.push('');
    },
    hideModalWindow() {
      this.items = [...this.initialState];
      this.$refs.modal.hide();
    },
    selectExceptions() {
      this.$emit('select-exceptions', this.items?.filter(Boolean));
    },
    getItems(variable) {
      return [variable, ...this.unselectedItems].filter(Boolean);
    },
    isCustomVariable(variable) {
      return Boolean(variable) && !FLAT_LIST_OPTIONS.includes(variable);
    },
    selectException(variable, index) {
      this.items.splice(index, 1, variable);
    },
    removeException(index) {
      this.items.splice(index, 1);
    },
    /**
     * Used in parent component
     */
    // eslint-disable-next-line vue/no-unused-properties
    showModalWindow() {
      this.$refs.modal.show();
    },
  },
};
</script>

<template>
  <gl-modal
    ref="modal"
    :action-cancel="$options.ACTION_CANCEL"
    :action-primary="primaryAction"
    :title="modalTitle"
    scrollable
    size="md"
    content-class="security-policies-variables-modal-min-height"
    modal-id="deny-allow-list-modal"
    @canceled="hideModalWindow"
    @primary="selectExceptions"
    @show="setInitialState"
  >
    <div class="gl-bg-default gl-px-4 gl-py-5">
      <p class="gl-font-bold" data-testid="table-header">
        {{ tableHeader }}
      </p>

      <p class="gl-mb-4 gl-border-b-1 gl-border-b-default gl-pb-2 gl-border-b-solid">
        {{ $options.i18n.tableSubheader }}
      </p>

      <variables-selector
        v-for="(variable, index) of selectedExceptions"
        :key="index"
        :items="getItems(variable)"
        :is-custom="isCustomVariable(variable)"
        :has-validation-error="isDuplicate(variable)"
        class="gl-mb-3"
        :selected="variable"
        @remove="removeException(index)"
        @select="selectException($event, index)"
      />

      <gl-button
        data-testid="add-button"
        category="secondary"
        :disabled="hasEmptyPlaceholder"
        variant="confirm"
        size="small"
        @click="addVariableSelector"
      >
        {{ $options.i18n.newVariableButtonText }}
      </gl-button>
    </div>
  </gl-modal>
</template>
