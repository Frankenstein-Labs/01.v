<script>
import { __ } from '~/locale';
import { TYPENAME_MERGE_REQUEST } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import approvalRulesQuery from 'ee/vue_merge_request_widget/components/approvals/queries/approval_rules.query.graphql';
import approvalRulesSubscription from 'ee/vue_merge_request_widget/components/approvals/queries/approval_rules.subscription.graphql';
import {
  RULE_TYPE_ANY_APPROVER,
  RULE_TYPE_REGULAR,
  RULE_TYPE_REPORT_APPROVER,
  RULE_TYPE_CODE_OWNER,
} from 'ee/approvals/constants';
import ApprovalRules from './approval_rules.vue';

export default {
  name: 'ApprovalRulesWrapper',
  apollo: {
    approvalRules: {
      query: approvalRulesQuery,
      variables() {
        return {
          projectPath: this.projectPath,
          iid: this.issuableIid,
        };
      },
      skip() {
        return !this.multipleApprovalRulesAvailable;
      },
      update: (data) => data.project?.mergeRequest?.approvalState?.rules || [],
      subscribeToMore: {
        document: approvalRulesSubscription,
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
            this.approvalRules = queryResult.approvalState?.rules || [];
          }
        },
      },
    },
  },
  components: {
    ApprovalRules,
  },
  inject: ['projectPath', 'issuableIid', 'issuableId', 'multipleApprovalRulesAvailable'],
  props: {
    reviewers: {
      type: Array,
      required: true,
    },
  },
  emits: ['remove-reviewer', 'request-review'],
  data() {
    return {
      approvalRules: [],
    };
  },
  computed: {
    isLoading() {
      return this.$apollo?.queries.approvalRules.loading;
    },
    mappedApprovalRules() {
      const codeOwners = this.approvalRules.filter(
        ({ type }) => type.toLowerCase() === RULE_TYPE_CODE_OWNER,
      );
      const regular = this.approvalRules.filter((r) => {
        const type = r.type.toLowerCase();

        return (
          type === RULE_TYPE_REGULAR ||
          type === RULE_TYPE_ANY_APPROVER ||
          type === RULE_TYPE_REPORT_APPROVER
        );
      });

      return [
        {
          key: 'required',
          sections: [
            {
              key: 'regular',
              label: __('Approval Rules'),
              rules: regular.filter((r) => r.approvalsRequired),
            },
            {
              key: 'code_owner',
              label: __('Code Owners'),
              rules: codeOwners.filter((r) => r.approvalsRequired),
            },
          ].filter(({ rules }) => rules.length),
        },
        {
          key: 'optional',
          sections: [
            {
              key: 'regular',
              label: __('Approval Rules'),
              rules: regular.filter((r) => !r.approvalsRequired),
            },
            {
              key: 'code_owner',
              label: __('Code Owners'),
              rules: codeOwners.filter((r) => !r.approvalsRequired),
            },
          ].filter(({ rules }) => rules.length),
        },
      ].filter(({ sections }) => sections.length);
    },
  },
};
</script>

<template>
  <div v-if="isLoading">
    <div class="gl-animate-skeleton-loader gl-mb-3 gl-h-4 !gl-max-w-30 gl-rounded-base"></div>
    <div class="gl-animate-skeleton-loader gl-mb-3 gl-h-4 !gl-max-w-30 gl-rounded-base"></div>
    <div class="gl-animate-skeleton-loader gl-mb-3 gl-h-4 !gl-max-w-30 gl-rounded-base"></div>
    <div class="gl-animate-skeleton-loader gl-mb-3 gl-h-4 !gl-max-w-30 gl-rounded-base"></div>
  </div>
  <div v-else class="!gl-p-0">
    <approval-rules
      v-for="group in mappedApprovalRules"
      :key="group.key"
      :reviewers="reviewers"
      :group="group"
      @request-review="(data) => $emit('request-review', data)"
      @remove-reviewer="(data) => $emit('remove-reviewer', data)"
    />
  </div>
</template>
