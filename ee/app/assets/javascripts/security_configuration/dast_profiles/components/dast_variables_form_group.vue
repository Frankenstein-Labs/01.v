<script>
import {
  GlFormGroup,
  GlButton,
  GlSprintf,
  GlLink,
  GlTableLite,
  GlDisclosureDropdown,
  GlDisclosureDropdownItem,
  GlFriendlyWrap,
} from '@gitlab/ui';
import { s__, __ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import { getEmptyVariable } from 'ee/security_configuration/dast_profiles/constants';
import DastVariablesModal from './dast_variables_modal.vue';

export default {
  name: 'DastVariablesFormGroup',
  i18n: {
    label: s__('DastProfiles|Additional variables'),
    helpText: s__(
      'DastProfiles| Customize the behavior of DAST using additional variables. For a full list of available variables, refer to the %{linkStart}DAST documentation%{linkEnd}.',
    ),
    addVariableButtonLabel: s__('DastProfiles|Add variable'),
    optionalText: __('(optional)'),
  },
  dastDocumentationPath: helpPagePath(
    'user/application_security/dast/browser/configuration/variables',
  ),
  components: {
    CrudComponent,
    GlFormGroup,
    GlButton,
    GlSprintf,
    GlLink,
    GlTableLite,
    GlFriendlyWrap,
    GlDisclosureDropdown,
    GlDisclosureDropdownItem,
    DastVariablesModal,
  },
  props: {
    value: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  emits: ['input'],
  data() {
    return {
      fields: [
        { key: 'variable', label: __('Variable'), tdClass: 'gl-max-w-0' },
        { key: 'value', label: __('Value'), tdClass: 'gl-max-w-0' },
        { key: 'actions', label: '', tdClass: 'gl-max-w-0, gl-text-right' },
      ],
      existingVariables: this.value,
      additionalVariables: [],
      editedVariable: getEmptyVariable(),
    };
  },
  computed: {
    variableList() {
      return [...this.existingVariables, ...this.additionalVariables];
    },
  },
  watch: {
    variableList(newValue) {
      this.$emit('input', newValue);
    },
  },
  methods: {
    showAddVariableModal() {
      this.editedVariable = getEmptyVariable();
      this.$refs.addVariableModal.createVariable();
    },
    filterVariableList(item) {
      const { variable: variableToBeOverride } = item;
      this.existingVariables = this.existingVariables.filter(
        ({ variable }) => variable !== variableToBeOverride,
      );
      this.additionalVariables = this.additionalVariables.filter(
        ({ variable }) => variable !== variableToBeOverride,
      );
    },
    updateVariableList(item) {
      this.filterVariableList(item);
      this.additionalVariables.push(item);
    },
    addVariableToList(item) {
      this.additionalVariables.push(item);
    },
    deleteVariableFromList(item) {
      this.filterVariableList(item);
    },
    updateVariable(item) {
      const { value, variable } = item;
      this.editedVariable.value = value;
      this.editedVariable.id = variable;
      this.$refs.addVariableModal.editVariable();
      return item;
    },
    editItem(item) {
      return {
        text: __('Edit'),
        action: () => this.updateVariable(item),
      };
    },
    deleteItem(item) {
      return {
        text: __('Delete'),
        action: () => this.deleteVariableFromList(item),
        variant: 'danger',
      };
    },
  },
  wrapSymbols: [',', '_'],
};
</script>

<template>
  <div class="row">
    <gl-form-group
      class="gl-col-md-12 gl-mb-0"
      :optional="true"
      :optional-text="$options.i18n.optionalText"
      :label="$options.i18n.label"
    >
      <template #label-description>
        <gl-sprintf :message="$options.i18n.helpText">
          <template #link="{ content }">
            <gl-link :href="$options.dastDocumentationPath" target="_blank">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </template>

      <crud-component
        v-if="variableList.length"
        class="gl-my-3 gl-border-t-0"
        :header-class="'!gl-py-0 gl-min-h-0'"
      >
        <gl-table-lite
          :items="variableList"
          :fields="fields"
          bordered
          hover
          class="dast-variables-table gl-mb-0 gl-border-none"
          data-testid="variables-table"
          borderless
        >
          <template #cell(variable)="{ item }">
            <gl-friendly-wrap :text="item.variable" :symbols="$options.wrapSymbols" />
          </template>

          <template #cell(value)="{ item }">
            <gl-friendly-wrap :text="item.value" :symbols="$options.wrapSymbols" />
          </template>

          <template #cell(actions)="{ item }">
            <gl-disclosure-dropdown
              category="tertiary"
              variant="default"
              size="small"
              icon="ellipsis_v"
              no-caret
            >
              <gl-disclosure-dropdown-item :item="editItem(item)" />
              <gl-disclosure-dropdown-item :item="deleteItem(item)" />
            </gl-disclosure-dropdown> </template
        ></gl-table-lite>
      </crud-component>
      <gl-button
        data-testid="additional-variables-btn"
        class="gl-mt-3"
        variant="confirm"
        category="secondary"
        @click="showAddVariableModal"
      >
        {{ $options.i18n.addVariableButtonLabel }}
      </gl-button>
    </gl-form-group>
    <dast-variables-modal
      ref="addVariableModal"
      :pre-selected-variables="variableList"
      :variable="editedVariable"
      @add-variable="addVariableToList"
      @update-variable="updateVariableList"
      @delete-variable="deleteVariableFromList"
    />
  </div>
</template>
