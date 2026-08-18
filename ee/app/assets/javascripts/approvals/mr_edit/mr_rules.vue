<script>
// eslint-disable-next-line no-restricted-imports
import { mapState, mapActions } from 'vuex';
import { __ } from '~/locale';
import UserAvatarList from '~/vue_shared/components/user_avatar/user_avatar_list.vue';
import {
  RULE_TYPE_ANY_APPROVER,
  RULE_TYPE_REGULAR,
  RULE_NAME_ANY_APPROVER,
} from 'ee/approvals/constants';
import EmptyRule from 'ee/approvals/components/rules/empty_rule.vue';
import RuleControls from 'ee/approvals/components/rules/rule_controls.vue';
import Rules from 'ee/approvals/components/rules/rules.vue';
import RuleInput from 'ee/approvals/components/rules/rule_input.vue';

let targetBranchMutationObserver;

export default {
  name: 'MrRules',
  components: {
    UserAvatarList,
    Rules,
    RuleControls,
    EmptyRule,
    RuleInput,
  },
  computed: {
    ...mapState(['settings']),
    ...mapState({
      rules: (state) => state.approvals.rules,
      targetBranch: (state) => state.approvals.targetBranch,
    }),
    hasNamedRule() {
      if (this.settings.allowMultiRule) {
        return this.rules.some((rule) => rule.ruleType !== RULE_TYPE_ANY_APPROVER);
      }

      const [rule] = this.rules;
      return rule.ruleType
        ? rule.ruleType === RULE_TYPE_REGULAR
        : rule.name !== RULE_NAME_ANY_APPROVER;
    },
    firstColumnSpan() {
      return this.hasNamedRule ? '1' : '2';
    },
    firstColumnWidth() {
      return this.hasNamedRule ? 'gl-w-3/10' : 'gl-w-3/4';
    },
    canEdit() {
      return this.settings.canEdit;
    },
    isEditPath() {
      return this.settings.mrSettingsPath;
    },
  },
  watch: {
    rules: {
      handler(newValue) {
        if (!this.settings.allowMultiRule && newValue.length === 0) {
          this.setEmptyRule();
        }
        if (
          this.settings.allowMultiRule &&
          !newValue.some((rule) => rule.ruleType === RULE_TYPE_ANY_APPROVER)
        ) {
          this.addEmptyRule();
        }
      },
      immediate: true,
    },
    targetBranch() {
      this.fetchRules({ targetBranch: this.targetBranch });
    },
  },
  mounted() {
    if (this.isEditPath) {
      this.mergeRequestTargetBranchElement = document.querySelector('#merge_request_target_branch');
      const targetBranch = this.mergeRequestTargetBranchElement?.value;

      this.setTargetBranch(targetBranch);

      if (targetBranch) {
        targetBranchMutationObserver = new MutationObserver(this.onTargetBranchMutation);
        targetBranchMutationObserver.observe(this.mergeRequestTargetBranchElement, {
          attributes: true,
          childList: false,
          subtree: false,
          attributeFilter: ['value'],
        });
      }
    }
  },
  beforeDestroy() {
    if (this.isEditPath && targetBranchMutationObserver) {
      targetBranchMutationObserver.disconnect();
      targetBranchMutationObserver = null;
    }
  },
  methods: {
    ...mapActions(['setEmptyRule', 'addEmptyRule', 'fetchRules', 'setTargetBranch']),
    onTargetBranchMutation() {
      const selectedTargetBranchValue = this.mergeRequestTargetBranchElement.value;

      if (this.targetBranch !== selectedTargetBranchValue) {
        this.setTargetBranch(selectedTargetBranchValue);
      }
    },
    indicatorText(rule) {
      if (rule.hasSource) {
        return rule.overridden ? __('Overridden') : '';
      }

      return __('Added for this merge request');
    },
  },
};
</script>

<template>
  <rules :rules="rules">
    <template #thead="{ name, members, approvalsRequired, actions }">
      <tr>
        <th :colspan="firstColumnSpan" :class="firstColumnWidth">
          {{ hasNamedRule ? name : members }}
        </th>
        <th v-if="hasNamedRule" class="gl-w-2/5">
          <span>{{ members }}</span>
        </th>
        <th class="gl-text-center">{{ approvalsRequired }}</th>
        <th class="gl-text-right">{{ actions }}</th>
      </tr>
    </template>
    <template #tbody="{ rules, name, members, approvalsRequired, actions }">
      <template v-for="(rule, index) in rules">
        <empty-rule
          v-if="rule.ruleType === 'any_approver'"
          :key="index"
          :rule="rule"
          :allow-multi-rule="settings.allowMultiRule"
          :eligible-approvers-docs-path="settings.eligibleApproversDocsPath"
          :can-edit="canEdit"
        />
        <tr v-else :key="index">
          <td :data-label="name">
            <div>
              <div data-testid="approvals-table-name">{{ rule.name }}</div>
              <div ref="indicator" data-testid="indicator" class="gl-text-subtle">
                {{ indicatorText(rule) }}
              </div>
            </div>
          </td>
          <td class="!gl-py-5" data-testid="approvals-table-members" :data-label="members">
            <user-avatar-list
              :items="rule.approvers"
              :img-size="24"
              :empty-text="__('Approvers from private group(s) not shown')"
              class="!-gl-my-2"
            />
          </td>
          <td
            class="gl-text-right"
            data-testid="approvals-table-approvals-required"
            :data-label="approvalsRequired"
          >
            <rule-input :rule="rule" />
          </td>
          <td
            class="@md/panel:!gl-pl-0 @md/panel:!gl-pr-0"
            data-testid="approvals-table-controls"
            :data-label="actions"
          >
            <rule-controls v-if="canEdit" :rule="rule" />
          </td>
        </tr>
      </template>
    </template>
  </rules>
</template>
