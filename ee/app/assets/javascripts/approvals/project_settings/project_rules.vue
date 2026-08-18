<script>
import { GlButton } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapState, mapActions } from 'vuex';
import RuleName from 'ee/approvals/components/rules/rule_name.vue';
import { s__ } from '~/locale';
import UserAvatarList from '~/vue_shared/components/user_avatar/user_avatar_list.vue';
import { RULE_TYPE_ANY_APPROVER, RULE_TYPE_REGULAR } from 'ee/approvals/constants';

import EmptyRule from 'ee/approvals/components/rules/empty_rule.vue';
import RuleInput from 'ee/approvals/components/rules/rule_input.vue';
import RuleBranches from 'ee/approvals/components/rules/rule_branches.vue';
import RuleControls from 'ee/approvals/components/rules/rule_controls.vue';
import Rules from 'ee/approvals/components/rules/rules.vue';
import UnconfiguredSecurityRules from 'ee/approvals/components/security_configuration/unconfigured_security_rules.vue';

export default {
  name: 'ProjectRules',
  i18n: {
    noRulesText: s__('ApprovalRules|Define target branch approval rules for new merge requests.'),
  },
  components: {
    GlButton,
    RuleControls,
    Rules,
    UserAvatarList,
    EmptyRule,
    RuleInput,
    RuleBranches,
    RuleName,
    UnconfiguredSecurityRules,
  },
  props: {
    isBranchRulesEdit: {
      type: Boolean,
      default: false,
      required: false,
    },
  },
  computed: {
    ...mapState(['settings']),
    ...mapState({
      rules: (state) => state.approvals.rules,
      pagination: (state) => state.approvals.rulesPagination,
      isLoading: (state) => state.approvals.isLoading,
    }),
    hasNamedRule() {
      return this.rules.some((rule) => rule.ruleType === RULE_TYPE_REGULAR);
    },
    firstColumnSpan() {
      return this.hasNamedRule ? '1' : '2';
    },
    firstColumnWidth() {
      return this.hasNamedRule ? 'gl-w-1/2' : 'gl-w-full';
    },
    hasPagination() {
      return !this.isBranchRulesEdit && this.pagination.nextPage;
    },
  },
  watch: {
    rules: {
      handler(newValue) {
        if (
          this.settings.allowMultiRule &&
          !newValue.some((rule) => rule.ruleType === RULE_TYPE_ANY_APPROVER) &&
          !this.isBranchRulesEdit
        ) {
          this.addEmptyRule();
        }
      },
      immediate: true,
    },
  },
  methods: {
    ...mapActions(['addEmptyRule', 'fetchRules']),
    canEdit(rule) {
      const { canEdit, allowMultiRule } = this.settings;
      const canEditRuleCounter = canEdit && (!allowMultiRule || !rule.hasSource);

      return canEditRuleCounter;
    },
  },
};
</script>

<template>
  <div>
    <rules :rules="rules">
      <template #thead="{ name, members, approvalsRequired, branches, actions }">
        <tr class="gl-hidden @sm/panel:gl-table-row">
          <th :colspan="firstColumnSpan" :class="firstColumnWidth">
            {{ hasNamedRule ? name : members }}
          </th>
          <th v-if="hasNamedRule" class="gl-hidden gl-w-1/2 @sm/panel:gl-table-cell">
            <span>{{ members }}</span>
          </th>
          <th v-if="settings.allowMultiRule && !isBranchRulesEdit">{{ branches }}</th>
          <th>{{ approvalsRequired }}</th>
          <th>{{ actions }}</th>
        </tr>
      </template>
      <template #tbody="{ rules, name, members, approvalsRequired, branches, actions }">
        <unconfigured-security-rules v-if="!isBranchRulesEdit" />

        <p v-if="isBranchRulesEdit && !rules.length" class="gl-mb-0 gl-p-5 gl-text-subtle">
          {{ $options.i18n.noRulesText }}
        </p>

        <template v-for="(rule, index) in rules">
          <empty-rule
            v-if="rule.ruleType === 'any_approver'"
            :key="index"
            :rule="rule"
            :allow-multi-rule="settings.allowMultiRule"
            :is-mr-edit="false"
            :eligible-approvers-docs-path="settings.eligibleApproversDocsPath"
            :is-branch-rules-edit="isBranchRulesEdit"
            :can-edit="canEdit(rule)"
          />
          <tr v-else :key="index">
            <td data-testid="approvals-table-name" :data-label="name">
              <rule-name :name="rule.name" />
            </td>
            <td class="!gl-py-5" data-testid="approvals-table-members" :data-label="members">
              <user-avatar-list
                :items="rule.eligibleApprovers"
                :img-size="24"
                empty-text=""
                class="!-gl-my-2"
              />
            </td>
            <td
              v-if="settings.allowMultiRule && !isBranchRulesEdit"
              data-testid="approvals-table-branches"
              :data-label="branches"
            >
              <rule-branches :rule="rule" />
            </td>
            <td
              class="!gl-py-5"
              data-testid="approvals-table-approvals-required"
              :data-label="approvalsRequired"
            >
              <rule-input :rule="rule" :is-branch-rules-edit="isBranchRulesEdit" />
            </td>
            <td
              class="!gl-whitespace-nowrap @md/panel:!gl-pl-0 @md/panel:!gl-pr-0"
              data-testid="approvals-table-controls"
              :data-label="actions"
            >
              <rule-controls v-if="canEdit(rule)" :rule="rule" />
            </td>
          </tr>
        </template>
      </template>
    </rules>

    <div v-if="hasPagination" class="gl-mb-4 gl-mt-6 gl-flex gl-justify-center">
      <gl-button :loading="isLoading" @click="fetchRules">{{ __('Show more') }}</gl-button>
    </div>
  </div>
</template>
