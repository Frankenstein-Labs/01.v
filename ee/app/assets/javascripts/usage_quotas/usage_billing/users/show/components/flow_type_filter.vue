<script>
import { GlCollapsibleListbox, GlFormGroup } from '@gitlab/ui';
import { sprintf, s__ } from '~/locale';

export default {
  name: 'FlowTypeFilter',
  components: {
    GlCollapsibleListbox,
    GlFormGroup,
  },
  props: {
    flowTypes: {
      type: Array,
      required: true,
    },
    appliedFlowTypes: {
      type: Array,
      required: true,
    },
  },
  emits: ['apply'],
  data() {
    return {
      selectedFlowTypes: [...this.appliedFlowTypes],
      flowTypeSearch: '',
    };
  },
  computed: {
    filteredFlowTypes() {
      if (!this.flowTypeSearch) {
        return this.flowTypes;
      }

      const searchLower = this.flowTypeSearch.toLowerCase();
      return this.flowTypes.filter((flowType) =>
        flowType.text?.toLowerCase().includes(searchLower),
      );
    },
    toggleText() {
      if (this.selectedFlowTypes.length === 0) {
        return s__('UsageBillingUserDetails|Any type');
      }

      if (this.selectedFlowTypes.length === this.flowTypes.length) {
        return s__('UsageBillingUserDetails|All types');
      }

      if (this.selectedFlowTypes.length === 1) {
        const selectedType = this.flowTypes.find(
          (type) => type.value === this.selectedFlowTypes[0],
        );
        return selectedType?.text ?? s__('UsageBillingUserDetails|1 flow type selected');
      }

      return sprintf(s__('UsageBillingUserDetails|%{count} flow types selected'), {
        count: this.selectedFlowTypes.length,
      });
    },
  },
  watch: {
    appliedFlowTypes(newValue) {
      this.selectedFlowTypes = [...newValue];
    },
  },
  methods: {
    searchFlowType(searchQuery) {
      this.flowTypeSearch = searchQuery;
    },
    selectAllItems() {
      this.selectedFlowTypes = [...this.flowTypes.map((x) => x.value)];
    },
    onReset() {
      this.selectedFlowTypes = [];
      this.flowTypeSearch = '';
    },
    applyFilter() {
      this.$emit('apply', this.selectedFlowTypes);
    },
  },
};
</script>

<template>
  <div>
    <gl-form-group
      :label="s__('UsageBillingUserDetails|Flow')"
      label-for="flow-type-picker"
      class="gl-m-0"
    >
      <gl-collapsible-listbox
        ref="flowTypeListbox"
        v-model="selectedFlowTypes"
        :items="filteredFlowTypes"
        toggle-id="flow-type-picker"
        :toggle-text="toggleText"
        :search-placeholder="s__('UsageBillingUserDetails|Search types')"
        :no-results-text="s__('UsageBillingUserDetails|No matching types')"
        multiple
        searchable
        fluid-width
        :header-text="s__('UsageBillingUserDetails|Filter flow types')"
        :reset-button-label="s__('UsageBillingUserDetails|Clear')"
        :show-select-all-button-label="s__('UsageBillingUserDetails|Select all')"
        @search="searchFlowType"
        @reset="onReset"
        @select-all="selectAllItems"
        @hidden="applyFilter"
      />
    </gl-form-group>
  </div>
</template>
