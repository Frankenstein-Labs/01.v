<script>
import ApprovalsList from './approvals_list.vue';

export default {
  name: 'ApprovalsFooter',
  components: {
    ApprovalsList,
  },
  props: {
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
    projectPath: {
      type: String,
      required: true,
    },
    iid: {
      type: String,
      required: true,
    },
  },
};
</script>

<template>
  <div class="mr-widget-extension gl-rounded-b-xl gl-border-t-0" data-testid="approvals-footer">
    <approvals-list
      :code-coverage-check-help-page-path="codeCoverageCheckHelpPagePath"
      :eligible-approvers-docs-path="eligibleApproversDocsPath"
      :project-path="projectPath"
      :iid="iid"
    />
  </div>
</template>
