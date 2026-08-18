<script>
const GRAPHQL_TYPENAME_TO_COMPONENT_MAP = {
  VulnerabilityDetailUrl: () => import('./types/report_type_url.vue'),
  VulnerabilityDetailDiff: () => import('./types/report_type_diff.vue'),
  VulnerabilityDetailCode: () => import('./types/report_type_code.vue'),
  VulnerabilityDetailFileLocation: () => import('./types/report_type_file_location.vue'),
  VulnerabilityDetailModuleLocation: () => import('./types/report_type_module_location.vue'),
  VulnerabilityDetailCommit: () => import('./types/report_type_commit.vue'),
  VulnerabilityDetailValue: () => import('./types/report_type_value.vue'),
  VulnerabilityDetailText: () => import('./types/report_type_value.vue'),
  VulnerabilityDetailMarkdown: () =>
    import('~/vue_shared/components/markdown/markdown_content.vue'),
  VulnerabilityDetailBoolean: () => import('./types/report_type_value.vue'),
  VulnerabilityDetailInt: () => import('./types/report_type_value.vue'),
  VulnerabilityDetailList: () => import('./types/report_type_list_graphql.vue'),
  VulnerabilityDetailNamedList: () => import('./types/report_type_named_list_graphql.vue'),
  VulnerabilityDetailTable: () => import('./types/report_type_table_graphql.vue'),
};

export const GRAPHQL_TYPENAMES = Object.keys(GRAPHQL_TYPENAME_TO_COMPONENT_MAP);

export default {
  name: 'GenericReportItemGraphql',
  components: {
    // Register the components that are currently mapped to a GraphQL type, so they can be rendered dynamically
    ...GRAPHQL_TYPENAME_TO_COMPONENT_MAP,
  },
  props: {
    item: {
      type: Object,
      required: true,
    },
  },
};
</script>
<template>
  <component :is="item.type" v-bind="item" data-testid="report-component" />
</template>
