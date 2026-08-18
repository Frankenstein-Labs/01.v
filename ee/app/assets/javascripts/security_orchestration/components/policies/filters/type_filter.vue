<script>
import { GlFormGroup, GlCollapsibleListbox } from '@gitlab/ui';
import { __, s__, sprintf } from '~/locale';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { validateTypeFilter } from 'ee/security_orchestration/components/policies/utils';
import { POLICY_TYPE_FILTER_OPTIONS } from '../constants';

export default {
  name: 'PolicyTypeFilter',
  components: {
    GlFormGroup,
    GlCollapsibleListbox,
  },
  mixins: [glFeatureFlagMixin()],
  props: {
    value: {
      type: String,
      required: true,
      validator: (value) => validateTypeFilter(value),
    },
  },
  emits: ['input'],
  computed: {
    ariaLabel() {
      return sprintf(s__('SecurityOrchestration|Select type, currently selected: %{selected}'), {
        selected: this.selectedValueText,
      });
    },
    listboxItems() {
      return Object.values(POLICY_TYPE_FILTER_OPTIONS)
        .filter((option) => {
          if (option.value === POLICY_TYPE_FILTER_OPTIONS.DEPENDENCY_FIREWALL.value) {
            return this.glFeatures.dependencyFirewallPhase1;
          }
          return true;
        })
        .map(({ value, text }) => ({ value, text }));
    },

    selectedValueText() {
      return Object.values(POLICY_TYPE_FILTER_OPTIONS).find(({ value }) => value === this.value)
        .text;
    },
  },
  methods: {
    setPolicyType(value) {
      this.$emit('input', value);
    },
  },
  policyTypeFilterId: 'policy-type-filter',
  i18n: {
    label: __('Type'),
  },
};
</script>

<template>
  <gl-form-group
    :label="$options.i18n.label"
    label-size="sm"
    :label-for="$options.policyTypeFilterId"
  >
    <gl-collapsible-listbox
      :id="$options.policyTypeFilterId"
      :aria-label="ariaLabel"
      class="gl-flex"
      toggle-class="gl-truncate"
      block
      :toggle-text="selectedValueText"
      :items="listboxItems"
      :selected="value"
      @select="setPolicyType"
    />
  </gl-form-group>
</template>
