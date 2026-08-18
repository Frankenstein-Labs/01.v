<script>
import { defineAsyncComponent } from 'vue';
import {
  GlButton,
  GlDrawer,
  GlLink,
  GlPopover,
  GlSprintf,
  GlTabs,
  GlTab,
  GlTruncate,
} from '@gitlab/ui';
import { s__ } from '~/locale';
import { getSecurityPolicyListUrl } from '~/editor/extensions/source_editor_security_policy_schema_ext';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import { getContentWrapperHeight } from '~/lib/utils/dom_utils';
import { policyToYaml } from 'ee/security_orchestration/components/policy_editor/utils';
import projectSecurityPolicyDetailsQuery from 'ee/security_orchestration/graphql/queries/project_security_policy_details.query.graphql';
import groupSecurityPolicyDetailsQuery from 'ee/security_orchestration/graphql/queries/group_security_policy_details.query.graphql';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';
import { removeUnnecessaryDashes } from '../../utils';
import {
  APPROVAL_POLICY_TYPE,
  PIPELINE_EXECUTION_POLICY_TYPE,
  PIPELINE_EXECUTION_SCHEDULE_POLICY_TYPE,
  POLICIES_LIST_CONTAINER_CLASS,
  POLICY_TYPE_COMPONENT_OPTIONS,
} from '../constants';
import { POLICY_RELATIONSHIP_DIRECT, POLICY_RELATIONSHIP_INHERITED } from '../policies/constants';
import { extractPolicyContent, isPolicyInherited, policyHasNamespace, isGroup } from '../utils';
import PipelineExecutionDrawer from './pipeline_execution/details_drawer.vue';
import ScanExecutionDrawer from './scan_execution/details_drawer.vue';
import ScanResultDrawer from './scan_result/details_drawer.vue';
import VulnerabilityManagementDrawer from './vulnerability_management/details_drawer.vue';
import DependencyFirewallDrawer from './dependency_firewall/details_drawer.vue';
import TestRunsTab from './pipeline_execution/test_runs_tab.vue';

const policyComponent = {
  [POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.value]: ScanExecutionDrawer,
  [POLICY_TYPE_COMPONENT_OPTIONS.approval.value]: ScanResultDrawer,
  [POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecution.value]: PipelineExecutionDrawer,
  [POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecutionSchedule.value]: PipelineExecutionDrawer,
  [POLICY_TYPE_COMPONENT_OPTIONS.vulnerabilityManagement.value]: VulnerabilityManagementDrawer,
  [POLICY_TYPE_COMPONENT_OPTIONS.dependencyFirewall.value]: DependencyFirewallDrawer,
};

export default {
  name: 'DrawerWrapper',
  components: {
    GlButton,
    GlDrawer,
    GlLink,
    GlPopover,
    GlSprintf,
    GlTab,
    GlTabs,
    GlTruncate,
    YamlEditor: defineAsyncComponent(
      () => import(/* webpackChunkName: 'policy_yaml_editor' */ '../yaml_editor.vue'),
    ),
    PipelineExecutionDrawer,
    ScanExecutionDrawer,
    ScanResultDrawer,
    VulnerabilityManagementDrawer,
    DependencyFirewallDrawer,
    TestRunsTab,
  },
  mixins: [glListenersMixin],
  inject: ['namespacePath', 'namespaceType'],
  props: {
    containerClass: {
      type: String,
      required: false,
      default: POLICIES_LIST_CONTAINER_CLASS,
    },
    policy: {
      type: Object,
      required: false,
      default: null,
    },
    policyType: {
      type: String,
      required: false,
      default: '',
    },
    disableScanPolicyUpdate: {
      type: Boolean,
      required: false,
      default: false,
    },
    activeTestRun: {
      type: Object,
      required: false,
      default: null,
    },
  },
  emits: ['test-run-created'],
  apollo: {
    policyDetails: {
      query() {
        return this.isGroup ? groupSecurityPolicyDetailsQuery : projectSecurityPolicyDetailsQuery;
      },
      variables() {
        return {
          fullPath: this.namespacePath,
          type: this.policyTypeEnum,
          relationship: this.policyRelationship,
        };
      },
      update(data) {
        const policies = data?.namespace?.securityPolicies?.nodes || [];
        // Prefer id match (available since 18.11.0); fall back to name for older instances.
        // Note: this query fetches up to 50 policies per type — if a namespace exceeds
        // that limit the selected policy may not be found and the drawer falls back to
        // list-query data (no approvers / blob path shown).
        return (
          policies.find(({ id, name }) =>
            this.policy.id ? id === this.policy.id : name === this.policy.name,
          ) || null
        );
      },
      skip() {
        return !this.policy || !this.shouldFetchDetails || !this.policyTypeEnum;
      },
      error() {
        this.policyDetails = null;
      },
    },
  },
  data() {
    return {
      policyDetails: null,
    };
  },
  computed: {
    isGroup() {
      return isGroup(this.namespaceType);
    },
    policyTypeEnum() {
      return this.policy?.type?.toUpperCase() || null;
    },
    policyRelationship() {
      return this.isPolicyInherited ? POLICY_RELATIONSHIP_INHERITED : POLICY_RELATIONSHIP_DIRECT;
    },
    shouldFetchDetails() {
      // Only fetch additional details for policy types that need them
      return this.needsActionApprovers || this.needsPolicyBlobFilePath;
    },
    needsActionApprovers() {
      return this.policy?.type === APPROVAL_POLICY_TYPE;
    },
    needsPolicyBlobFilePath() {
      return (
        this.policy?.type === PIPELINE_EXECUTION_POLICY_TYPE ||
        this.policy?.type === PIPELINE_EXECUTION_SCHEDULE_POLICY_TYPE
      );
    },
    isLoadingDetails() {
      return this.$apollo?.queries?.policyDetails?.loading && this.shouldFetchDetails;
    },
    /**
     * Merged policy with additional details from the drawer query
     */
    enrichedPolicy() {
      if (!this.policy) return null;
      if (!this.policyDetails) return this.policy;

      const { policyScope, policyAttributes } = this.policyDetails;

      // Merge so attribute-scope fields loaded by the list query survive — the drawer
      // details query does not redeclare them (see policy_scope_drawer.fragment.graphql).
      // Drawer-query fields (richer compliance frameworks, full project lists) still win.
      const details = {
        policyScope: { ...this.policy.policyScope, ...policyScope },
      };

      if (this.needsActionApprovers) {
        details.actionApprovers = policyAttributes?.actionApprovers;
      }

      if (this.needsPolicyBlobFilePath) {
        details.policyBlobFilePath = policyAttributes?.policyBlobFilePath;
      }

      return { ...this.policy, ...details };
    },
    isPolicyInherited() {
      return isPolicyInherited(this.policy?.source);
    },
    policyHasNamespace() {
      return policyHasNamespace(this.policy?.source);
    },
    policyComponent() {
      return policyComponent[this.policyType] || null;
    },
    policyYaml() {
      const policyOption = Object.values(POLICY_TYPE_COMPONENT_OPTIONS).find(
        ({ value }) => value === this.policyType,
      );
      const type = policyOption?.urlParameter || '';

      return policyToYaml(
        extractPolicyContent({
          manifest: removeUnnecessaryDashes(this.policy.yaml),
          type,
        }),
        type,
      );
    },
    sourcePolicyListUrl() {
      return getSecurityPolicyListUrl({ namespacePath: this.policy.source.namespace.fullPath });
    },
    isPipelineExecutionSchedulePolicy() {
      return this.policyType === POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecutionSchedule.value;
    },
  },
  watch: {
    policy(newPolicy) {
      if (newPolicy) {
        this.policyDetails = null;
      }
    },
  },
  methods: {
    getDrawerHeaderHeight() {
      return getContentWrapperHeight(this.containerClass);
    },
  },
  DRAWER_Z_INDEX,
  i18n: {
    editButtonPopoverMessage: s__(
      'SecurityOrchestration|This policy is inherited from %{linkStart}namespace%{linkEnd} and must be edited there',
    ),
    tabDetails: s__('SecurityOrchestration|Details'),
    tabTestRuns: s__('SecurityOrchestration|Test runs'),
    tabYaml: s__('SecurityOrchestration|YAML'),
  },
};
</script>

<template>
  <gl-drawer
    :z-index="$options.DRAWER_Z_INDEX"
    :header-height="getDrawerHeaderHeight()"
    v-bind="$attrs"
    v-on="glListeners()"
  >
    <template v-if="policy" #title>
      <gl-truncate
        class="gl-max-w-34 gl-text-size-h2 gl-font-bold gl-leading-24"
        :text="policy.name"
        with-tooltip
      />
    </template>
    <template v-if="policy" #header>
      <span v-if="!disableScanPolicyUpdate" ref="editButton" class="gl-inline-block">
        <gl-button
          class="gl-mt-5"
          data-testid="edit-button"
          category="primary"
          variant="confirm"
          :href="policy.editPath"
          :disabled="isPolicyInherited"
          >{{ s__('SecurityOrchestration|Edit policy') }}</gl-button
        >
      </span>
      <gl-popover
        v-if="isPolicyInherited && policyHasNamespace"
        triggers="hover"
        :target="() => $refs.editButton"
        data-testid="edit-button-popover"
        placement="right"
      >
        <gl-sprintf :message="$options.i18n.editButtonPopoverMessage">
          <template #link>
            <gl-link :href="sourcePolicyListUrl">
              {{ policy.source.namespace.name }}
            </gl-link>
          </template>
        </gl-sprintf>
      </gl-popover>
    </template>
    <gl-tabs v-if="policy" class="!gl-p-0" justified content-class="gl-py-0" lazy>
      <gl-tab :title="$options.i18n.tabDetails" class="gl-ml-6 gl-mr-3 gl-mt-5">
        <component
          :is="policyComponent"
          v-if="policyComponent"
          :policy="enrichedPolicy"
          :loading-details="isLoadingDetails"
        />
        <div v-else>
          <h5>{{ s__('SecurityOrchestration|Policy definition') }}</h5>
          <p>
            {{
              s__("SecurityOrchestration|Define this policy's location, conditions and actions.")
            }}
          </p>
          <yaml-editor :value="policyYaml" data-testid="policy-yaml-editor-default-component" />
        </div>
      </gl-tab>
      <gl-tab v-if="policyComponent" :title="$options.i18n.tabYaml">
        <yaml-editor
          class="gl-h-screen"
          :value="policyYaml"
          data-testid="policy-yaml-editor-tab-content"
        />
      </gl-tab>
      <gl-tab
        v-if="isPipelineExecutionSchedulePolicy"
        :title="$options.i18n.tabTestRuns"
        data-testid="policy-test-runs-tab"
      >
        <test-runs-tab
          :policy="policy"
          :active-test-run="activeTestRun"
          @test-run-created="$emit('test-run-created', $event)"
        />
      </gl-tab>
    </gl-tabs>
  </gl-drawer>
</template>
