<script>
import { parseGraphQLIssueLinksToRelatedIssues } from '~/observability/utils';
import { getSlotFunction, normalizeRender } from '~/lib/utils/vue3compat/normalize_render';
import { GRAPHQL_METRIC_TYPE } from '../../constants';
import getMetricsRelatedIssues from './graphql/get_metrics_related_issues.query.graphql';

export default normalizeRender({
  props: {
    projectFullPath: {
      type: String,
      required: true,
    },
    metricName: {
      type: String,
      required: true,
    },
    metricType: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      relatedIssues: [],
      error: null,
    };
  },
  apollo: {
    relatedIssues: {
      query: getMetricsRelatedIssues,
      variables() {
        return {
          projectFullPath: this.projectFullPath,
          metricName: this.metricName,
          metricType: GRAPHQL_METRIC_TYPE[this.metricType.toLowerCase()],
        };
      },
      update(data) {
        const links = data.project?.observabilityMetricsLinks?.nodes || [];
        return parseGraphQLIssueLinksToRelatedIssues(links);
      },
      error(error) {
        this.error = error;
      },
    },
  },
  render() {
    const slot = getSlotFunction(this);
    if (!slot) return null;

    return slot({
      issues: this.relatedIssues,
      loading: this.$apollo.loading,
      error: this.error,
    });
  },
});
</script>
