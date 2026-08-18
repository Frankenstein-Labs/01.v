<script>
import {
  GlTable,
  GlButton,
  GlFormInput,
  GlFormGroup,
  GlBadge,
  GlTooltipDirective,
} from '@gitlab/ui';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import { __ } from '~/locale';
import { WORKSPACE_VARIABLE_INPUT_TYPE_ENUM } from '../constants';

export default {
  name: 'WorkspaceVariables',
  components: {
    GlTable,
    GlButton,
    GlFormInput,
    GlFormGroup,
    GlBadge,
    CrudComponent,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  model: {
    event: 'input',
    prop: 'variables',
  },
  props: {
    variables: {
      type: Array,
      required: true,
      validator: (v) => {
        return v.every((variable) => {
          return ['key', 'value', 'variableType', 'valid'].every((k) => {
            return Object.keys(variable).some((key) => {
              return key === k;
            });
          });
        });
      },
    },
    showValidations: {
      type: Boolean,
      required: true,
      default: false,
    },
  },
  emits: ['add-variable', 'input'],
  fields: [
    {
      key: 'key',
      label: __('Key'),
    },
    {
      key: 'value',
      label: __('Value'),
    },
    {
      key: 'variableType',
      label: __('Type'),
    },
    {
      key: 'action',
      thAlignRight: true,
      thClass: 'gl-w-2/20',
      tdClass: 'gl-text-right',
      label: '',
    },
  ],
  computed: {
    hasVariables() {
      return this.variables.length;
    },
  },
  methods: {
    validateVariable(key) {
      return !(key === '');
    },
    getStateValue(variable) {
      return this.showValidations === true ? variable.valid : null;
    },
    addVariable() {
      this.$emit('add-variable');
      this.$emit(
        'input',
        this.variables.concat([
          {
            key: '',
            value: '',
            variableType: WORKSPACE_VARIABLE_INPUT_TYPE_ENUM.env,
            valid: false,
          },
        ]),
      );
    },
    removeVariable(variable) {
      this.$emit(
        'input',
        this.variables.filter((v) => v !== variable),
      );
    },
    updateVariable($event, variable, field) {
      const targetIndex = this.variables.indexOf(variable);
      const updatedVariables = this.variables.map((v, index) => {
        if (targetIndex === index) {
          const updatedV = { ...v, [field]: $event };
          updatedV.valid = this.validateVariable(updatedV.key);
          return updatedV;
        }
        return v;
      });
      this.$emit('input', updatedVariables);
    },
  },
};
</script>
<template>
  <crud-component :title="__('Variables')" icon="code" :count="variables.length">
    <template #actions>
      <gl-button size="small" data-testid="add-variable" @click="addVariable">{{
        __('Add variable')
      }}</gl-button>
    </template>

    <template v-if="hasVariables" #default>
      <gl-table :fields="$options.fields" :items="variables" show-empty stacked="sm">
        <template #cell(key)="{ item, index }">
          <gl-form-group
            :optional="false"
            optional-text=""
            :label-for="`key_${index}`"
            label="Variable Key"
            label-sr-only
            invalid-feedback="This field is required."
            :state="getStateValue(item)"
          >
            <gl-form-input
              :id="`key_${index}`"
              data-testid="key"
              :value="item.key"
              type="text"
              @input="updateVariable($event, item, 'key')"
            />
          </gl-form-group>
        </template>
        <template #cell(value)="{ item, index }">
          <gl-form-group
            :optional="true"
            optional-text=""
            :label-for="`value_${index}`"
            label="Variable Value"
            label-sr-only
            invalid-feedback="This field is required."
          >
            <gl-form-input
              :id="`value_${index}`"
              data-testid="value"
              :value="item.value"
              type="text"
              @input="updateVariable($event, item, 'value')"
            />
          </gl-form-group>
        </template>
        <template #cell(type)="{ item }">
          <gl-badge variant="neutral">{{ item.variableType }}</gl-badge>
        </template>
        <template #cell(action)="{ item }">
          <gl-button
            v-gl-tooltip
            icon="remove"
            size="small"
            category="tertiary"
            data-testid="remove-variable"
            :aria-label="__('Remove variable')"
            :title="__('Remove variable')"
            @click="removeVariable(item)"
          />
        </template>
      </gl-table>
    </template>
    <template v-if="!hasVariables" #empty>
      {{ __('There are no variables yet.') }}
    </template>
  </crud-component>
</template>
