<script>
import { GlFilteredSearch } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import DateToken from '~/vue_shared/components/filtered_search_bar/tokens/date_token.vue';
import ProjectToken from '../../standards_adherence_report/components/filters_bar/tokens/project_token.vue';
import StatusToken from './tokens/status_token.vue';
import ControlToken from './tokens/control_token.vue';

export default {
  name: 'FiltersBar',
  components: {
    GlFilteredSearch,
  },
  props: {
    groupPath: {
      type: String,
      required: true,
    },
  },
  emits: ['update:filters'],
  data() {
    return {
      selectedTokens: [],
    };
  },
  computed: {
    filterTokens() {
      return [
        {
          unique: true,
          type: 'status',
          title: s__('ComplianceReport|Status'),
          token: StatusToken,
          operators: [{ value: '=', description: 'is' }],
        },
        {
          unique: true,
          type: 'projectId',
          title: __('Project'),
          token: ProjectToken,
          operators: [{ value: '=', description: 'is' }],
          fullPath: this.groupPath,
        },
        {
          unique: true,
          type: 'controlId',
          title: s__('ComplianceReport|Control'),
          token: ControlToken,
          operators: [{ value: '=', description: 'is' }],
          groupPath: this.groupPath,
        },
        {
          unique: true,
          type: 'createdAfter',
          title: s__('ComplianceReport|Detected after'),
          token: DateToken,
          operators: [{ value: '=', description: 'is' }],
        },
        {
          unique: true,
          type: 'createdBefore',
          title: s__('ComplianceReport|Detected before'),
          token: DateToken,
          operators: [{ value: '=', description: 'is' }],
        },
      ];
    },
  },
  methods: {
    convertTokensToObject(tokens) {
      return Object.fromEntries(
        tokens.map((token) => {
          const value = token.type === 'status' ? token.value.data.toUpperCase() : token.value.data;
          return [token.type, value];
        }),
      );
    },
    onFilterSubmit(value) {
      const filteredValues = value.filter((token) => Boolean(token.type));
      this.selectedTokens = filteredValues;
      this.$emit('update:filters', this.convertTokensToObject(filteredValues));
    },
    handleFilterClear() {
      this.selectedTokens = [];
      this.$emit('update:filters', {});
    },
  },
  i18n: {
    filterByText: s__('ComplianceReport|Filter by'),
  },
};
</script>

<template>
  <div class="gl-flex gl-flex-col">
    <label for="violations-filter-search" class="gl-leading-normal">
      {{ $options.i18n.filterByText }}
    </label>
    <gl-filtered-search
      id="violations-filter-search"
      v-model="selectedTokens"
      :available-tokens="filterTokens"
      @submit="onFilterSubmit"
      @clear="handleFilterClear"
    />
  </div>
</template>
