<script>
import { GlLoadingIcon } from '@gitlab/ui';
import projectPoliciesQuery from '../queries/project_policies.query.graphql';
import policyViolationsQuery from '../queries/policy_violations.query.graphql';
import SecurityListItem from '../components/security_list_item.vue';
import PolicyDrawer from '../components/policy_drawer.vue';
import FindingDrawer from '../components/finding_drawer.vue';

const VIOLATIONS_DATA_MAP = {
  ANY_MERGE_REQUEST: 'anyMergeRequest',
  SCAN_FINDING: 'newScanFinding',
};

export default {
  name: 'MergeRequestReportsBlocksPage',
  apollo: {
    policies: {
      query: projectPoliciesQuery,
      variables() {
        return { projectPath: this.projectPath };
      },
      update: (d) => (d.project?.approvalPolicies?.nodes || []).filter((p) => p.enabled),
      context: {
        batchKey: 'PolicyBlockers',
      },
    },
    mergeRequest: {
      query: policyViolationsQuery,
      variables() {
        return { projectPath: this.projectPath, iid: this.iid };
      },
      update: (d) => d.project?.mergeRequest || {},
      context: {
        batchKey: 'PolicyBlockers',
      },
    },
  },
  components: {
    GlLoadingIcon,
    SecurityListItem,
    PolicyDrawer,
    FindingDrawer,
  },
  inject: ['projectPath', 'iid'],
  data() {
    return {
      policies: [],
      mergeRequest: {},
      openPolicy: null,
      selectedFinding: null,
    };
  },
  computed: {
    policyViolations() {
      return this.mergeRequest.policyViolations;
    },
    isLoading() {
      return this.$apollo.queries.policies.loading || this.$apollo.queries.mergeRequest.loading;
    },
    openPolicyName() {
      return this.openPolicy?.name;
    },
  },
  methods: {
    openPolicyDrawer(policyName) {
      this.openPolicy = this.policies.find((p) => p.name === policyName);
    },
    setSelectedFinding(finding) {
      this.selectedFinding = finding;
    },
    getPolicyStatus(name) {
      const policy = this.policyViolations?.policies?.find((p) => p.name === name);

      if (!policy) return 'success';

      return policy.status;
    },
    getFindingsForPolicyForName(name) {
      const policy = this.policyViolations?.policies?.find((p) => p.name === name);

      if (!policy) return [];

      const propertyKey = VIOLATIONS_DATA_MAP[policy.reportType];

      return this.policyViolations[propertyKey];
    },
    getComparisonPipelines(name) {
      const policy = this.policyViolations?.policies?.find((p) => p.name === name);

      if (!policy) return null;

      return this.policyViolations.comparisonPipelines.find(
        (pipeline) => pipeline.reportType === policy.reportType,
      );
    },
    isPolicyActive(policy) {
      return this.openPolicyName === policy.name;
    },
  },
};
</script>

<template>
  <div>
    <gl-loading-icon v-if="isLoading" size="lg" />
    <template v-else>
      <security-list-item
        v-for="(policy, index) in policies"
        :key="index"
        :policy-name="policy.name"
        :active="isPolicyActive(policy)"
        :findings="getFindingsForPolicyForName(policy.name)"
        :status="getPolicyStatus(policy.name)"
        :loading="false"
        :selected-finding="selectedFinding"
        class="gl-mb-3 gl-pb-3"
        :class="{ 'gl-border-b': index !== policies.length - 1 }"
        @open-drawer="openPolicyDrawer"
        @open-finding="setSelectedFinding"
      />
      <policy-drawer
        :open="Boolean(openPolicy)"
        :policy="openPolicy"
        :comparison-pipelines="getComparisonPipelines(openPolicyName)"
        :target-branch="mergeRequest.targetBranch"
        :source-branch="mergeRequest.sourceBranch"
        :pipeline="mergeRequest.headPipeline"
        @close="openPolicy = null"
      />
      <finding-drawer :open="Boolean(selectedFinding)" @close="setSelectedFinding(null)" />
    </template>
  </div>
</template>
