<script>
import { n__, sprintf, s__, __ } from '~/locale';
import { getApprovalRuleNamesLeft } from 'ee/vue_merge_request_widget/mappers';
import { toNounSeriesText } from '~/lib/utils/grammar';
import { TYPENAME_MERGE_REQUEST } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import approvalSummaryQuery from '../../queries/approval_summary.query.graphql';
import approvalSummarySubscription from '../../queries/approval_summary.subscription.graphql';

export default {
  name: 'ApprovalSummary',
  apollo: {
    mergeRequest: {
      query: approvalSummaryQuery,
      variables() {
        return {
          projectPath: this.projectPath,
          iid: this.issuableIid,
        };
      },
      update: (data) => data.project?.mergeRequest,
      subscribeToMore: {
        document: approvalSummarySubscription,
        variables() {
          return {
            issuableId: convertToGraphQLId(TYPENAME_MERGE_REQUEST, this.issuableId),
          };
        },
        updateQuery(
          _,
          {
            subscriptionData: {
              data: { mergeRequestApprovalStateUpdated: queryResult },
            },
          },
        ) {
          if (queryResult) {
            this.mergeRequest = queryResult;
          }
        },
      },
    },
  },
  inject: ['projectPath', 'issuableId', 'issuableIid', 'multipleApprovalRulesAvailable'],
  props: {
    shortText: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      mergeRequest: null,
    };
  },
  computed: {
    isLoading() {
      return this.$apollo?.queries?.mergeRequest?.loading || !this.mergeRequest;
    },
    approvalsOptional() {
      return (
        this.mergeRequest.approvalsRequired === 0 && this.mergeRequest.approvedBy.nodes.length === 0
      );
    },
    approvalsLeft() {
      return this.mergeRequest.approvalsLeft || 0;
    },
    rulesLeft() {
      return getApprovalRuleNamesLeft(
        this.multipleApprovalRulesAvailable,
        (this.mergeRequest.approvalState?.rules || []).filter((r) => !r.approved),
      );
    },
    approvalsLeftMessage() {
      if (this.approvalsOptional) {
        return s__('mrWidget|Approval is optional');
      }

      if (this.mergeRequest.approved) {
        return __('All required approvals given');
      }

      if (this.rulesLeft.length && !this.shortText) {
        return sprintf(
          n__(
            'Requires %{count} approval from %{names}.',
            'Requires %{count} approvals from %{names}.',
            this.approvalsLeft,
          ),
          {
            names: toNounSeriesText(this.rulesLeft),
            count: this.approvalsLeft,
          },
          false,
        );
      }

      if (this.shortText) {
        return n__('Requires %d approval', 'Requires %d approvals', this.approvalsLeft);
      }

      return n__(
        'Requires %d approval from eligible users.',
        'Requires %d approvals from eligible users.',
        this.approvalsLeft,
      );
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-items-center">
    <div v-if="isLoading" class="gl-animate-skeleton-loader gl-h-4 gl-w-full gl-rounded-base"></div>
    <template v-else-if="mergeRequest && multipleApprovalRulesAvailable">
      <p class="gl-mb-0 gl-inline-block gl-text-sm gl-text-subtle">
        {{ approvalsLeftMessage }}
      </p>
      <slot></slot>
    </template>
  </div>
</template>
