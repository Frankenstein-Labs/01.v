<script>
import { GlAlert, GlBadge, GlButton, GlIcon, GlSprintf } from '@gitlab/ui';
import { parseBoolean } from '~/lib/utils/common_utils';
import { s__ } from '~/locale';
import { projectPath } from '~/lib/utils/path_helpers/project';
import { rootPath } from '~/lib/utils/path_helpers/routes';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import { NEW_POLICY_BUTTON_TEXT } from '../constants';
import CspBanner from './banners/csp_banner.vue';
import DeprecatedCustomScanBanner from './banners/deprecated_custom_scan_banner.vue';
import ExceedingActionsBanner from './banners/exceeding_actions_banner.vue';
import ExceedingScheduledRulesBanner from './banners/exceeding_scheduled_rules_banner.vue';
import InvalidPoliciesBanner from './banners/invalid_policies_banner.vue';
import InvalidPolicyYamlBanner from './banners/invalid_policy_yaml_banner.vue';
import MalwareRolloutBanner from './banners/malware_rollout_banner.vue';
import MissingPolicyYamlBanner from './banners/missing_policy_yaml_banner.vue';
import ProjectModal from './project_modal.vue';

export default {
  name: 'ListHeaderEE',
  BANNER_STORAGE_KEY: 'security_policies_scan_result_name_change',
  components: {
    CspBanner,
    DeprecatedCustomScanBanner,
    ExceedingActionsBanner,
    ExceedingScheduledRulesBanner,
    GlAlert,
    GlBadge,
    GlButton,
    GlIcon,
    GlSprintf,
    InvalidPoliciesBanner,
    InvalidPolicyYamlBanner,
    MalwareRolloutBanner,
    MissingPolicyYamlBanner,
    PageHeading,
    ProjectModal,
  },
  inject: [
    'assignedPolicyProject',
    'designatedAsCsp',
    'disableSecurityPolicyProject',
    'disableScanPolicyUpdate',
    'documentationPath',
    'newPolicyPath',
    'namespaceType',
  ],
  props: {
    hasInvalidPolicies: {
      type: Boolean,
      required: true,
    },
    hasDeprecatedCustomScanPolicies: {
      type: Boolean,
      required: true,
    },
    hasExceedingActionLimitPolicies: {
      type: Boolean,
      required: true,
    },
    hasExceedingScheduledLimitPolicies: {
      type: Boolean,
      required: true,
    },
    showMalwareRolloutBanner: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['update-policy-list'],
  i18n: {
    newPolicyButtonText: NEW_POLICY_BUTTON_TEXT,
  },
  data() {
    return {
      projectIsBeingLinked: false,
      showAlert: false,
      alertVariant: '',
      alertText: '',
      modalVisible: false,
    };
  },
  computed: {
    hasAssignedPolicyProject() {
      return Boolean(this.assignedPolicyProject?.id);
    },
    hasInvalidPolicyYaml() {
      return parseBoolean(this.assignedPolicyProject?.policyYamlHasSyntaxErrors);
    },
    hasMissingPolicyYaml() {
      return parseBoolean(this.assignedPolicyProject?.policyYamlMissing);
    },
    securityPolicyProjectPath() {
      if (this.assignedPolicyProject?.fullPath) {
        return projectPath(this.assignedPolicyProject?.fullPath);
      }

      return rootPath();
    },
    subtitle() {
      if (this.namespaceType === NAMESPACE_TYPES.PROJECT) {
        return s__(
          'SecurityOrchestration|Enforce %{linkStart}security policies%{linkEnd} for this project.',
        );
      }

      if (this.designatedAsCsp) {
        return s__(
          'SecurityOrchestration|Enforce %{linkStart}security policies%{linkEnd} for all groups within your instance.',
        );
      }

      return s__(
        'SecurityOrchestration|Enforce %{linkStart}security policies%{linkEnd} for all projects in this group.',
      );
    },
  },
  methods: {
    updateAlertText({ text, variant, hasPolicyProject }) {
      this.projectIsBeingLinked = false;

      if (text) {
        this.showAlert = true;
        this.alertVariant = variant;
        this.alertText = text;
      }
      this.$emit('update-policy-list', { hasPolicyProject, shouldUpdatePolicyList: true });
    },
    isUpdatingProject() {
      this.projectIsBeingLinked = true;
      this.showAlert = false;
      this.alertVariant = '';
      this.alertText = '';
    },
    dismissAlert() {
      this.showAlert = false;
    },
    showNewPolicyModal() {
      this.modalVisible = true;
    },
  },
};
</script>
<template>
  <div>
    <gl-alert
      v-if="showAlert"
      class="gl-mt-3"
      :dismissible="true"
      :variant="alertVariant"
      data-testid="error-alert"
      @dismiss="dismissAlert"
    >
      {{ alertText }}
    </gl-alert>

    <page-heading>
      <template #heading>
        <div class="gl-flex gl-items-center">
          <span>{{ s__('SecurityOrchestration|Policies') }}</span>
          <gl-badge v-if="designatedAsCsp" class="gl-ml-2" data-testid="csp-badge">
            {{ s__('SecurityOrchestration|Compliance and security policy group') }}
          </gl-badge>
        </div>
      </template>
      <template #description>
        <gl-sprintf :message="subtitle">
          <template #link="{ content }">
            <gl-button
              class="!gl-pb-1"
              variant="link"
              :href="documentationPath"
              target="_blank"
              data-testid="more-information-link"
            >
              {{ content }}
            </gl-button>
          </template>
        </gl-sprintf>
      </template>

      <template #actions>
        <gl-button
          v-if="!disableSecurityPolicyProject"
          data-testid="edit-project-policy-button"
          :loading="projectIsBeingLinked"
          @click="showNewPolicyModal"
        >
          {{ s__('SecurityOrchestration|Edit policy project') }}
        </gl-button>
        <gl-button
          v-else-if="hasAssignedPolicyProject"
          data-testid="view-project-policy-button"
          target="_blank"
          :href="securityPolicyProjectPath"
        >
          <gl-icon name="external-link" />
          {{ s__('SecurityOrchestration|View policy project') }}
        </gl-button>
        <gl-button
          v-if="!disableScanPolicyUpdate"
          data-testid="new-policy-button"
          variant="confirm"
          :href="newPolicyPath"
        >
          {{ $options.i18n.newPolicyButtonText }}
        </gl-button>
      </template>
    </page-heading>

    <project-modal
      :visible="modalVisible"
      @close="modalVisible = false"
      @project-updated="updateAlertText"
      @updating-project="isUpdatingProject"
    />

    <malware-rollout-banner v-if="showMalwareRolloutBanner" class="gl-mb-6 gl-mt-3" />

    <csp-banner v-if="designatedAsCsp" class="gl-mb-6 gl-mt-3" />

    <deprecated-custom-scan-banner v-if="hasDeprecatedCustomScanPolicies" class="gl-mb-6 gl-mt-3" />

    <invalid-policies-banner v-if="hasInvalidPolicies" />

    <missing-policy-yaml-banner v-if="hasMissingPolicyYaml" />

    <invalid-policy-yaml-banner v-if="hasInvalidPolicyYaml" />

    <exceeding-actions-banner v-if="hasExceedingActionLimitPolicies" class="gl-mb-6" />

    <exceeding-scheduled-rules-banner v-if="hasExceedingScheduledLimitPolicies" class="gl-mb-6" />
  </div>
</template>
