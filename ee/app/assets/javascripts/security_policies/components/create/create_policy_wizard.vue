<script>
import {
  GlAlert,
  GlButton,
  GlCollapsibleListbox,
  GlFormInput,
  GlFormTextarea,
  GlIcon,
  GlLoadingIcon,
  GlModal,
  GlTooltipDirective,
} from '@gitlab/ui';
import { safeLoad } from 'js-yaml';
import { s__ } from '~/locale';
import getSecurityPolicyProjectSub from 'ee/security_orchestration/graphql/queries/security_policy_project_created.subscription.graphql';
import {
  goToPolicyMR,
  assignSecurityPolicyProjectAsync,
} from 'ee/security_orchestration/components/policy_editor/utils';
import { SECURITY_POLICY_ACTIONS } from 'ee/security_orchestration/components/policy_editor/constants';
import { WIZARD_STEPS } from '../../constants';
import { ACTION_TYPES } from '../../constants/action_types';
import { RULE_TYPES } from '../../constants/rule_types';
import { TRIGGER_TYPES } from '../../constants/trigger_types';
import { buildPolicyYaml } from './policy_serializer';
import BuildPolicyStep from './steps/build_policy_step.vue';
import ScopeStep from './steps/scope_step.vue';

const ENFORCEMENT_MODES = [
  { value: 'enforce', text: s__('SecurityOrchestration|Enforce') },
  { value: 'warn', text: s__('SecurityOrchestration|Warn') },
  { value: 'audit', text: s__('SecurityOrchestration|Audit') },
];

const MODE_ICON = {
  enforce: { name: 'dash-circle', class: 'gl-text-danger' },
  warn: { name: 'warning', class: 'gl-text-warning' },
  audit: { name: 'doc-text', class: 'gl-text-info' },
};

const MAX_SUBSCRIPTION_RETRY_COUNT = 5;

function extractConfigs(yamlItems, typeDefs) {
  const configs = {};
  (yamlItems || []).forEach((item) => {
    const itemId = item?.type || item?.scan;
    if (!itemId) return;
    const typeDef = typeDefs.find((t) => t.id === itemId);
    if (!typeDef?.fields) return;
    const config = {};
    if (itemId === 'require_approval') {
      const approvers = [...(item.group_approvers || []), ...(item.user_approvers || [])].join(
        ', ',
      );
      if (approvers) config.approverGroups = approvers;
      if (item.approvals_required != null) config.approvalCount = String(item.approvals_required);
      if (item.request_message) config.requestMessage = item.request_message;
    }
    typeDef.fields.forEach((field) => {
      if (field.key in item && !(field.key in config)) config[field.key] = item[field.key];
    });
    if (Object.keys(config).length) configs[itemId] = config;
  });
  return configs;
}

function parsePolicyYaml(initialPolicy) {
  const empty = {
    name: '',
    description: '',
    policyData: {
      triggers: [],
      rules: [],
      actions: [],
      scope: 'all',
      triggerConfigs: {},
      ruleConfigs: {},
      actionConfigs: {},
    },
  };
  if (!initialPolicy?.yaml) return { ...empty, name: initialPolicy?.name || '' };
  try {
    const yaml = safeLoad(initialPolicy.yaml);
    if (!yaml || typeof yaml !== 'object') return empty;
    return {
      name: yaml.name || initialPolicy.name || '',
      description: yaml.description || '',
      policyData: {
        triggers: (yaml.triggers || []).map((t) => t.type).filter(Boolean),
        rules: (yaml.rules || []).map((r) => r.type).filter(Boolean),
        actions: (yaml.actions || []).map((a) => a.type || a.scan).filter(Boolean),
        scope: yaml.scope || 'all',
        triggerConfigs: extractConfigs(yaml.triggers, TRIGGER_TYPES),
        ruleConfigs: extractConfigs(yaml.rules, RULE_TYPES),
        actionConfigs: extractConfigs(yaml.actions, ACTION_TYPES),
      },
    };
  } catch {
    return empty;
  }
}

export default {
  name: 'CreatePolicyWizard',
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  components: {
    GlAlert,
    GlButton,
    GlCollapsibleListbox,
    GlFormInput,
    GlFormTextarea,
    GlIcon,
    GlLoadingIcon,
    GlModal,
    BuildPolicyStep,
    ScopeStep,
  },
  inject: ['assignedPolicyProject', 'namespacePath'],
  props: {
    initialPolicy: {
      type: Object,
      required: false,
      default: null,
    },
  },
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
          if (errors?.length) {
            this.saveError = errors.join('\n');
            this.isSaving = false;
            return;
          }
          if (project) {
            this.resolvedPolicyProject = {
              ...project,
              branch: project?.branch?.rootRef,
            };
          }
        },
        skip() {
          return this.subscriptionErrorCount > MAX_SUBSCRIPTION_RETRY_COUNT;
        },
        error(e) {
          this.saveError = e.message;
          this.isSaving = false;
          this.subscriptionErrorCount += 1;
        },
      },
    },
  },
  ENFORCEMENT_MODES,
  MODE_ICON,
  i18n: {
    unsavedTitle: s__('SecurityOrchestration|You have unsaved changes'),
    unsavedBody: s__(
      'SecurityOrchestration|Your policy has unsaved changes. Save as a draft to come back to it later, or discard to leave without saving.',
    ),
  },
  emits: ['cancel', 'submit'],
  data() {
    const parsed = parsePolicyYaml(this.initialPolicy);
    return {
      currentStep: 1,
      policyName: parsed.name,
      policyDescription: parsed.description,
      showDescriptionPanel: false,
      enforcementMode: 'enforce',
      wizardSteps: WIZARD_STEPS,
      showUnsavedModal: false,
      isSaving: false,
      saveStarted: false,
      saveError: '',
      subscriptionErrorCount: 0,
      resolvedPolicyProject: this.assignedPolicyProject,
      policyData: parsed.policyData,
    };
  },
  computed: {
    modeIcon() {
      return MODE_ICON[this.enforcementMode] || MODE_ICON.enforce;
    },
    modeVariant() {
      const variants = { enforce: 'danger', warn: 'warning', audit: 'info' };
      return variants[this.enforcementMode] || 'danger';
    },
    nextLabel() {
      if (this.currentStep === 2) return s__('SecurityOrchestration|Enable policy');
      return s__('SecurityOrchestration|Select scope →');
    },
    modalActionPrimary() {
      return {
        text: s__('SecurityOrchestration|Save as draft'),
        attributes: { variant: 'confirm' },
      };
    },
    modalActionCancel() {
      return { text: s__('SecurityOrchestration|Discard changes') };
    },
    isDirty() {
      return (
        this.policyName !== '' ||
        this.policyData.rules.length > 0 ||
        this.policyData.actions.length > 0
      );
    },
    effectivePolicyProject() {
      return this.resolvedPolicyProject || this.assignedPolicyProject;
    },
  },
  watch: {
    resolvedPolicyProject(project) {
      if (project?.fullPath && this.isSaving) {
        this.savePolicyToProject(project);
      }
    },
  },
  methods: {
    async next() {
      if (this.currentStep < 2) {
        this.currentStep += 1;
      } else {
        await this.enablePolicy();
      }
    },
    back() {
      if (this.currentStep > 1) {
        this.currentStep -= 1;
      }
    },
    requestCancel() {
      if (this.isDirty) {
        this.showUnsavedModal = true;
      } else {
        this.$emit('cancel');
      }
    },
    saveAsDraft() {
      this.$emit('cancel');
    },
    confirmDiscard() {
      this.showUnsavedModal = false;
      this.$emit('cancel');
    },
    updatePolicyData(data) {
      this.policyData = { ...this.policyData, ...data };
    },
    async enablePolicy() {
      this.saveError = '';
      this.isSaving = true;

      try {
        if (!this.effectivePolicyProject?.fullPath) {
          await assignSecurityPolicyProjectAsync(this.namespacePath);
          // Subscription watcher will call savePolicyToProject once the project is ready
        } else {
          await this.savePolicyToProject(this.effectivePolicyProject);
        }
      } catch (e) {
        this.saveError = e.message;
        this.isSaving = false;
      }
    },
    async savePolicyToProject(policyProject) {
      if (this.saveStarted) return;
      this.saveStarted = true;

      try {
        await goToPolicyMR({
          action: SECURITY_POLICY_ACTIONS.APPEND,
          assignedPolicyProject: policyProject,
          name: this.policyName,
          namespacePath: this.namespacePath,
          yamlEditorValue: this.buildPolicyYaml(),
        });
      } catch (e) {
        this.saveError = e.message;
        this.isSaving = false;
      } finally {
        this.saveStarted = false;
      }
    },
    buildPolicyYaml() {
      return buildPolicyYaml({
        policyName: this.policyName,
        policyDescription: this.policyDescription,
        scope: this.policyData.scope,
        triggers: this.policyData.triggers,
        rules: this.policyData.rules,
        actions: this.policyData.actions,
        triggerConfigs: this.policyData.triggerConfigs,
        ruleConfigs: this.policyData.ruleConfigs,
        actionConfigs: this.policyData.actionConfigs,
      });
    },
    stepClass(stepId) {
      if (stepId < this.currentStep) {
        return 'gl-flex gl-h-6 gl-w-6 gl-items-center gl-justify-center gl-rounded-full gl-bg-success gl-text-inverse gl-text-sm';
      }
      if (stepId === this.currentStep) {
        return 'gl-flex gl-h-6 gl-w-6 gl-items-center gl-justify-center gl-rounded-full gl-bg-brand gl-text-inverse gl-text-sm gl-font-bold';
      }
      return 'gl-flex gl-h-6 gl-w-6 gl-items-center gl-justify-center gl-rounded-full gl-border gl-border-default gl-text-secondary gl-text-sm';
    },
    stepLabelClass(stepId) {
      if (stepId === this.currentStep) return 'gl-font-bold';
      return 'gl-text-secondary';
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-flex-col">
    <div class="gl-border-b gl-flex gl-items-center gl-border-default gl-px-5 gl-py-3">
      <div class="gl-flex gl-flex-1 gl-items-center">
        <div class="gl-relative">
          <gl-form-input
            v-model="policyName"
            :placeholder="s__('SecurityOrchestration|Untitled policy')"
            class="gl-w-32 gl-border-0 gl-bg-transparent gl-text-lg gl-font-bold gl-shadow-none focus-visible:gl-outline-none"
            @focus="showDescriptionPanel = true"
          />
          <div
            v-if="showDescriptionPanel"
            class="gl-w-72 gl-border gl-absolute gl-left-0 gl-top-full gl-z-200 gl-mt-1 gl-rounded-base gl-border-default gl-bg-default gl-p-3 gl-shadow-md"
          >
            <p class="gl-mb-1 gl-text-xs gl-font-bold gl-uppercase gl-text-secondary">
              {{ s__('SecurityOrchestration|Description') }}
            </p>
            <gl-form-textarea
              v-model="policyDescription"
              :placeholder="s__('SecurityOrchestration|Describe what this policy does…')"
              :rows="2"
              class="gl-text-sm"
              no-resize
            />
            <div class="gl-mt-2 gl-flex gl-justify-end">
              <gl-button size="small" @click="showDescriptionPanel = false">
                {{ s__('SecurityOrchestration|Done') }}
              </gl-button>
            </div>
          </div>
        </div>
      </div>

      <div class="gl-flex gl-items-center gl-justify-center gl-gap-2">
        <template v-for="(step, index) in wizardSteps">
          <div :key="step.id" class="gl-flex gl-items-center gl-gap-2">
            <div :class="stepClass(step.id)">
              <gl-icon v-if="step.id < currentStep" name="check" :size="12" />
              <span v-else>{{ step.id }}</span>
            </div>
            <span :class="stepLabelClass(step.id)" class="gl-text-sm">{{ step.label }}</span>
          </div>
          <div
            v-if="index < wizardSteps.length - 1"
            :key="`sep-${step.id}`"
            class="gl-h-px gl-w-8 gl-bg-strong"
          ></div>
        </template>
      </div>

      <div class="gl-flex gl-flex-1 gl-items-center gl-justify-end">
        <gl-collapsible-listbox
          v-model="enforcementMode"
          :items="$options.ENFORCEMENT_MODES"
          :toggle-text="$options.ENFORCEMENT_MODES.find((m) => m.value === enforcementMode).text"
          :variant="modeVariant"
          size="small"
        >
          <template #toggle>
            <gl-button size="small" :variant="modeVariant" category="secondary">
              <gl-icon :name="modeIcon.name" :size="12" :class="modeIcon.class" />
              {{ $options.ENFORCEMENT_MODES.find((m) => m.value === enforcementMode).text }}
              <gl-icon name="chevron-down" :size="12" />
            </gl-button>
          </template>
        </gl-collapsible-listbox>
      </div>
    </div>

    <div class="gl-flex-1 gl-overflow-y-auto">
      <gl-alert
        v-if="saveError"
        variant="danger"
        dismissible
        class="gl-m-4"
        @dismiss="saveError = ''"
      >
        {{ saveError }}
      </gl-alert>

      <build-policy-step
        v-if="currentStep === 1"
        :policy-data="policyData"
        :policy-name="policyName"
        :policy-description="policyDescription"
        :enforcement-mode="enforcementMode"
        :raw-yaml="null"
        @update="updatePolicyData"
      />
      <scope-step
        v-else-if="currentStep === 2"
        :policy-data="policyData"
        :policy-name="policyName"
        :policy-description="policyDescription"
        :enforcement-mode="enforcementMode"
        @update="updatePolicyData"
      />
    </div>

    <div
      class="gl-border-t gl-flex gl-items-center gl-justify-between gl-border-default gl-px-5 gl-py-3"
    >
      <gl-button @click="requestCancel">{{ s__('SecurityOrchestration|Save as draft') }}</gl-button>
      <div class="gl-flex gl-gap-3">
        <gl-button v-if="currentStep > 1" :disabled="isSaving" @click="back">
          ← {{ s__('SecurityOrchestration|Back') }}
        </gl-button>
        <gl-button variant="confirm" :disabled="isSaving" @click="next">
          <gl-loading-icon v-if="isSaving" inline size="sm" class="gl-mr-2" />
          {{ nextLabel }}
        </gl-button>
      </div>
    </div>

    <gl-modal
      v-if="showUnsavedModal"
      modal-id="unsaved-changes-modal"
      :title="$options.i18n.unsavedTitle"
      :action-primary="modalActionPrimary"
      :action-cancel="modalActionCancel"
      visible
      @primary="saveAsDraft"
      @cancel="confirmDiscard"
      @hidden="showUnsavedModal = false"
    >
      <p>{{ $options.i18n.unsavedBody }}</p>
    </gl-modal>
  </div>
</template>
