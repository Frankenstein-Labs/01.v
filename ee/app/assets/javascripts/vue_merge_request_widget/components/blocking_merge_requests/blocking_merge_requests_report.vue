<script>
import { GlSprintf } from '@gitlab/ui';
import { componentNames } from 'ee/ci/reports/components/issue_body';
import { TYPENAME_MERGE_REQUEST } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import mergeRequestQueryVariablesMixin from '~/vue_merge_request_widget/mixins/merge_request_query_variables';
import getStateSubscription from '~/vue_merge_request_widget/queries/get_state.subscription.graphql';
import { DETAILED_MERGE_STATUS } from '~/vue_merge_request_widget/constants';
import { STATUS_CLOSED, STATUS_MERGED } from '~/issues/constants';
import { n__, sprintf } from '~/locale';
import ReportSection from '~/ci/reports/components/report_section.vue';
import { status as reportStatus } from '~/ci/reports/constants';
import blockingMergeRequestsQuery from '../../queries/blocking_merge_requests.query.graphql';

export default {
  name: 'BlockingMergeRequestsReport',
  apollo: {
    $subscribe: {
      // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
      state: {
        query: getStateSubscription,
        skip() {
          return !this.mr?.id;
        },
        variables() {
          return {
            issuableId: convertToGraphQLId(TYPENAME_MERGE_REQUEST, this.mr?.id),
          };
        },
        result({ data: { mergeRequestMergeStatusUpdated } }) {
          if (
            mergeRequestMergeStatusUpdated?.detailedMergeStatus ===
            DETAILED_MERGE_STATUS.BLOCKED_STATUS
          ) {
            this.$apollo.queries.blockingMergeRequests.refetch();
          }
        },
      },
    },
    blockingMergeRequests: {
      query: blockingMergeRequestsQuery,
      variables() {
        return this.mergeRequestQueryVariables;
      },
      update: (data) => data.project?.mergeRequest?.blockingMergeRequests,
    },
  },
  components: { ReportSection, GlSprintf },
  mixins: [mergeRequestQueryVariablesMixin],
  props: {
    mr: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      blockingMergeRequests: {},
    };
  },
  computed: {
    visibleMergeRequests() {
      return this.blockingMergeRequests.visibleMergeRequests?.reduce((acc, mr) => {
        if (!acc[mr.state]) acc[mr.state] = [];

        acc[mr.state].push(mr);

        return acc;
      }, {});
    },
    shouldRenderBlockingMergeRequests() {
      return this.blockingMergeRequests?.totalCount > 0;
    },
    closedBlockingMergeRequests() {
      return this.visibleMergeRequests.closed || [];
    },
    mergedBlockingMergeRequests() {
      return this.visibleMergeRequests.merged || [];
    },
    unmergedBlockingMergeRequests() {
      return Object.keys(this.visibleMergeRequests)
        .filter((state) => state !== STATUS_MERGED)
        .reduce(
          (unmergedBlockingMRs, state) =>
            state === STATUS_CLOSED
              ? [...this.visibleMergeRequests[state], ...unmergedBlockingMRs]
              : [...unmergedBlockingMRs, ...this.visibleMergeRequests[state]],
          [],
        );
    },
    unresolvedIssues() {
      return this.blockingMergeRequests.hiddenCount > 0
        ? [
            { hiddenCount: this.blockingMergeRequests.hiddenCount },
            ...this.unmergedBlockingMergeRequests,
          ]
        : this.unmergedBlockingMergeRequests;
    },
    isBlocked() {
      return (
        this.blockingMergeRequests.hiddenCount > 0 || this.unmergedBlockingMergeRequests.length > 0
      );
    },
    closedCount() {
      return this.closedBlockingMergeRequests.length;
    },
    unmergedCount() {
      return this.unmergedBlockingMergeRequests.length + this.blockingMergeRequests.hiddenCount;
    },
    blockedByText() {
      if (this.closedCount > 0 && this.closedCount === this.unmergedCount) {
        return sprintf(
          n__(
            'Depends on %{strongStart}%{closedCount} closed%{strongEnd} merge request.',
            'Depends on %{strongStart}%{closedCount} closed%{strongEnd} merge requests.',
            this.closedCount,
          ),
          { closedCount: this.closedCount },
        );
      }

      const mainText = n__(
        'Depends on %d merge request being merged',
        'Depends on %d merge requests being merged',
        this.unmergedCount,
      );

      return this.closedCount > 0
        ? `${mainText} %{strongStart}${n__(
            '(%d closed)',
            '(%d closed)',
            this.closedCount,
          )}%{strongEnd}`
        : mainText;
    },
    status() {
      return this.isBlocked ? reportStatus.ERROR : reportStatus.SUCCESS;
    },
  },
  componentNames,
};
</script>

<template>
  <report-section
    v-if="shouldRenderBlockingMergeRequests"
    class="mr-widget-border-top mr-report blocking-mrs-report"
    :status="status"
    :has-issues="true"
    :unresolved-issues="unresolvedIssues"
    :resolved-issues="mergedBlockingMergeRequests"
    :component="$options.componentNames.BlockingMergeRequestsBody"
    :show-report-section-status-icon="false"
    issues-ul-element-class="content-list"
    issues-list-container-class="!gl-p-0"
    issue-item-class="!gl-p-0"
  >
    <template #success>
      {{ __('All merge request dependencies have been merged') }}
      <span class="gl-ml-1 gl-text-subtle">
        {{
          sprintf(__('(%{mrCount} merged)'), {
            mrCount: blockingMergeRequests.totalCount - unmergedBlockingMergeRequests.length,
          })
        }}
      </span>
    </template>
    <template #error>
      <span>
        <gl-sprintf :message="blockedByText">
          <template #strong="{ content }">
            <strong>{{ content }}</strong>
          </template>
        </gl-sprintf>
      </span>
    </template>
  </report-section>
</template>
