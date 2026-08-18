<script>
import { GlDisclosureDropdown, GlFilteredSearch } from '@gitlab/ui';
import { __, s__ } from '~/locale';

import complianceFrameworksInGroupQuery from '../../graphql/queries/compliance_frameworks_in_group.query.graphql';
import { GROUP_BY } from '../../constants';

import FrameworkToken from '../../../shared/filter_tokens/compliance_framework_token.vue';
import ProjectToken from './tokens/project_token.vue';
import RequirementToken from './tokens/requirement_token.vue';

export const FILTERS = {
  [GROUP_BY.REQUIREMENTS]: 'requirementId',
  [GROUP_BY.FRAMEWORKS]: 'frameworkId',
  [GROUP_BY.PROJECTS]: 'projectId',
};

const dropdownItems = [
  { text: __('None'), value: null },
  { text: s__('ComplianceStandardsAdherence|Requirements'), value: GROUP_BY.REQUIREMENTS },
  { text: s__('ComplianceStandardsAdherence|Frameworks'), value: GROUP_BY.FRAMEWORKS },
  { text: __('Projects'), value: GROUP_BY.PROJECTS },
];

export default {
  components: {
    GlDisclosureDropdown,
    GlFilteredSearch,
  },
  props: {
    groupPath: {
      type: String,
      required: true,
    },
    groupBy: {
      type: String,
      required: false,
      default: null,
    },
    withProjects: {
      type: Boolean,
      required: false,
      default: false,
    },
    withGroupBy: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['load', 'update:filters', 'update:groupBy'],
  data() {
    return {
      frameworks: [],
      requirements: [],
      selectedTokens: [],
    };
  },
  apollo: {
    frameworks: {
      query: complianceFrameworksInGroupQuery,
      variables() {
        return {
          fullPath: this.groupPath,
        };
      },
      update(data) {
        const { complianceFrameworks } = data.namespace;
        this.requirements = [
          ...new Set(complianceFrameworks.nodes.flatMap((f) => f.complianceRequirements.nodes)),
        ];
        return complianceFrameworks.nodes;
      },
    },
  },
  computed: {
    dropdownItems() {
      return this.withProjects
        ? dropdownItems
        : dropdownItems.filter((item) => item.value !== GROUP_BY.PROJECTS);
    },
    dropdownText() {
      return this.dropdownItems.find((item) => item.value === this.groupBy)?.text;
    },
    filterTokens() {
      const initialTokens = this.withProjects
        ? [
            {
              unique: true,
              type: FILTERS[GROUP_BY.PROJECTS],
              title: __('Project'),
              entityType: 'project',
              token: ProjectToken,
              operators: [{ value: 'is', description: 'is' }],
              fullPath: this.groupPath,
            },
          ]
        : [];

      return [
        ...initialTokens,
        {
          unique: true,
          type: FILTERS[GROUP_BY.FRAMEWORKS],
          title: s__('ComplianceManagement|Framework'),
          token: FrameworkToken,
          operators: [{ value: '=', description: 'is' }],
          frameworks: this.frameworks,
        },
        {
          unique: true,
          type: FILTERS[GROUP_BY.REQUIREMENTS],
          title: s__('ComplianceManagement|Requirement'),
          token: RequirementToken,
          operators: [{ value: '=', description: 'is' }],
          requirements: this.requirements,
        },
      ].filter((token) => token.type !== FILTERS[this.groupBy]);
    },
  },

  watch: {
    requirements() {
      this.$emit('load');
    },
  },

  methods: {
    onGroupSelected(grouping) {
      this.selectedTokens = this.selectedTokens.filter(
        (token) => token.type !== FILTERS[grouping.value] && token.type !== 'filtered-search-term',
      );
      this.$emit('update:filters', this.convertTokensToObject(this.selectedTokens));
      this.$emit('update:groupBy', grouping.value);
    },

    convertTokensToObject(tokens) {
      return Object.fromEntries(tokens.map((token) => [token.type, token.value.data]));
    },

    onFilterSubmit(value) {
      const filteredValues = value.filter((token) => Boolean(token.type));
      this.selectedTokens = filteredValues;

      this.$emit('update:filters', this.convertTokensToObject(filteredValues));
    },
    handleFilterClear() {
      this.$emit('update:filters', {});
    },
  },

  i18n: {
    rawFiltersNotSupported: s__(
      'ComplianceStandardsAdherence|Raw text search is not currently supported. Please use the available filters.',
    ),
    invalidFilterValue: s__(
      'ComplianceStandardsAdherence|Raw filter values is not currently supported. Please use available values.',
    ),
    groupByText: s__('ComplianceStandardsAdherence|Group by'),
    filterByText: s__('ComplianceStandardsAdherence|Filter by'),
  },
};
</script>
<template>
  <div v-if="frameworks.length" class="row-content-block gl-flex gl-border-0 @md/panel:gl-flex-row">
    <div v-if="withGroupBy" class="gl-flex gl-flex-col">
      <label data-testid="dropdown-label" class="gl-leading-normal">
        {{ $options.i18n.groupByText }}
      </label>
      <gl-disclosure-dropdown
        class="gl-mr-6 @lg/panel:gl-mb-0"
        :items="dropdownItems"
        :toggle-text="dropdownText"
        @action="onGroupSelected"
      />
    </div>
    <div class="gl-flex gl-grow-2 gl-flex-col">
      <label for="target-branch-input" class="gl-leading-normal">
        {{ $options.i18n.filterByText }}
      </label>
      <gl-filtered-search
        v-model="selectedTokens"
        loading
        :available-tokens="filterTokens"
        @submit="onFilterSubmit"
        @clear="handleFilterClear"
      />
    </div>
  </div>
</template>
