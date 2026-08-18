<script>
import { GlSkeletonLoader, GlTooltipDirective } from '@gitlab/ui';
import { uniqueId, orderBy } from 'lodash-es';
import ApprovalCheckRulePopover from 'ee/approvals/components/mr_widget_approval_check/approval_check_rule_popover.vue';
import EmptyRuleApprovers from 'ee/approvals/components/rules/empty_rule_approvers.vue';
import { RULE_TYPE_CODE_OWNER, RULE_TYPE_ANY_APPROVER } from 'ee/approvals/constants';
import { sprintf, __, s__ } from '~/locale';
import UserAvatarList from '~/vue_shared/components/user_avatar/user_avatar_list.vue';
import { TYPENAME_MERGE_REQUEST } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import ApprovedIcon from './approved_icon.vue';
import NumberOfApprovals from './number_of_approvals.vue';
import ApprovalsUsersList from './approvals_users_list.vue';
import approvalRulesQuery from './queries/approval_rules.query.graphql';
import mergeRequestApprovalStateUpdated from './queries/approval_rules.subscription.graphql';
import { createSecurityPolicyRuleHelpText } from './utils';

const INCLUDE_APPROVERS = 1;
const DO_NOT_INCLUDE_APPROVERS = 2;

export default {
  name: 'ApprovalsList',
  apollo: {
    mergeRequest: {
      query: approvalRulesQuery,
      variables() {
        return {
          projectPath: this.projectPath,
          iid: this.iid,
        };
      },
      update: (data) => data?.project?.mergeRequest,
      subscribeToMore: {
        document: mergeRequestApprovalStateUpdated,
        variables() {
          return {
            issuableId: convertToGraphQLId(TYPENAME_MERGE_REQUEST, this.mergeRequest.id),
          };
        },
        skip() {
          return !this.mergeRequest?.id;
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
  components: {
    GlSkeletonLoader,
    UserAvatarList,
    ApprovedIcon,
    ApprovalCheckRulePopover,
    EmptyRuleApprovers,
    NumberOfApprovals,
    ApprovalsUsersList,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    projectPath: {
      type: String,
      required: true,
    },
    iid: {
      type: String,
      required: true,
    },
    codeCoverageCheckHelpPagePath: {
      type: String,
      required: false,
      default: '',
    },
    eligibleApproversDocsPath: {
      type: String,
      required: false,
      default: '',
    },
  },
  data() {
    return {
      mergeRequest: null,
    };
  },
  computed: {
    sections() {
      const approvalRules = this.mergeRequest.approvalState.rules;

      return [
        {
          id: uniqueId(),
          title: '',
          rules: approvalRules.filter((rule) => rule.type.toLowerCase() !== RULE_TYPE_CODE_OWNER),
        },
        {
          id: uniqueId(),
          title: __('Code Owners'),
          rules: orderBy(
            approvalRules
              .filter((rule) => rule.type.toLowerCase() === RULE_TYPE_CODE_OWNER)
              .map((rule) => ({ ...rule, nameClass: 'gl-font-monospace gl-break-all' })),
            [(o) => o.section === 'codeowners', 'name', 'section'],
            ['desc', 'asc', 'asc'],
          ),
        },
      ].filter((x) => x.rules.length);
    },
  },
  methods: {
    getTooltipText(rule) {
      if (!rule?.scanResultPolicies) return '';
      return createSecurityPolicyRuleHelpText(rule.scanResultPolicies);
    },
    summaryText(rule) {
      return rule.approvalsRequired === 0
        ? this.summaryOptionalText(rule)
        : this.summaryRequiredText(rule);
    },
    summaryRequiredText(rule) {
      return sprintf(__('%{count} of %{required} approvals from %{name}'), {
        count: rule.approvedBy.nodes.length,
        required: rule.approvalsRequired,
        name: rule.name,
      });
    },
    summaryOptionalText(rule) {
      return sprintf(__('%{count} approvals from %{name}'), {
        count: rule.approvedBy.nodes.length,
        name: rule.name,
      });
    },
    sectionNameLabel(rule) {
      return sprintf(s__('Approvals|Section: %{section}'), { section: rule.section });
    },
    numberOfColumns(rule) {
      return rule.type.toLowerCase() === this.$options.ruleTypeAnyApprover
        ? DO_NOT_INCLUDE_APPROVERS
        : INCLUDE_APPROVERS;
    },
  },
  i18n: {
    commentedBy: s__('MRApprovals|Commented by'),
    approvedBy: s__('MRApprovals|Approved by'),
  },
  ruleTypeAnyApprover: RULE_TYPE_ANY_APPROVER,
};
</script>

<template>
  <table class="table gl-border-t gl-m-0 gl-rounded-b-xl gl-border-t-section gl-bg-subtle">
    <thead class="thead-white !gl-whitespace-nowrap">
      <tr class="gl-hidden gl-text-sm @md/panel:gl-table-row">
        <th class="!gl-bg-default"></th>
        <th class="gl-w-full !gl-bg-default !gl-pl-0">{{ s__('MRApprovals|Approvers') }}</th>
        <th class="gl-w-full !gl-bg-default"></th>
        <th class="gl-w-full !gl-bg-default">{{ s__('MRApprovals|Approvals') }}</th>
        <th class="gl-w-full !gl-bg-default">{{ s__('MRApprovals|Commented by') }}</th>
        <th class="gl-w-full !gl-bg-default">{{ s__('MRApprovals|Approved by') }}</th>
      </tr>
    </thead>
    <tbody v-if="$apollo.queries.mergeRequest.loading || !mergeRequest" class="!gl-border-t-0">
      <tr>
        <td></td>
        <td class="!gl-pl-0">
          <div class="gl-flex" style="width: 100px; height: 20px">
            <gl-skeleton-loader :width="100" :height="20">
              <rect width="100" height="20" x="0" y="0" rx="4" />
            </gl-skeleton-loader>
          </div>
        </td>
        <td></td>
        <td>
          <div class="gl-flex" style="width: 50px; height: 20px">
            <gl-skeleton-loader :width="50" :height="20">
              <rect width="50" height="20" x="0" y="0" rx="4" />
            </gl-skeleton-loader>
          </div>
        </td>
        <td>
          <div class="gl-flex" style="width: 20px; height: 20px">
            <gl-skeleton-loader :width="20" :height="20">
              <circle cx="10" cy="10" r="10" />
            </gl-skeleton-loader>
          </div>
        </td>
        <td>
          <div class="gl-flex" style="width: 20px; height: 20px">
            <gl-skeleton-loader :width="20" :height="20">
              <circle cx="10" cy="10" r="10" />
            </gl-skeleton-loader>
          </div>
        </td>
      </tr>
    </tbody>
    <template v-else>
      <tbody v-for="{ id, title, rules } in sections" :key="id" class="!gl-border-t-0">
        <tr v-if="title" class="js-section-title gl-bg-default">
          <td class="w-0"></td>
          <td colspan="99" class="!gl-pl-0 gl-text-sm gl-text-subtle">
            <strong>{{ title }}</strong>
          </td>
        </tr>
        <tr v-for="rule in rules" :key="rule.id" data-testid="approval-rules-row">
          <td class="gl-min-w-9 !gl-pr-4">
            <approved-icon class="gl-pl-2" :is-approved="rule.approved" />
          </td>
          <td :colspan="numberOfColumns(rule)" class="!gl-pl-0">
            <div class="js-name gl-hidden gl-items-center @md/panel:gl-flex">
              <empty-rule-approvers
                v-if="rule.type.toLowerCase() === $options.ruleTypeAnyApprover"
                :eligible-approvers-docs-path="eligibleApproversDocsPath"
              />
              <span v-else>
                <span
                  v-if="rule.section && rule.section !== 'codeowners'"
                  :aria-label="sectionNameLabel(rule)"
                  class="small gl-block gl-text-subtle"
                  data-testid="rule-section"
                >
                  {{ rule.section }}
                </span>
                <span
                  v-gl-tooltip.left
                  :class="rule.nameClass"
                  :title="getTooltipText(rule)"
                  data-testid="approval-name"
                >
                  {{ rule.name }}
                </span>
              </span>
              <approval-check-rule-popover
                :rule="rule"
                :code-coverage-check-help-page-path="codeCoverageCheckHelpPagePath"
              />
            </div>
            <div class="js-summary gl-flex !gl-flex-col @md/panel:gl-hidden">
              <empty-rule-approvers
                v-if="rule.type.toLowerCase() === $options.ruleTypeAnyApprover"
                :eligible-approvers-docs-path="eligibleApproversDocsPath"
              />
              <span v-else>{{ summaryText(rule) }}</span>
              <user-avatar-list
                v-if="!rule.fallback && rule.eligibleApprovers.length"
                class="gl-my-3"
                :items="rule.eligibleApprovers"
                :img-size="24"
                empty-text=""
              />
              <approvals-users-list
                v-if="rule.commentedBy.nodes.length > 0"
                :label="$options.i18n.commentedBy"
                :users="rule.commentedBy.nodes"
                class="gl-mb-3"
              />
              <approvals-users-list
                v-if="rule.approvedBy.nodes.length > 0"
                :label="$options.i18n.approvedBy"
                :users="rule.approvedBy.nodes"
                class="gl-mb-3"
              />
            </div>
          </td>
          <td
            v-if="rule.type.toLowerCase() !== $options.ruleTypeAnyApprover"
            class="js-approvers gl-hidden gl-min-w-20 @md/panel:gl-table-cell"
          >
            <user-avatar-list
              :items="rule.eligibleApprovers"
              :img-size="24"
              empty-text=""
              class="gl-flex gl-flex-wrap gl-gap-y-2"
            />
          </td>
          <td class="w-0 js-pending gl-hidden gl-whitespace-nowrap @md/panel:gl-table-cell">
            <number-of-approvals :rule="rule" />
          </td>
          <td class="js-commented-by gl-hidden @md/panel:gl-table-cell">
            <user-avatar-list
              :items="rule.commentedBy.nodes"
              :img-size="24"
              empty-text=""
              class="gl-flex gl-flex-wrap gl-gap-y-2"
            />
          </td>
          <td class="js-approved-by gl-hidden @md/panel:gl-table-cell">
            <user-avatar-list
              :items="rule.approvedBy.nodes"
              :img-size="24"
              empty-text=""
              class="gl-flex gl-flex-wrap gl-gap-y-2"
            />
          </td>
        </tr>
      </tbody>
    </template>
  </table>
</template>
