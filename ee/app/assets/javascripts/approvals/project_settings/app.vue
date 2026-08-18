<script>
import ApprovalRulesApp from 'ee/approvals/components/approval_rules_app.vue';
import ScanResultPolicies from 'ee/approvals/components/security_orchestration/scan_result_policies.vue';
import ProjectApprovalSettings from './project_approval_settings.vue';
import ProjectRules from './project_rules.vue';

export default {
  name: 'ApprovalsProjectSettingsApp',
  components: {
    ApprovalRulesApp,
    ProjectApprovalSettings,
    ProjectRules,
    ScanResultPolicies,
  },
  inject: ['canReadSecurityPolicies'],
};
</script>

<template>
  <div>
    <approval-rules-app :is-mr-edit="false">
      <template #rules>
        <project-rules />
      </template>
    </approval-rules-app>
    <scan-result-policies v-if="canReadSecurityPolicies" class="gl-mt-5" />
    <project-approval-settings class="gl-mt-5" />
  </div>
</template>
