<script>
import { GlFormGroup, GlCollapsibleListbox } from '@gitlab/ui';
import { s__, sprintf } from '~/locale';
import { validateSourceFilter } from 'ee/security_orchestration/components/policies/utils';
import { POLICY_SOURCE_OPTIONS } from '../constants';

const POLICY_SOURCE_OPTIONS_VALUES = Object.values(POLICY_SOURCE_OPTIONS);

export default {
  name: 'PolicySourceFilter',
  components: {
    GlCollapsibleListbox,
    GlFormGroup,
  },
  props: {
    value: {
      type: String,
      required: true,
      validator: (value) => validateSourceFilter(value),
    },
  },
  emits: ['input'],
  computed: {
    ariaLabel() {
      return sprintf(s__('SecurityOrchestration|Select source, currently selected: %{selected}'), {
        selected: this.selectedValueText,
      });
    },
    selectedValueText() {
      return POLICY_SOURCE_OPTIONS_VALUES.find(({ value }) => value === this.value).text;
    },
  },
  methods: {
    setPolicySource(value) {
      this.$emit('input', value);
    },
  },
  policySourceFilterId: 'policy-source-filter',
  POLICY_SOURCE_OPTIONS_VALUES,
  i18n: {
    label: s__('SecurityOrchestration|Source'),
  },
};
</script>

<template>
  <gl-form-group
    :label="$options.i18n.label"
    label-size="sm"
    :label-for="$options.policySourceFilterId"
  >
    <gl-collapsible-listbox
      :id="$options.policySourceFilterId"
      :aria-label="ariaLabel"
      block
      class="gl-flex"
      toggle-class="gl-truncate"
      :items="$options.POLICY_SOURCE_OPTIONS_VALUES"
      :toggle-text="selectedValueText"
      :selected="value"
      @select="setPolicySource"
    >
      <template #list-item="{ item }">
        <span :data-testid="`policy-source-${item.value}-option`">{{ item.text }}</span>
      </template>
    </gl-collapsible-listbox>
  </gl-form-group>
</template>
