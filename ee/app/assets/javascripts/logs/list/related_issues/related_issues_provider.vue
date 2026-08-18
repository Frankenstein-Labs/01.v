<script>
import { parseGraphQLIssueLinksToRelatedIssues } from '~/observability/utils';
import { getSlotFunction, normalizeRender } from '~/lib/utils/vue3compat/normalize_render';
import getLogsRelatedIssues from './graphql/get_logs_related_issues.query.graphql';

export default normalizeRender({
  props: {
    projectFullPath: {
      type: String,
      required: true,
    },
    log: {
      type: Object,
      required: false,
      default: null,
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
      query: getLogsRelatedIssues,
      variables() {
        const {
          trace_id: traceId,
          fingerprint,
          severity_number: severityNumber,
          service_name: service,
          timestamp,
        } = this.log;
        return {
          projectFullPath: this.projectFullPath,
          traceId,
          fingerprint,
          severityNumber,
          service,
          timestamp,
        };
      },
      skip() {
        return !this.log;
      },
      update(data) {
        const links = data.project?.observabilityLogsLinks?.nodes || [];
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
