<script>
import { GlSprintf, GlLink, GlPopover } from '@gitlab/ui';
import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import RuleViewCe from '~/projects/settings/branch_rules/components/index.vue';
import ProtectionRow from '~/projects/settings/branch_rules/components/protection_row.vue';
import ProtectionToggle from '~/projects/settings/branch_rules/components/protection_toggle.vue';
import ApprovalRulesApp from 'ee/approvals/components/approval_rules_app.vue';
import ProjectRules from 'ee/approvals/project_settings/project_rules.vue';
import StatusChecks from 'ee/projects/settings/branch_rules/components/status_checks/status_checks.vue';
import SettingsSection from '~/vue_shared/components/settings/settings_section.vue';
import { I18N } from '~/projects/settings/branch_rules/components/constants';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';

const statusChecksHelpDocLink = helpPagePath('user/project/merge_requests/status_checks');
const codeOwnersHelpDocLink = helpPagePath('user/project/codeowners/_index');
const approvalsHelpDocLink = helpPagePath('user/project/merge_requests/approvals/_index');
const policiesDocumentationLink = helpPagePath(
  'user/application_security/policies/merge_request_approval_policies.md',
);

export default {
  name: 'RuleViewEE',
  i18n: I18N,
  statusChecksHelpDocLink,
  codeOwnersHelpDocLink,
  approvalsHelpDocLink,
  policiesDocumentationLink,
  components: {
    RuleViewCe,
    GlSprintf,
    GlLink,
    GlPopover,
    ProtectionToggle,
    ProtectionRow,
    ApprovalRulesApp,
    ProjectRules,
    StatusChecks,
    SettingsSection,
  },
  mixins: [glListenersMixin],
  inject: {
    securityPoliciesPath: {
      default: '',
    },
    showStatusChecks: { default: false },
    showApprovers: { default: false },
    showCodeOwners: { default: false },
  },
  methods: {
    getModificationBlockedByPolicy(branchProtection) {
      return branchProtection?.modificationBlockedByPolicy;
    },
    getWarnModificationBlockedByPolicy(branchProtection) {
      return branchProtection?.warnModificationBlockedByPolicy;
    },
    isModificationAffectedByPolicy(branchProtection) {
      return (
        branchProtection &&
        (this.getModificationBlockedByPolicy(branchProtection) ||
          this.getWarnModificationBlockedByPolicy(branchProtection))
      );
    },
    deleteBranchRuleTooltip(branchProtection) {
      return this.getModificationBlockedByPolicy(branchProtection)
        ? s__(
            "SecurityOrchestration|You can't unprotect this branch because its protection is enforced by one or more %{securityPoliciesPathStart}security policies%{securityPoliciesPathEnd}. %{linkStart}Learn more%{linkEnd}.",
          )
        : s__(
            "SecurityOrchestration|If one or more %{securityPoliciesPathStart}security policies%{securityPoliciesPathEnd} become enforced, you can't unprotect this branch. %{linkStart}Learn more%{linkEnd}.",
          );
    },
    showStatusChecksSection(branch) {
      return this.showStatusChecks && branch !== this.$options.i18n.allProtectedBranches;
    },
    getStatusChecks(branchRule) {
      return branchRule?.externalStatusChecks?.nodes || [];
    },
    codeOwnersApprovalAttributes(branchProtection) {
      const codeOwnerApprovalRequired = branchProtection?.codeOwnerApprovalRequired;
      const title = codeOwnerApprovalRequired
        ? this.$options.i18n.requiresCodeOwnerApprovalTitle
        : this.$options.i18n.doesNotRequireCodeOwnerApprovalTitle;

      return {
        title,
        description: this.$options.i18n.codeOwnerApprovalDescription,
      };
    },
  },
};
</script>

<template>
  <rule-view-ce v-bind="$attrs" v-on="glListeners()">
    <template #ee-merge-custom-roles="{ memberRoles }">
      <protection-row
        v-if="memberRoles && memberRoles.length"
        :show-divider="true"
        :member-roles="memberRoles"
        :title="s__('BranchRules|Custom roles')"
      />
    </template>

    <template #ee-push-custom-roles="{ memberRoles }">
      <protection-row
        v-if="memberRoles && memberRoles.length"
        :show-divider="true"
        :member-roles="memberRoles"
        :title="s__('BranchRules|Custom roles')"
      />
    </template>
    <!-- EE delete button popover -->
    <template #ee-delete-popover="{ deleteButtonId, branchProtection }">
      <gl-popover v-if="isModificationAffectedByPolicy(branchProtection)" :target="deleteButtonId">
        <gl-sprintf :message="deleteBranchRuleTooltip(branchProtection)">
          <template #securityPoliciesPath="{ content }">
            <gl-link :href="securityPoliciesPath">{{ content }}</gl-link>
          </template>
          <template #link="{ content }">
            <gl-link :href="$options.policiesDocumentationLink" target="_blank">{{
              content
            }}</gl-link>
          </template>
        </gl-sprintf>
      </gl-popover>
    </template>

    <!-- EE code owners toggle -->
    <template
      #ee-code-owners="{ branchProtection, hasPushAccessLevelSet, isCodeOwnersLoading, onToggle }"
    >
      <protection-toggle
        v-if="branchProtection && showCodeOwners"
        :class="{ 'gl-mt-6': !hasPushAccessLevelSet }"
        data-testid="code-owners-content"
        data-test-id-prefix="code-owners"
        :is-protected="branchProtection.codeOwnerApprovalRequired"
        :label="$options.i18n.requiresCodeOwnerApprovalLabel"
        :icon-title="codeOwnersApprovalAttributes(branchProtection).title"
        :description="codeOwnersApprovalAttributes(branchProtection).description"
        :description-link="$options.codeOwnersHelpDocLink"
        :is-loading="isCodeOwnersLoading"
        :is-group-level="branchProtection.isGroupLevel"
        @toggle="onToggle"
      />
    </template>

    <!-- EE approval rules -->
    <template #ee-approval-rules="{ onSubmitted }">
      <approval-rules-app
        v-if="showApprovers"
        :is-mr-edit="false"
        :is-branch-rules-edit="true"
        class="!gl-mt-0"
        @submitted="onSubmitted"
      >
        <template #description>
          <gl-sprintf :message="$options.i18n.approvalsDescription">
            <template #link="{ content }">
              <gl-link :href="$options.approvalsHelpDocLink">{{ content }}</gl-link>
            </template>
          </gl-sprintf>
        </template>

        <template #rules>
          <project-rules :is-branch-rules-edit="true" />
        </template>
      </approval-rules-app>
    </template>

    <!-- EE status checks -->
    <template #ee-status-checks="{ branchRule, branch, isAllBranchesRule, projectPath }">
      <settings-section
        v-if="showStatusChecksSection(branch)"
        :heading="$options.i18n.statusChecksTitle"
        class="-gl-mt-5"
      >
        <template #description>
          <gl-sprintf :message="$options.i18n.statusChecksDescription">
            <template #link="{ content }">
              <gl-link :href="$options.statusChecksHelpDocLink">{{ content }}</gl-link>
            </template>
          </gl-sprintf>
        </template>
        <status-checks
          :branch-rule-id="branchRule.id"
          :status-checks="getStatusChecks(branchRule)"
          :project-path="projectPath"
          :is-all-branches-rule="isAllBranchesRule"
          class="gl-mt-3"
        />
      </settings-section>
    </template>
  </rule-view-ce>
</template>
