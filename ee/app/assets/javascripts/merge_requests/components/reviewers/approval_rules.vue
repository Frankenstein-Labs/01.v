<script>
import { GlButton } from '@gitlab/ui';
import { sprintf, __ } from '~/locale';
import ReviewerDropdown from '~/merge_requests/components/reviewers/reviewer_dropdown.vue';
import EmptyRuleApprovers from 'ee/approvals/components/rules/empty_rule_approvers.vue';
import UncollapsedReviewerList from '~/sidebar/components/reviewers/uncollapsed_reviewer_list.vue';
import userPermissionsQuery from '~/merge_requests/components/reviewers/queries/user_permissions.query.graphql';
import { RULE_TYPE_ANY_APPROVER, RULE_TYPE_CODE_OWNER } from 'ee/approvals/constants';

export default {
  name: 'ApprovalRules',
  apollo: {
    userPermissions: {
      query: userPermissionsQuery,
      variables() {
        return {
          fullPath: this.projectPath,
          iid: this.issuableIid,
        };
      },
      update: (data) => data.project?.mergeRequest?.userPermissions || {},
    },
  },
  components: {
    GlButton,
    ReviewerDropdown,
    EmptyRuleApprovers,
    UncollapsedReviewerList,
  },
  inject: ['projectPath', 'issuableIid'],
  props: {
    group: {
      type: Object,
      required: true,
    },
    reviewers: {
      type: Array,
      required: true,
    },
  },
  emits: ['remove-reviewer', 'request-review'],
  data() {
    return {
      userPermissions: {},
      showApprovalSections: this.group.key !== 'optional',
    };
  },
  methods: {
    mappedRules(rules) {
      return rules.map((rule) => ({
        ...rule,
        reviewers: this.reviewersForApprovalRule(rule),
      }));
    },
    getApprovalsLeftText(rule) {
      return sprintf(__('%{approvals} of %{approvalRequired}'), {
        approvals: rule.approvedBy.nodes.length,
        approvalRequired: rule.approvalsRequired,
      });
    },
    reviewersForApprovalRule(rule) {
      if (rule.type.toLowerCase() === RULE_TYPE_ANY_APPROVER) {
        return this.reviewers.filter(
          (r) => !r.mergeRequestInteraction.applicableApprovalRules.length,
        );
      }

      return this.reviewers.filter((r) =>
        r.mergeRequestInteraction.applicableApprovalRules.find((a) => a.id === rule.id),
      );
    },
    toggleApprovalSections() {
      this.showApprovalSections = !this.showApprovalSections;
    },
    reviewersEligibleForRule(rule) {
      let visible = rule.reviewers;

      if (rule.type.toLowerCase() === RULE_TYPE_ANY_APPROVER) {
        visible = this.reviewers;
      }

      return visible;
    },
  },
  ANY_APPROVER: RULE_TYPE_ANY_APPROVER.toUpperCase(),
  CODE_OWNERS: RULE_TYPE_CODE_OWNER.toUpperCase(),
};
</script>

<template>
  <div>
    <div
      v-if="group.key === 'optional'"
      class="gl-border-b-1 gl-border-b-default gl-px-5 gl-py-3 gl-border-b-solid"
    >
      <gl-button
        category="tertiary"
        size="small"
        :icon="showApprovalSections ? 'chevron-down' : 'chevron-right'"
        data-testid="optional-rules-toggle"
        @click="toggleApprovalSections"
      >
        {{ __('Optional approvals') }}
      </gl-button>
    </div>
    <template v-if="showApprovalSections">
      <table
        v-for="section in group.sections"
        :key="section.key"
        class="!gl-mb-0 gl-w-full gl-table-fixed"
      >
        <thead>
          <tr class="gl-border-b-1 gl-border-b-default gl-border-b-solid">
            <th class="w-60p gl-px-5 gl-py-3 gl-text-sm gl-font-semibold gl-text-subtle">
              {{ section.label }}
            </th>
            <th class="w-30p gl-px-5 gl-py-3 gl-text-sm gl-font-semibold gl-text-subtle">
              {{ __('Approvals') }}
            </th>
            <th class="w-30p gl-px-5 gl-py-3"></th>
          </tr>
        </thead>
        <tbody>
          <template v-for="rule in mappedRules(section.rules)">
            <tr
              :key="rule.id"
              class="gl-border-b-1 gl-bg-subtle"
              :class="{
                'gl-border-b-default gl-border-b-solid': !rule.reviewers.length,
              }"
            >
              <td class="gl-px-5 gl-py-3">
                <empty-rule-approvers
                  v-if="rule.type === $options.ANY_APPROVER"
                  popover-id="sidebar-pop-approver"
                  popover-container-id="sidebar-popover-container"
                />
                <template v-else>
                  <span
                    v-if="rule.section && rule.section !== 'codeowners'"
                    class="gl-block"
                    data-testid="section-name"
                  >
                    {{ rule.section }}
                  </span>
                  <span
                    :class="{
                      'gl-break-all gl-font-monospace gl-text-sm':
                        rule.type === $options.CODE_OWNERS,
                    }"
                  >
                    {{ rule.name }}
                  </span>
                </template>
              </td>
              <td class="gl-px-5 gl-py-3">
                {{ getApprovalsLeftText(rule) }}
              </td>
              <td class="gl-px-5 gl-py-3">
                <div class="gl-flex gl-justify-end">
                  <reviewer-dropdown
                    data-testid="reviewer-dropdown"
                    :selected-reviewers="reviewers"
                    :eligible-reviewers="reviewersEligibleForRule(rule)"
                    :users="rule.eligibleApprovers"
                    multiple-selection-enabled
                    :unique-id="rule.id"
                  />
                </div>
              </td>
            </tr>
            <tr
              v-if="rule.reviewers.length"
              :key="`${rule.id}-reviewers`"
              class="gl-border-b-1 gl-border-b-default gl-bg-subtle gl-border-b-solid"
            >
              <td colspan="3" class="gl-px-5 gl-pb-3">
                <uncollapsed-reviewer-list
                  :users="rule.reviewers"
                  :is-editable="userPermissions.adminMergeRequest"
                  :can-rerequest="userPermissions.adminMergeRequest"
                  data-testid="approval-rule-reviewers"
                  @request-review="(data) => $emit('request-review', data)"
                  @remove-reviewer="(data) => $emit('remove-reviewer', data)"
                />
              </td>
            </tr>
          </template>
        </tbody>
      </table>
    </template>
  </div>
</template>
