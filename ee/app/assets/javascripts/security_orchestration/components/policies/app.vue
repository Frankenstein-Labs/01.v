<script>
import { groupBy } from 'lodash-es';
import { s__ } from '~/locale';
import getSppLinkedProjectsGroups from 'ee/security_orchestration/graphql/queries/get_spp_linked_projects_groups.graphql';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import { createAlert } from '~/alert';
import { getParameterByName } from '~/lib/utils/url_utility';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import {
  exceedsActionLimit,
  exceedsScheduleRulesLimit,
  extractSourceParameter,
  extractTypeParameter,
  flattenPolicies,
} from 'ee/security_orchestration/components/policies/utils';
import {
  DEPENDENCY_FIREWALL_POLICY_TYPE,
  SCAN_EXECUTION_POLICY_TYPE,
  APPROVAL_POLICY_TYPE,
  PIPELINE_EXECUTION_POLICY_TYPE,
  PIPELINE_EXECUTION_SCHEDULE_POLICY_TYPE,
  VULNERABILITY_MANAGEMENT_POLICY_TYPE,
} from 'ee/security_orchestration/components/constants';
import projectSecurityPoliciesQuery from 'ee/security_orchestration/graphql/queries/project_security_policies.query.graphql';
import groupSecurityPoliciesQuery from 'ee/security_orchestration/graphql/queries/group_security_policies.query.graphql';
import { isGroup } from '../utils';
import ListHeader from './list_header.vue';
import ListComponent from './list_component.vue';
import {
  DEPRECATED_CUSTOM_SCAN_PROPERTY,
  POLICY_TYPE_FILTER_OPTIONS,
  ACTION_LIMIT,
  POLICIES_PER_PAGE,
  PIPELINE_TYPE_COMBINED_TYPE_MAP,
} from './constants';

const NAMESPACE_QUERY_DICT_COMBINED_LIST = {
  [NAMESPACE_TYPES.PROJECT]: projectSecurityPoliciesQuery,
  [NAMESPACE_TYPES.GROUP]: groupSecurityPoliciesQuery,
};

const createPolicyFetchError = ({ gqlError, networkError }) => {
  const error =
    gqlError?.message ||
    networkError?.message ||
    s__('SecurityOrchestration|Something went wrong, unable to fetch policies');
  createAlert({
    message: error,
  });
};

export default {
  name: 'PoliciesApp',
  components: {
    ListHeader,
    ListComponent,
  },
  mixins: [glFeatureFlagMixin()],
  inject: [
    'assignedPolicyProject',
    'namespacePath',
    'namespaceType',
    'maxScanExecutionPolicyActions',
    'maxScanExecutionPolicySchedules',
  ],
  apollo: {
    linkedSppItems: {
      query: getSppLinkedProjectsGroups,
      variables() {
        return {
          fullPath: this.namespacePath,
        };
      },
      update(data) {
        const {
          securityPolicyProjectLinkedProjects: { nodes: linkedProjects = [] } = {},
          securityPolicyProjectLinkedGroups: { nodes: linkedGroups = [] } = {},
        } = data?.project || {};

        return [...linkedProjects, ...linkedGroups];
      },
      skip() {
        return isGroup(this.namespaceType);
      },
      error: createPolicyFetchError,
    },
    securityPolicies: {
      query() {
        return NAMESPACE_QUERY_DICT_COMBINED_LIST[this.namespaceType];
      },
      variables() {
        return {
          ...this.queryVariables,
          ...(this.type ? { type: this.type } : {}),
        };
      },
      result({ data }) {
        this.pageInfo = data?.namespace?.securityPolicies?.pageInfo ?? {};
      },
      update(data) {
        return data?.namespace?.securityPolicies?.nodes ?? [];
      },
      error: createPolicyFetchError,
    },
  },
  data() {
    const selectedPolicySource = extractSourceParameter(getParameterByName('source'));
    const selectedPolicyType = extractTypeParameter(getParameterByName('type'));
    const type = PIPELINE_TYPE_COMBINED_TYPE_MAP[selectedPolicyType] || '';

    return {
      hasPolicyProject: Boolean(this.assignedPolicyProject?.id),
      selectedPolicySource,
      selectedPolicyType,
      shouldUpdatePolicyList: false,
      linkedSppItems: [],
      pageInfo: {},
      securityPolicies: [],
      type,
    };
  },
  computed: {
    queryVariables() {
      return {
        fullPath: this.namespacePath,
        relationship: this.selectedPolicySource,
        includeAttributeScopes: Boolean(this.glFeatures.securityAttributesPolicyScope),
      };
    },
    hasExceedingScheduledLimitPolicies() {
      return this.policiesByType[POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value]?.some(
        ({ yaml }) =>
          exceedsScheduleRulesLimit({
            policyType: POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.text,
            yaml,
            maxScanExecutionPolicySchedules: this.maxScanExecutionPolicySchedules,
          }),
      );
    },
    hasDeprecatedCustomScanPolicies() {
      return this.policiesByType[POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value]?.some((policy) =>
        policy.deprecatedProperties.includes(DEPRECATED_CUSTOM_SCAN_PROPERTY),
      );
    },
    hasExceedingActionLimitPolicies() {
      return this.policiesByType[POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value]?.some(
        ({ yaml }) =>
          exceedsActionLimit({
            policyType: POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.text,
            yaml,
            maxScanExecutionPolicyActions: ACTION_LIMIT,
          }),
      );
    },
    hasInvalidPolicies() {
      return this.policiesByType[POLICY_TYPE_FILTER_OPTIONS.APPROVAL.value]?.some((policy) =>
        policy.deprecatedProperties?.some((prop) => prop !== 'scan_result_policy'),
      );
    },
    hasDependencyFirewallEnabled() {
      return this.glFeatures.dependencyFirewallPhase1;
    },
    showMalwareRolloutBanner() {
      return Boolean(this.glFeatures.securityPoliciesMalwareAttribute);
    },
    flattenedPolicies() {
      return flattenPolicies(this.securityPolicies);
    },
    policiesByType() {
      const groupedPolicies = groupBy(this.flattenedPolicies, 'type');

      const policiesByType = {
        [POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value]:
          groupedPolicies[SCAN_EXECUTION_POLICY_TYPE] || [],
        [POLICY_TYPE_FILTER_OPTIONS.APPROVAL.value]: groupedPolicies[APPROVAL_POLICY_TYPE] || [],
        [POLICY_TYPE_FILTER_OPTIONS.PIPELINE_EXECUTION.value]:
          groupedPolicies[PIPELINE_EXECUTION_POLICY_TYPE] || [],
        [POLICY_TYPE_FILTER_OPTIONS.PIPELINE_EXECUTION_SCHEDULE.value]:
          groupedPolicies[PIPELINE_EXECUTION_SCHEDULE_POLICY_TYPE] || [],
        [POLICY_TYPE_FILTER_OPTIONS.VULNERABILITY_MANAGEMENT.value]:
          groupedPolicies[VULNERABILITY_MANAGEMENT_POLICY_TYPE] || [],
      };

      if (this.hasDependencyFirewallEnabled) {
        policiesByType[POLICY_TYPE_FILTER_OPTIONS.DEPENDENCY_FIREWALL.value] =
          groupedPolicies[DEPENDENCY_FIREWALL_POLICY_TYPE] || [];
      }

      return policiesByType;
    },
    isLoadingPolicies() {
      return this.$apollo.queries.securityPolicies.loading;
    },
  },
  methods: {
    handleClearedSelected() {
      this.shouldUpdatePolicyList = false;
    },
    handleUpdatePolicyList({ hasPolicyProject, shouldUpdatePolicyList = false }) {
      if (hasPolicyProject !== undefined) {
        this.hasPolicyProject = hasPolicyProject;
      }

      this.shouldUpdatePolicyList = shouldUpdatePolicyList;

      this.$apollo.queries.securityPolicies.refetch();
    },
    handleUpdatePolicySource(value) {
      this.selectedPolicySource = value;
    },
    async handleUpdatePolicyType(value) {
      this.type = PIPELINE_TYPE_COMBINED_TYPE_MAP[value] || '';
      this.selectedPolicyType = value;
    },
    async handlePageChange(isNext = false) {
      const pageVariables = isNext
        ? { after: this.pageInfo.endCursor }
        : { before: this.pageInfo.startCursor, first: null, last: POLICIES_PER_PAGE };

      try {
        const { data } = await this.$apollo.queries.securityPolicies.fetchMore({
          variables: {
            ...this.queryVariables,
            ...pageVariables,
          },
        });
        const { pageInfo = {}, nodes = [] } = data?.namespace?.securityPolicies ?? {};

        this.pageInfo = pageInfo;
        this.securityPolicies = nodes;
      } catch (e) {
        createPolicyFetchError(e);
      }
    },
  },
};
</script>
<template>
  <div>
    <list-header
      :has-exceeding-scheduled-limit-policies="hasExceedingScheduledLimitPolicies"
      :has-exceeding-action-limit-policies="hasExceedingActionLimitPolicies"
      :has-invalid-policies="hasInvalidPolicies"
      :has-deprecated-custom-scan-policies="hasDeprecatedCustomScanPolicies"
      :show-malware-rollout-banner="showMalwareRolloutBanner"
      @update-policy-list="handleUpdatePolicyList"
    />
    <list-component
      :has-policy-project="hasPolicyProject"
      :should-update-policy-list="shouldUpdatePolicyList"
      :is-loading-policies="isLoadingPolicies"
      :selected-policy-source="selectedPolicySource"
      :selected-policy-type="selectedPolicyType"
      :linked-spp-items="linkedSppItems"
      :page-info="pageInfo"
      :policies-by-type="policiesByType"
      @cleared-selected="handleClearedSelected"
      @next-page="handlePageChange(true)"
      @prev-page="handlePageChange(false)"
      @update-policy-source="handleUpdatePolicySource"
      @update-policy-type="handleUpdatePolicyType"
    />
  </div>
</template>
