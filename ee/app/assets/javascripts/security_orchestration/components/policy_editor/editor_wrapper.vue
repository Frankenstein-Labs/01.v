<script>
import { GlAlert, GlFormGroup, GlFormSelect } from '@gitlab/ui';
import getSecurityPolicyProjectSub from 'ee/security_orchestration/graphql/queries/security_policy_project_created.subscription.graphql';
import { NAMESPACE_TYPES } from '../../constants';
import { POLICY_TYPE_COMPONENT_OPTIONS, SCAN_EXECUTION_POLICY_TYPE } from '../constants';
import { fromYaml } from '../utils';
import { GRAPHQL_ERROR_MESSAGE, SECURITY_POLICY_ACTIONS } from './constants';
import { assignSecurityPolicyProjectAsync, goToPolicyMR, parseError } from './utils';
import DependencyFirewallPolicyEditor from './dependency_firewall/editor_component.vue';
import PipelineExecutionPolicyEditor from './pipeline_execution/editor_component.vue';
import ScanExecutionPolicyEditor from './scan_execution/editor_component.vue';
import ScanResultPolicyEditor from './scan_result/editor_component.vue';
import VulnerabilityManagementPolicyEditor from './vulnerability_management/editor_component.vue';

const MAX_RETRY_COUNT = 5;

export default {
  name: 'EditorWrapper',
  apollo: {
    $subscribe: {
      // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
      newlyCreatedPolicyProject: {
        query() {
          return getSecurityPolicyProjectSub;
        },
        variables() {
          return { fullPath: this.namespacePath };
        },
        result({ data: { securityPolicyProjectCreated } }) {
          if (!securityPolicyProjectCreated) return;

          const { project, errors } = securityPolicyProjectCreated;

          if (errors.length) {
            this.setError(errors.join('\n'));
            this.setLoadingFlag(false);
          }

          if (project) {
            this.securityPolicyProject = {
              ...project,
              branch: project?.branch?.rootRef,
            };
          }
        },
        skip() {
          return this.subscriptionErrorCount > MAX_RETRY_COUNT;
        },
        error(e) {
          this.setError(e.message);
          this.setLoadingFlag(false);
          this.subscriptionErrorCount += 1;
        },
      },
    },
  },
  components: {
    GlAlert,
    GlFormGroup,
    GlFormSelect,
    DependencyFirewallPolicyEditor,
    PipelineExecutionPolicyEditor,
    ScanExecutionPolicyEditor,
    ScanResultPolicyEditor,
    VulnerabilityManagementPolicyEditor,
  },
  inject: {
    assignedPolicyProject: { default: null },
    existingPolicy: { default: null },
    namespacePath: { default: '' },
  },
  props: {
    // This is the POLICY_TYPE_COMPONENT_OPTIONS object for the policy type
    selectedPolicy: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      isRuleMode: true,
      error: '',
      errorMessages: [],
      errorSources: [],
      extraMergeRequestInput: null,
      isCreating: false,
      isDeleting: false,
      policy: null,
      policyModificationAction: null,
      securityPolicyProject: this.assignedPolicyProject,
      subscriptionErrorCount: 0,
    };
  },
  computed: {
    policyUrlParameter() {
      return this.selectedPolicy?.urlParameter || SCAN_EXECUTION_POLICY_TYPE;
    },
    isEditing() {
      return Boolean(this.existingPolicy);
    },
    policyActionName() {
      return this.isEditing ? SECURITY_POLICY_ACTIONS.REPLACE : SECURITY_POLICY_ACTIONS.APPEND;
    },
    originalName() {
      return this.existingPolicy?.name;
    },
    policyOptions() {
      return this.selectedPolicy || POLICY_TYPE_COMPONENT_OPTIONS.scanExecution;
    },
  },
  watch: {
    async securityPolicyProject(project) {
      await this.createPolicyModification(project);
    },
  },
  methods: {
    handleError(error) {
      // Refactor errorSources to allow for customization as part of
      // https://gitlab.com/gitlab-org/gitlab/-/issues/486021
      const newErrorSources = [];
      // Emit error for alert
      if (this.isRuleMode && error.cause?.length) {
        const ACTION_ERROR_FIELD = 'actions';

        const actionErrors = error.cause.filter((cause) => ACTION_ERROR_FIELD === cause.field);

        if (error.cause.length > actionErrors.length) {
          this.setError(error.message);
        }

        // Errors due to the approvers ids do not show up at the top level, so we do not
        // call setError
        if (actionErrors.length) {
          newErrorSources.push(['action', '0', ACTION_ERROR_FIELD, actionErrors]);
        }
      } else if (error.message.toLowerCase().includes('graphql')) {
        this.setError(GRAPHQL_ERROR_MESSAGE);
      } else {
        this.setError(error.message);
      }

      // Process error to pass to specific component
      this.errorSources = [...newErrorSources, ...parseError(error)];
    },
    async handleSave({ action, extraMergeRequestInput = null, policy, isRuleMode = false }) {
      this.extraMergeRequestInput = extraMergeRequestInput;
      this.policyModificationAction = action || this.policyActionName;
      this.policy = policy;
      this.isRuleMode = isRuleMode;

      this.setError('');
      this.errorSources = [];
      this.setLoadingFlag(true);

      try {
        if (!this.securityPolicyProject.fullPath) {
          await assignSecurityPolicyProjectAsync(this.namespacePath);
        } else {
          await this.createPolicyModification(this.securityPolicyProject);
        }
      } catch (e) {
        this.handleError(e);
        this.setLoadingFlag(false);
      }
    },
    async createPolicyModification(assignedSecurityPolicyProject) {
      if (!this.policy || !this.policyModificationAction) return;

      this.setError('');
      this.setLoadingFlag(true);

      try {
        await goToPolicyMR({
          action: this.policyModificationAction,
          assignedPolicyProject: assignedSecurityPolicyProject,
          extraMergeRequestInput: this.extraMergeRequestInput,
          name: this.originalName || fromYaml({ manifest: this.policy })?.name,
          namespacePath: this.namespacePath,
          yamlEditorValue: this.policy,
        });
      } catch (e) {
        this.handleError(e);
        this.setLoadingFlag(false);
        this.policyModificationAction = null;
      }
    },

    setError(errors) {
      [this.error, ...this.errorMessages] = errors.split('\n');
    },
    setLoadingFlag(val) {
      if (this.policyModificationAction === SECURITY_POLICY_ACTIONS.REMOVE) {
        this.isDeleting = val;
      } else {
        this.isCreating = val;
      }
    },
  },
  NAMESPACE_TYPES,
};
</script>

<template>
  <section class="policy-editor">
    <gl-alert
      v-if="error"
      class="security-policies-alert gl-z-2 gl-mt-5"
      :title="error"
      dismissible
      variant="danger"
      data-testid="error-alert"
      sticky
      @dismiss="setError('')"
    >
      <ul v-if="errorMessages.length" class="!gl-mb-0 gl-ml-5">
        <li v-for="errorMessage in errorMessages" :key="errorMessage">
          {{ errorMessage }}
        </li>
      </ul>
    </gl-alert>
    <component
      :is="policyOptions.component"
      :error-sources="errorSources"
      :existing-policy="existingPolicy"
      :is-creating="isCreating"
      :is-deleting="isDeleting"
      :is-editing="isEditing"
      :selected-policy-type="policyUrlParameter"
      @save="handleSave"
      @error="setError($event)"
    />
  </section>
</template>
