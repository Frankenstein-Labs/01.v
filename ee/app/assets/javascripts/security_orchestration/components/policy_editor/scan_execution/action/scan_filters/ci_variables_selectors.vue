<script>
import { isEmpty, uniqueId } from 'lodash-es';
import { GlButton, GlTooltipDirective } from '@gitlab/ui';
import { s__ } from '~/locale';
import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';
import { isCauseOfError } from 'ee/security_orchestration/components/policy_editor/utils';
import { CI_VARIABLE } from './constants';
import CiVariableSelector from './ci_variable_selector.vue';

export default {
  name: 'CiVariablesSelectors',
  i18n: {
    addLabel: s__('ScanExecutionPolicy|Add new CI variable'),
    label: s__('ScanExecutionPolicy|Customized CI variables:'),
    subLabel: s__(
      'ScanExecutionPolicy|Customized variables will overwrite ones defined in the project CI/CD file and settings',
    ),
    tooltipText: s__('ScanExecutionPolicy|Only one variable can be added at a time.'),
    disableRemoveButtonTitle: s__(
      'ScanExecutionPolicy|This is a required variable for this scanner and cannot be removed.',
    ),
  },
  components: {
    GlButton,
    CiVariableSelector,
    SectionLayout,
  },
  directives: { GlTooltip: GlTooltipDirective },
  props: {
    actionIndex: {
      type: Number,
      required: false,
      default: 0,
    },
    errorSources: {
      type: Array,
      required: false,
      default: () => [],
    },
    scanType: {
      type: String,
      required: true,
    },
    selected: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  emits: ['input', 'remove'],
  data() {
    return {
      variableTracker: Object.entries(this.selected).map(() => uniqueId()),
    };
  },
  computed: {
    isErrorSource() {
      return isCauseOfError({
        errorSources: this.errorSources,
        primaryKey: 'actions',
        index: this.actionIndex,
        location: 'variables',
      });
    },
    hasEmptyVariable() {
      return this.variables.some(([key]) => key === '');
    },
    variables() {
      return Object.entries(this.selected).length ? Object.entries(this.selected) : [['', '']];
    },
    hasRequiredVariable() {
      return 'SECURE_ENABLE_LOCAL_CONFIGURATION' in this.selected;
    },
    parentDisabledRemoveButtonTitle() {
      return this.hasRequiredVariable ? this.$options.i18n.disableRemoveButtonTitle : '';
    },
  },
  methods: {
    addVariable() {
      this.variableTracker.push(uniqueId());
      this.$emit('input', { variables: { ...this.selected, '': '' } });
    },
    reduceVariablesToObject(array) {
      return array.reduce((acc, [key, value]) => {
        acc[key] = value;
        return acc;
      }, {});
    },
    remove() {
      this.$emit('remove', CI_VARIABLE);
    },
    removeVariable(variable, index) {
      this.variableTracker.splice(index, 1);
      const remainingVariables = this.variables.filter(([key]) => variable !== key);

      const variablesObject = this.reduceVariablesToObject(remainingVariables);
      if (isEmpty(variablesObject)) {
        this.remove();
      } else {
        this.$emit('input', { variables: variablesObject });
      }
    },
    updateVariable([key, value], index) {
      const newVariables = [...this.variables];
      newVariables[index] = [key, value];

      const variablesObject = this.reduceVariablesToObject(newVariables);
      this.$emit('input', { variables: variablesObject });
    },
    isRequiredVariable(variable) {
      return variable === 'SECURE_ENABLE_LOCAL_CONFIGURATION';
    },
    requiredVariableDisabledTitle(variable) {
      return this.isRequiredVariable(variable) ? this.$options.i18n.disableRemoveButtonTitle : '';
    },
  },
};
</script>

<template>
  <div class="gl-w-full gl-rounded-base gl-bg-default">
    <section-layout
      class="gl-mb-2 gl-bg-default gl-pb-0 gl-pr-2"
      content-classes="gl-gap-y-2"
      :disable-remove-button="hasRequiredVariable"
      :disable-remove-button-title="parentDisabledRemoveButtonTitle"
      @remove="remove"
    >
      <template #selector>
        <label class="gl-mb-0" :title="$options.i18n.label">
          {{ $options.i18n.label }}
        </label>
        <p class="gl-mb-4 gl-basis-full gl-text-sm">{{ $options.i18n.subLabel }}</p>
      </template>
    </section-layout>

    <ci-variable-selector
      v-for="([key, value], index) in variables"
      :key="variableTracker[index]"
      :variable="key"
      :value="value"
      :scan-type="scanType"
      :selected="selected"
      :disable-remove-button="isRequiredVariable(key)"
      :disable-remove-button-title="requiredVariableDisabledTitle(key)"
      :is-error-source="isErrorSource"
      class="gl-mb-2"
      @input="updateVariable($event, index)"
      @remove="removeVariable($event, index)"
    />

    <span v-gl-tooltip.hover="$options.i18n.tooltipText">
      <gl-button
        :disabled="hasEmptyVariable"
        variant="link"
        data-testid="add-variable-button"
        :aria-label="$options.i18n.addLabel"
        class="gl-mb-5 gl-ml-4 gl-mr-3 gl-mt-4 gl-pt-2"
        @click="addVariable"
      >
        {{ $options.i18n.addLabel }}
      </gl-button>
    </span>
  </div>
</template>
