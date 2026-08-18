<script>
import { GlEmptyState } from '@gitlab/ui';
import { s__ } from '~/locale';
import EmptyStateWithoutAnyIssues from '~/work_items/list/components/empty_state_without_any_issues.vue';
import { NO_DATA_EMPTY_STATE_TYPE, NO_DATA_WITH_FILTERS_EMPTY_STATE_TYPE } from '../constants';

export default {
  name: 'IssuesAnalyticsEmptyState',
  components: {
    GlEmptyState,
    EmptyStateWithoutAnyIssues,
  },
  inject: ['showNewIssueDropdown', 'filtersEmptyStateSvgPath'],
  props: {
    emptyStateType: {
      type: String,
      required: true,
      validator: (type) =>
        [NO_DATA_EMPTY_STATE_TYPE, NO_DATA_WITH_FILTERS_EMPTY_STATE_TYPE].includes(type),
    },
  },
  i18n: {
    title: s__('IssuesAnalytics|Sorry, your filter produced no results'),
    description: s__(
      'IssuesAnalytics|To widen your search, change or remove filters in the filter bar above.',
    ),
  },
  computed: {
    hasNoDataWithFilters() {
      return this.emptyStateType === NO_DATA_WITH_FILTERS_EMPTY_STATE_TYPE;
    },
  },
};
</script>

<template>
  <gl-empty-state
    v-if="hasNoDataWithFilters"
    :title="$options.i18n.title"
    :description="$options.i18n.description"
    :svg-path="filtersEmptyStateSvgPath"
    :svg-height="150"
  />
  <empty-state-without-any-issues v-else :show-new-issue-dropdown="showNewIssueDropdown" />
</template>
