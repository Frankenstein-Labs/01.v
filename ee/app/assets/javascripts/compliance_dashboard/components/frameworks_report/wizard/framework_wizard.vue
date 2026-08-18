<script>
import {
  GlSprintf,
  GlAlert,
  GlButton,
  GlLink,
  GlLoadingIcon,
  GlTooltip,
  GlModal,
  GlToastMixin,
} from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { sprintf, s__, __ } from '~/locale';
import { SAVE_ERROR } from 'ee/groups/settings/compliance_frameworks/constants';
import {
  getSubmissionParams,
  initialiseFormData,
} from 'ee/groups/settings/compliance_frameworks/utils';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { fromYaml } from 'ee/security_orchestration/components/utils';
import { PIPELINE_EXECUTION_POLICY_TYPE } from 'ee/security_orchestration/components/constants';
import WizardStepper from '~/vue_shared/components/wizard_stepper/wizard_stepper.vue';
import {
  ROUTE_NEW_FRAMEWORK_SUCCESS,
  ROUTE_FRAMEWORKS,
  ROUTE_EDIT_FRAMEWORK,
} from '../../../constants';
import { convertFrameworkIdToGraphQl } from '../../../utils';
import * as formHelpers from '../framework_form_helpers';
import getComplianceFrameworkQuery from './graphql/get_compliance_framework.query.graphql';
import DeleteModal from './components/delete_modal.vue';
import { i18n, requirementEvents } from './constants';
import BasicInformationSection from './components/basic_information_section.vue';
import RequirementsStep from './steps/requirements_step.vue';
import PoliciesStep from './steps/policies_step.vue';
import ProjectsStep from './steps/projects_step.vue';
import MethodStep from './steps/method_step.vue';
import TemplateStep from './steps/template_step.vue';

const STEP_METHOD = 'method';
const STEP_TEMPLATE = 'template';
const STEP_DETAILS = 'details';
const STEP_REQUIREMENTS = 'requirements';
const STEP_POLICIES = 'policies';
const STEP_PROJECTS = 'projects';

export default {
  name: 'FrameworkWizard',
  components: {
    GlSprintf,
    GlAlert,
    GlButton,
    GlLink,
    GlLoadingIcon,
    GlTooltip,
    GlModal,
    WizardStepper,
    DeleteModal,
    MethodStep,
    TemplateStep,
    BasicInformationSection,
    RequirementsStep,
    PoliciesStep,
    ProjectsStep,
  },
  mixins: [GlToastMixin],
  inject: [
    'pipelineConfigurationFullPathEnabled',
    'groupPath',
    'featureSecurityPoliciesEnabled',
    'pipelineExecutionPolicyPath',
    'migratePipelineToPolicyPath',
    'namespaceId',
  ],
  data() {
    return {
      errorMessage: '',
      formData: initialiseFormData(),
      requirements: [],
      originalName: '',
      showValidation: false,
      isSaving: false,
      isDeleting: false,
      hasMigratedPipeline: false,
      showMigrationPopup: false,
      currentNamespaceId: null,
      currentStepKey: this.$route.params.id ? STEP_DETAILS : STEP_METHOD,
      visitedSteps: this.$route.params.id ? [STEP_DETAILS] : [STEP_METHOD],
      detailsStepIsValid: true,
      creationMode: 'blank',
      selectedTemplateId: null,
      policiesCount: null,
    };
  },
  apollo: {
    // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
    namespace: {
      query: getComplianceFrameworkQuery,
      variables() {
        return this.queryVariables;
      },
      result({ data }) {
        this.currentNamespaceId = data?.namespace?.id;

        const [complianceFramework] = data?.namespace?.complianceFrameworks?.nodes || [];
        if (complianceFramework) {
          const { complianceRequirements, ...rest } = complianceFramework;
          this.formData = { ...rest };
          this.requirements = complianceRequirements?.nodes
            ? [...complianceRequirements.nodes].sort((a, b) => {
                const idA = getIdFromGraphQLId(a.id);
                const idB = getIdFromGraphQLId(b.id);
                return Number(idA) - Number(idB);
              })
            : [];
          this.originalName = complianceFramework.name;
          const policyBlob =
            data.namespace.securityPolicyProject?.repository?.blobs?.nodes?.[0]?.rawBlob;
          if (policyBlob) {
            const id = getIdFromGraphQLId(this.graphqlId);
            const policy = fromYaml({
              manifest: policyBlob,
              type: PIPELINE_EXECUTION_POLICY_TYPE,
              addIds: false,
            });

            this.hasMigratedPipeline = Boolean(
              policy?.policy_scope?.compliance_frameworks?.find((f) => f.id === id) &&
              policy?.metadata?.compliance_pipeline_migration,
            );
          }
        } else {
          this.errorMessage = this.$options.i18n.fetchError;
        }
      },
      error(error) {
        this.errorMessage = this.$options.i18n.fetchError;
        Sentry.captureException(error);
      },
      skip() {
        return this.isNewFramework;
      },
    },
  },
  computed: {
    isLoading() {
      return this.$apollo.loading || this.isSaving;
    },
    isEditing() {
      return Boolean(this.$route.params.id);
    },
    isNewFramework() {
      return !this.isEditing;
    },
    isDefaultFramework() {
      return this.formData.default;
    },
    hasLinkedPolicies() {
      if (!this.shouldRenderPolicyStep) return false;
      return this.policiesCount === null || this.policiesCount > 0;
    },
    queryVariables() {
      return {
        fullPath: this.groupPath,
        complianceFramework: this.graphqlId,
      };
    },
    deleteBtnDisabled() {
      return this.hasLinkedPolicies || this.isDefaultFramework || this.isFrameworkInherited;
    },
    deleteBtnDisabledTooltip() {
      return this.isDefaultFramework || this.isFrameworkInherited
        ? this.$options.i18n.deleteButtonDefaultFrameworkDisabledTooltip
        : this.$options.i18n.deleteButtonLinkedPoliciesDisabledTooltip;
    },
    refetchConfig() {
      return {
        awaitRefetchQueries: true,
        refetchQueries: [
          {
            query: getComplianceFrameworkQuery,
            variables: {
              fullPath: this.groupPath,
            },
          },
        ],
      };
    },
    title() {
      return this.isNewFramework
        ? this.$options.i18n.addFrameworkTitle
        : sprintf(
            this.$options.i18n.editFrameworkTitle,
            { frameworkName: this.originalName },
            false,
          );
    },
    graphqlId() {
      return this.$route.params.id ? convertFrameworkIdToGraphQl(this.$route.params.id) : null;
    },
    shouldRenderPolicyStep() {
      return this.isEditing && this.featureSecurityPoliciesEnabled;
    },
    showModal: {
      get() {
        const pipeline = this.hasPipeline;
        return pipeline != null && pipeline.length > 0 && this.showMigrationPopup;
      },
      set() {
        this.showMigrationPopup = false;
      },
    },
    hasPipeline() {
      return this.formData.pipelineConfigurationFullPath;
    },
    isFrameworkInherited() {
      if (!this.formData.namespaceId || !this.currentNamespaceId) {
        return false;
      }

      const frameworkNsId = getIdFromGraphQLId(this.formData.namespaceId);
      const currentNsId = getIdFromGraphQLId(this.currentNamespaceId);

      return frameworkNsId !== currentNsId;
    },
    stepKeys() {
      if (this.isEditing) {
        const keys = [STEP_DETAILS, STEP_REQUIREMENTS];
        if (this.shouldRenderPolicyStep) {
          keys.push(STEP_POLICIES);
        }
        keys.push(STEP_PROJECTS);
        return keys;
      }
      return [STEP_METHOD, STEP_TEMPLATE, STEP_DETAILS, STEP_REQUIREMENTS, STEP_PROJECTS];
    },
    isTemplateMode() {
      return this.creationMode === 'template';
    },
    currentStepIndex() {
      return this.stepKeys.indexOf(this.currentStepKey);
    },
    isFirstStep() {
      return this.currentStepIndex === 0;
    },
    isLastStep() {
      return this.currentStepIndex === this.stepKeys.length - 1;
    },
    wizardSteps() {
      return this.stepKeys.map((key, index) => {
        const stepNumber = index + 1;
        const isVisited = this.visitedSteps.includes(key);
        return {
          id: stepNumber,
          label: this.$options.stepLabels[key],
          // create mode: only visited steps are clickable; the Template step is always disabled
          //              (placeholder until template selection is wired up).
          // edit mode: all steps clickable.
          disabled: this.stepIsDisabled(key) || (this.isNewFramework && !isVisited),
          // error highlight: details step is invalid AND was visited (so the user has seen it)
          error:
            key === STEP_DETAILS && isVisited && this.showValidation && !this.detailsStepIsValid,
        };
      });
    },
    activeStepNumber() {
      return this.currentStepIndex + 1;
    },
    showCreateFooter() {
      return this.isNewFramework;
    },
    isMethodStep() {
      return this.currentStepKey === STEP_METHOD;
    },
    isNextDisabled() {
      return (
        this.currentStepKey === STEP_TEMPLATE && this.isTemplateMode && !this.selectedTemplateId
      );
    },
  },
  methods: {
    handlePoliciesCountLoaded(count) {
      this.policiesCount = count;
    },
    setError(error, userFriendlyText, loadingProp = 'isSaving') {
      this[loadingProp] = false;
      this.errorMessage = userFriendlyText;
      Sentry.captureException(error);
    },
    visitStep(key) {
      if (!this.visitedSteps.includes(key)) {
        this.visitedSteps = [...this.visitedSteps, key];
      }
    },
    stepIsDisabled(key) {
      // In blank-creation mode the Template step is non-interactive; in template
      // mode the user actively picks a template there.
      return key === STEP_TEMPLATE && !this.isTemplateMode;
    },
    findEnabledStep(startIndex, direction) {
      let idx = startIndex;
      let key = this.stepKeys[idx];
      while (key && this.stepIsDisabled(key)) {
        idx += direction;
        key = this.stepKeys[idx];
      }
      return key;
    },
    onStepClick(stepId) {
      const idx = stepId - 1;
      const key = this.stepKeys[idx];
      if (!key || this.stepIsDisabled(key)) return;
      // Create mode: linear gating — only allow nav to visited steps; not future ones
      if (this.isNewFramework && !this.visitedSteps.includes(key)) return;
      this.visitStep(key);
      this.currentStepKey = key;
    },
    next() {
      if (this.currentStepKey === STEP_DETAILS && !this.detailsStepIsValid) {
        this.showValidation = true;
        return;
      }
      if (this.isNextDisabled) {
        return;
      }
      const nextKey = this.findEnabledStep(this.currentStepIndex + 1, 1);
      if (!nextKey) return;
      this.visitStep(nextKey);
      this.currentStepKey = nextKey;
      this.showValidation = false;
    },
    back() {
      const prevKey = this.findEnabledStep(this.currentStepIndex - 1, -1);
      if (prevKey) {
        this.currentStepKey = prevKey;
      }
    },
    onMethodSelectBlank() {
      this.creationMode = 'blank';
      this.selectedTemplateId = null;
      this.next();
    },
    onMethodSelectTemplate() {
      this.creationMode = 'template';
      this.visitStep(STEP_TEMPLATE);
      this.currentStepKey = STEP_TEMPLATE;
    },
    onTemplateSelected(template) {
      this.selectedTemplateId = template.id;
      this.formData = {
        ...this.formData,
        name: template.name,
        description: template.description,
        color: template.color,
      };
      this.requirements = (template.requirements || []).map((requirement) => ({
        ...requirement,
        stagedControls: (requirement.controls || []).map((control) => ({
          ...control,
          controlType: control.controlType ?? control.control_type,
        })),
      }));
      this.visitStep(STEP_DETAILS);
      this.currentStepKey = STEP_DETAILS;
    },
    onMethodImported(frameworkId) {
      this.$router.push({
        name: ROUTE_EDIT_FRAMEWORK,
        params: { id: frameworkId },
      });
    },
    onDetailsInput(value) {
      this.formData = value;
    },
    navigateOutEditView() {
      if (this.isNewFramework) {
        this.$router.back();
        return;
      }

      this.$router.push({
        name: ROUTE_FRAMEWORKS,
        query: { id: getIdFromGraphQLId(this.formData.id) },
      });
    },
    navigateNewFramework(frameworkId) {
      this.$router.push({
        name: ROUTE_NEW_FRAMEWORK_SUCCESS,
        query: { id: getIdFromGraphQLId(frameworkId) },
      });
    },
    interjectModal() {
      if (!this.hasPipeline) {
        this.handleMutationSuccess(this.formData.id);
      }
      this.showMigrationPopup = true;
    },
    handleMutationSuccess(frameworkId) {
      if (this.isNewFramework) {
        this.navigateNewFramework(frameworkId);
      }
      this.showMigrationPopup = false;
    },
    async onSubmit() {
      this.showValidation = true;
      this.errorMessage = '';

      if (!this.detailsStepIsValid) {
        this.currentStepKey = STEP_DETAILS;
        return;
      }

      try {
        this.isSaving = true;
        const params = getSubmissionParams(
          this.formData,
          this.pipelineConfigurationFullPathEnabled,
        );

        if (this.isNewFramework) {
          let frameworkId;
          if (this.isTemplateMode) {
            frameworkId = await formHelpers.submitFromTemplate(this.$apollo, {
              groupPath: this.groupPath,
              templateId: this.selectedTemplateId,
              overrides: {
                name: this.formData.name,
                description: this.formData.description,
                color: this.formData.color,
                default: this.formData.default,
              },
              projects: this.formData.projects,
            });
          } else {
            frameworkId = await formHelpers.submitNewFramework(this.$apollo, {
              groupPath: this.groupPath,
              params,
              requirements: this.requirements,
            });
          }
          this.handleMutationSuccess(frameworkId);
        } else {
          await formHelpers.updateFramework(this.$apollo, {
            graphqlId: this.graphqlId,
            params,
          });
          this.interjectModal();
        }
      } catch (errors) {
        if (Array.isArray(errors)) {
          if (this.handleDuplicateNameError(errors)) {
            return;
          }
          const errorMessage = sprintf(
            __('Unable to save this compliance framework. %{errors}. Please try again'),
            { errors: errors.join('. ') },
            false,
          );
          this.setError(errors[0], errorMessage);
        } else {
          this.setError(errors, SAVE_ERROR);
        }
      } finally {
        this.isSaving = false;
      }
    },
    handleDuplicateNameError(errors) {
      const duplicate = errors.some((err) => /name has already been taken/i.test(err));
      if (!duplicate) return false;

      this.errorMessage = this.$options.i18n.nameInputDuplicateOnSubmit(this.formData.name);
      this.visitStep(STEP_DETAILS);
      this.currentStepKey = STEP_DETAILS;
      this.showValidation = true;
      this.isSaving = false;
      return true;
    },
    async handleCreateRequirement({ requirement, index }) {
      if (this.isNewFramework) {
        if (index !== null) {
          this.requirements.splice(index, 0, requirement);
        } else {
          this.requirements.push(requirement);
        }
      } else {
        try {
          await formHelpers.createRequirementAtIndex(this.$apollo, {
            frameworkId: this.graphqlId,
            requirement,
            index,
            isNewFramework: false,
            queryVariables: this.queryVariables,
            graphqlId: this.graphqlId,
          });
        } catch (error) {
          this.setError(error, error);
        }
      }
    },
    async handleUpdateRequirement({ requirement, index }) {
      if (this.isNewFramework) {
        if (index !== null) {
          this.requirements.splice(index, 1, requirement);
        }
      } else {
        try {
          if (requirement?.id) {
            await formHelpers.updateRequirement(this.$apollo, {
              requirement,
              queryVariables: this.queryVariables,
              graphqlId: this.graphqlId,
            });
            if (index !== null) {
              const updatedRequirement = {
                ...requirement,
                complianceRequirementsControls: {
                  nodes:
                    requirement.stagedControls?.map((control) => ({
                      id: control.id,
                      name: control.name,
                      controlType: control.controlType,
                      expression: control.expression,
                      __typename: 'ComplianceRequirementControl',
                    })) || [],
                  __typename: 'ComplianceRequirementControlConnection',
                },
              };
              this.requirements.splice(index, 1, updatedRequirement);
            }
          }
        } catch (error) {
          this.setError(error, error);
        }
      }
    },
    async handleDeleteRequirement(index) {
      const requirementToDelete = this.requirements[index];
      if (!requirementToDelete) {
        return;
      }

      if (this.isNewFramework) {
        this.requirements.splice(index, 1);
        this.showUndoDeleteRequirementToast(requirementToDelete, index);
      } else if (requirementToDelete.id) {
        try {
          await formHelpers.deleteRequirement(this.$apollo, {
            requirementId: requirementToDelete.id,
            queryVariables: this.queryVariables,
            graphqlId: this.graphqlId,
          });
          this.showUndoDeleteRequirementToast(requirementToDelete, index);
        } catch (error) {
          this.setError(error, error);
        }
      }
    },
    showUndoDeleteRequirementToast(requirementToDelete, index) {
      const { id, ...requirement } = requirementToDelete;
      this.$toast.show(this.$options.i18n.requirementRemovedMessage, {
        action: {
          text: __('Undo'),
          onClick: (_, toast) => {
            this.handleCreateRequirement({ requirement, index });
            toast.hide();
          },
        },
      });
    },
    async deleteFramework() {
      this.isDeleting = true;
      try {
        await formHelpers.deleteFramework(this.$apollo, {
          graphqlId: this.graphqlId,
          refetchConfig: this.refetchConfig,
        });
        this.$router.back();
      } catch (error) {
        this.setError(new Error(error), error, 'isDeleting');
      }
    },
    onDelete() {
      this.$refs.deleteModal.show();
    },
    updateProjects({ addProjects, removeProjects }) {
      this.formData.projects = {
        addProjects,
        removeProjects,
      };
    },
  },
  modalId: 'warn-when-using-pipeline-modal',
  i18n,
  requirementEvents,
  stepLabels: {
    [STEP_METHOD]: s__('ComplianceFrameworks|Method'),
    [STEP_TEMPLATE]: s__('ComplianceFrameworks|Template (Optional)'),
    [STEP_DETAILS]: s__('ComplianceFrameworks|Basic information'),
    [STEP_REQUIREMENTS]: s__('ComplianceFrameworks|Requirements & Controls'),
    [STEP_POLICIES]: s__('ComplianceFrameworks|Policies'),
    [STEP_PROJECTS]: s__('ComplianceFrameworks|Scoping'),
  },
  STEP_METHOD,
  STEP_TEMPLATE,
  STEP_DETAILS,
  STEP_REQUIREMENTS,
  STEP_POLICIES,
  STEP_PROJECTS,
};
</script>

<template>
  <div class="gl-mt-7">
    <gl-alert v-if="errorMessage" class="gl-mb-7" variant="danger" :dismissible="false">
      {{ errorMessage }}
    </gl-alert>

    <gl-modal
      ref="modal"
      v-model="showModal"
      data-testid="pipeline-migration-popup"
      :modal-id="$options.modalId"
      :title="$options.i18n.deprecationWarning.title"
      hide-footer
    >
      <p class="gl-mb-0">
        <gl-sprintf :message="$options.i18n.deprecationWarning.message">
          <template #link="{ content }">
            <gl-link :href="pipelineExecutionPolicyPath" target="_blank">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </p>
      <p>
        <gl-sprintf :message="$options.i18n.deprecationWarning.details">
          <template #link="{ content }">
            <gl-link :href="migratePipelineToPolicyPath" target="_blank">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </p>
    </gl-modal>

    <gl-loading-icon v-if="isLoading" size="lg" />

    <template v-else>
      <h2 class="gl-heading-2 gl-mb-7" data-testid="wizard-title">{{ title }}</h2>

      <wizard-stepper
        :steps="wizardSteps"
        :current-step="activeStepNumber"
        @step-click="onStepClick"
      />

      <div>
        <method-step
          v-if="currentStepKey === $options.STEP_METHOD"
          @select-blank="onMethodSelectBlank"
          @select-template="onMethodSelectTemplate"
          @imported="onMethodImported"
        />

        <template-step
          v-if="currentStepKey === $options.STEP_TEMPLATE && isTemplateMode"
          @template-selected="onTemplateSelected"
        />

        <basic-information-section
          v-show="currentStepKey === $options.STEP_DETAILS"
          :key="`details-${selectedTemplateId || 'blank'}`"
          :value="formData"
          :has-migrated-pipeline="hasMigratedPipeline"
          :show-validation="showValidation"
          :is-inherited="isFrameworkInherited"
          @input="onDetailsInput"
          @validity-change="detailsStepIsValid = $event"
        />

        <requirements-step
          v-if="currentStepKey === $options.STEP_REQUIREMENTS"
          :requirements="requirements"
          :is-new-framework="isNewFramework"
          :is-inherited="isFrameworkInherited"
          :readonly="isTemplateMode"
          @[$options.requirementEvents.create]="handleCreateRequirement"
          @[$options.requirementEvents.update]="handleUpdateRequirement"
          @[$options.requirementEvents.delete]="handleDeleteRequirement"
        />

        <policies-step
          v-if="currentStepKey === $options.STEP_POLICIES && shouldRenderPolicyStep"
          :count="policiesCount ?? 0"
          :full-path="groupPath"
          :graphql-id="graphqlId"
          :is-inherited="isFrameworkInherited"
          @policies-count-loaded="handlePoliciesCountLoaded"
        />

        <projects-step
          v-if="currentStepKey === $options.STEP_PROJECTS"
          :compliance-framework="formData"
          :group-path="groupPath"
          @update:projects="updateProjects"
        />

        <div class="gl-flex gl-gap-3 gl-px-5 gl-pt-6">
          <template v-if="showCreateFooter">
            <gl-button v-if="!isFirstStep" type="button" data-testid="back-btn" @click="back">{{
              __('Back')
            }}</gl-button>
            <gl-button
              v-if="!isLastStep && !isMethodStep"
              type="button"
              variant="confirm"
              data-testid="next-btn"
              :disabled="isNextDisabled"
              @click="next"
              >{{ __('Next') }}</gl-button
            >
            <gl-button
              v-if="isLastStep"
              type="button"
              variant="confirm"
              class="js-no-auto-disable"
              data-testid="submit-btn"
              :loading="isSaving"
              @click="onSubmit"
              >{{ $options.i18n.addSaveBtnText }}</gl-button
            >
            <gl-button type="button" data-testid="cancel-btn" @click="navigateOutEditView">{{
              __('Cancel')
            }}</gl-button>
          </template>

          <template v-else>
            <gl-button
              type="button"
              variant="confirm"
              class="js-no-auto-disable"
              data-testid="submit-btn"
              :loading="isSaving"
              @click="onSubmit"
              >{{ $options.i18n.editSaveBtnText }}</gl-button
            >
            <gl-button type="button" data-testid="cancel-btn" @click="navigateOutEditView">{{
              __('Cancel')
            }}</gl-button>
            <gl-tooltip
              v-if="deleteBtnDisabled"
              :target="() => $refs.deleteBtn"
              :title="deleteBtnDisabledTooltip"
            />
            <div ref="deleteBtn" class="gl-ml-auto">
              <gl-button
                type="button"
                variant="danger"
                data-testid="delete-btn"
                :loading="isDeleting"
                :disabled="deleteBtnDisabled"
                @click="onDelete"
                >{{ $options.i18n.deleteButtonText }}</gl-button
              >
            </div>
          </template>
        </div>
      </div>
    </template>

    <delete-modal
      v-if="graphqlId"
      ref="deleteModal"
      :name="originalName"
      @delete="deleteFramework"
    />
  </div>
</template>
