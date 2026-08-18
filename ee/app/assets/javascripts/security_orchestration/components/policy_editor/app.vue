<script>
import { s__ } from '~/locale';
import { getParameterByName } from '~/lib/utils/url_utility';
import {
  POLICY_TYPE_COMPONENT_OPTIONS,
  VULNERABILITY_MANAGEMENT_POLICY_TYPE,
} from 'ee/security_orchestration/components/constants';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import AdvancedEditorToggle from 'ee/security_orchestration/components/policy_editor/advanced_editor_toggle.vue';
import AutoDismissedActionBanner from 'ee/security_orchestration/components/policy_editor/auto_dismissed_action_banner.vue';
import EditorWrapper from './editor_wrapper.vue';
import PolicyTypeSelector from './policy_type_selector.vue';

export default {
  name: 'PolicyEditorApp',
  components: {
    AdvancedEditorToggle,
    AutoDismissedActionBanner,
    EditorWrapper,
    PolicyTypeSelector,
    PageHeading,
  },
  inject: {
    existingPolicy: { default: null },
  },
  data() {
    return {
      selectedPolicy: this.policyFromUrl(),
      hasPolicyType: false,
    };
  },
  computed: {
    isVulnerabilityType() {
      return this.selectedPolicy?.urlParameter === VULNERABILITY_MANAGEMENT_POLICY_TYPE;
    },
    title() {
      const titleType = this.existingPolicy
        ? this.$options.i18n.editTitles
        : this.$options.i18n.titles;

      return titleType[this.selectedPolicy?.value] || titleType.default;
    },
  },
  created() {
    this.policyFromUrl(getParameterByName('type'));
  },
  methods: {
    policyFromUrl() {
      const policyType = getParameterByName('type');
      this.hasPolicyType = Boolean(policyType);

      return Object.values(POLICY_TYPE_COMPONENT_OPTIONS).find(
        ({ urlParameter }) => urlParameter === policyType,
      );
    },
  },
  i18n: {
    titles: {
      [POLICY_TYPE_COMPONENT_OPTIONS.approval.value]: s__(
        'SecurityOrchestration|New merge request approval policy',
      ),
      [POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.value]: s__(
        'SecurityOrchestration|New scan execution policy',
      ),
      [POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecution.value]: s__(
        'SecurityOrchestration|New pipeline execution policy',
      ),
      [POLICY_TYPE_COMPONENT_OPTIONS.vulnerabilityManagement.value]: s__(
        'SecurityOrchestration|New vulnerability management policy',
      ),
      [POLICY_TYPE_COMPONENT_OPTIONS.dependencyFirewall.value]: s__(
        'SecurityOrchestration|New dependency firewall policy',
      ),
      default: s__('SecurityOrchestration|New policy'),
    },
    editTitles: {
      [POLICY_TYPE_COMPONENT_OPTIONS.approval.value]: s__(
        'SecurityOrchestration|Edit merge request approval policy',
      ),
      [POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.value]: s__(
        'SecurityOrchestration|Edit scan execution policy',
      ),
      [POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecution.value]: s__(
        'SecurityOrchestration|Edit pipeline execution policy',
      ),
      [POLICY_TYPE_COMPONENT_OPTIONS.vulnerabilityManagement.value]: s__(
        'SecurityOrchestration|Edit vulnerability management policy',
      ),
      [POLICY_TYPE_COMPONENT_OPTIONS.dependencyFirewall.value]: s__(
        'SecurityOrchestration|Edit dependency firewall policy',
      ),
      default: s__('SecurityOrchestration|Edit policy'),
    },
  },
};
</script>
<template>
  <div>
    <auto-dismissed-action-banner v-if="isVulnerabilityType" class="gl-mt-4" />

    <page-heading :heading="title">
      <template #actions>
        <advanced-editor-toggle v-if="hasPolicyType" />
      </template>
    </page-heading>
    <policy-type-selector v-if="!selectedPolicy" />
    <editor-wrapper v-else :selected-policy="selectedPolicy" />
  </div>
</template>
