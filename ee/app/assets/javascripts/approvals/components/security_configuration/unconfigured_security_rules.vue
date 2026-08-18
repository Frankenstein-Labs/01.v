<script>
import { GlSkeletonLoader } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapState, mapActions } from 'vuex';
import { COVERAGE_CHECK_NAME } from 'ee/approvals/constants';
import { s__ } from '~/locale';
import UnconfiguredSecurityRule from './unconfigured_security_rule.vue';

export default {
  name: 'UnconfiguredSecurityRules',
  components: {
    UnconfiguredSecurityRule,
    GlSkeletonLoader,
  },
  computed: {
    ...mapState({
      rules: (state) => state.approvals.rules,
      isApprovalsLoading: (state) => state.approvals.isLoading,
    }),
    isRulesLoading() {
      return this.isApprovalsLoading;
    },
    securityRules() {
      return [
        {
          name: COVERAGE_CHECK_NAME,
          description: s__('SecurityApprovals|Requires approval for decreases in test coverage.'),
        },
      ];
    },
    unconfiguredRules() {
      return this.securityRules.reduce((filtered, securityRule) => {
        const hasApprovalRuleDefined = this.hasApprovalRuleDefined(securityRule);

        if (!hasApprovalRuleDefined) {
          filtered.push({ ...securityRule });
        }
        return filtered;
      }, []);
    },
  },
  methods: {
    ...mapActions({ openCreateDrawer: 'openCreateDrawer' }),
    handleAddRule(ruleName) {
      const rule = { defaultRuleName: ruleName };
      this.openCreateDrawer(rule);
    },
    hasApprovalRuleDefined(matchRule) {
      return this.rules.some((rule) => {
        return matchRule.name === rule.name;
      });
    },
  },
};
</script>

<template>
  <tr>
    <td v-if="isRulesLoading" colspan="3">
      <gl-skeleton-loader :lines="3" />
    </td>

    <unconfigured-security-rule
      v-for="rule in unconfiguredRules"
      v-else
      :key="rule.name"
      :rule="rule"
      @enable="handleAddRule(rule.name)"
    />
  </tr>
</template>
