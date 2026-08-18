<script>
import { BLOCKERS_ROUTE } from '~/merge_requests/reports/constants';
import ReportListItem from '~/merge_requests/reports/components/report_list_item.vue';
import violationsCountQuery from '../queries/violations_count.query.graphql';

export default {
  name: 'BlockersListItem',
  apollo: {
    count: {
      query: violationsCountQuery,
      variables() {
        return { projectPath: this.projectPath, iid: this.iid };
      },
      update: (d) => d.project?.mergeRequest?.policyViolations?.violationsCount || null,
    },
  },
  components: {
    ReportListItem,
  },
  inject: ['projectPath', 'iid'],
  data() {
    return {
      count: null,
    };
  },
  computed: {
    statusIcon() {
      return this.count > 0 ? 'failed' : 'success';
    },
  },
  routeNames: {
    BLOCKERS_ROUTE,
  },
};
</script>

<template>
  <div class="gl-border-b gl-mb-2 gl-border-default gl-pb-4">
    <report-list-item
      :to="$options.routeNames.BLOCKERS_ROUTE"
      :status-icon="statusIcon"
      :count="count"
      :is-loading="$apollo.queries.count.loading"
    >
      {{ s__('MrReports|Blockers') }}
    </report-list-item>
  </div>
</template>
