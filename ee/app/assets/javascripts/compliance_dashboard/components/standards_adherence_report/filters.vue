<script>
import { GlFilteredSearch } from '@gitlab/ui';
import { __ } from '~/locale';
import ProjectsToken from './filter_tokens/projects_token.vue';
import ComplianceStandardNameToken from './filter_tokens/compliance_standard_name_token.vue';
import ComplianceCheckNameToken from './filter_tokens/compliance_check_name_token.vue';

export default {
  name: 'StandardsAdherenceReportFilters',
  components: {
    GlFilteredSearch,
  },
  props: {
    projects: {
      type: Array,
      required: false,
      default: null,
    },
    groupPath: {
      type: String,
      required: false,
      default: null,
    },
  },
  emits: ['clear', 'submit'],
  computed: {
    filterTokens() {
      return [
        {
          unique: true,
          type: 'standard',
          title: __('Standard'),
          entityType: 'standard',
          token: ComplianceStandardNameToken,
          operators: [{ value: 'matches', description: 'matches' }],
        },
        ...(this.projects
          ? [
              {
                unique: true,
                type: 'project',
                title: __('Project'),
                entityType: 'project',
                token: ProjectsToken,
                operators: [{ value: 'matches', description: 'matches' }],
                groupPath: this.groupPath,
                projects: this.projects,
              },
            ]
          : []),
        {
          unique: true,
          type: 'check',
          title: __('Check'),
          entityType: 'check',
          token: ComplianceCheckNameToken,
          operators: [{ value: 'matches', description: 'matches' }],
        },
      ];
    },
  },
  methods: {
    onFilterSubmit(filters) {
      this.$emit('submit', filters);
    },
    handleFilterClear() {
      this.$emit('clear', []);
    },
  },
};
</script>

<template>
  <gl-filtered-search
    :available-tokens="filterTokens"
    @submit="onFilterSubmit"
    @clear="handleFilterClear"
  />
</template>
