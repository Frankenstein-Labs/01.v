<script>
import {
  GlBadge,
  GlButton,
  GlTable,
  GlIcon,
  GlSprintf,
  GlLink,
  GlSkeletonLoader,
} from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import DrawerWrapper from 'ee/security_orchestration/components/policy_drawer/drawer_wrapper.vue';
import { getPolicyType } from 'ee/security_orchestration/utils';
import { i18n } from '../constants';
import namespacePoliciesQuery from '../graphql/namespace_policies.query.graphql';
import complianceFrameworkPoliciesQuery from '../graphql/compliance_frameworks_policies.query.graphql';
import EditSection from './edit_section.vue';

export default {
  name: 'PoliciesSection',
  components: {
    DrawerWrapper,
    EditSection,
    GlIcon,
    GlBadge,
    GlButton,
    GlSprintf,
    GlTable,
    GlLink,
    GlSkeletonLoader,
  },
  provide() {
    return {
      namespacePath: this.fullPath,
    };
  },
  inject: ['disableScanPolicyUpdate', 'groupSecurityPoliciesPath'],
  props: {
    fullPath: {
      type: String,
      required: true,
    },
    graphqlId: {
      type: String,
      required: true,
    },
    count: {
      type: Number,
      required: true,
    },
    isInherited: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['policies-count-loaded'],

  data() {
    return {
      selectedPolicy: null,
      rawPolicies: {
        namespaceSecurityPolicies: [],
        compliancePolicies: [],
      },
      policiesLoaded: false,
      namespacePoliciesLoaded: false,
      policiesLoadCursor: {
        namespaceSecurityPoliciesAfter: null,
        compliancePoliciesAfter: null,
      },
    };
  },

  apollo: {
    // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
    namespacePolicies: {
      query: namespacePoliciesQuery,
      variables() {
        return {
          fullPath: this.fullPath,
          after: this.policiesLoadCursor.namespaceSecurityPoliciesAfter,
        };
      },
      update(data) {
        const { nodes, pageInfo } = data.namespace.securityPolicies;
        this.rawPolicies = {
          ...this.rawPolicies,
          namespaceSecurityPolicies: [...this.rawPolicies.namespaceSecurityPolicies, ...nodes],
        };
        this.policiesLoadCursor.namespaceSecurityPoliciesAfter = pageInfo.endCursor;
        this.namespacePoliciesLoaded = !pageInfo.hasNextPage;
      },
      error(error) {
        this.handleError(error);
      },
      skip() {
        return this.namespacePoliciesLoaded;
      },
    },
    // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
    complianceFrameworkPolicies: {
      query: complianceFrameworkPoliciesQuery,
      variables() {
        return {
          fullPath: this.fullPath,
          complianceFramework: this.graphqlId,
          after: this.policiesLoadCursor.compliancePoliciesAfter,
        };
      },
      update(data) {
        const frameworkNode = data?.namespace?.complianceFrameworks?.nodes?.[0];
        if (!frameworkNode?.securityPolicies) return;
        const { nodes, pageInfo } = frameworkNode.securityPolicies;
        this.rawPolicies = {
          ...this.rawPolicies,
          compliancePolicies: [...this.rawPolicies.compliancePolicies, ...nodes],
        };
        this.policiesLoadCursor.compliancePoliciesAfter = pageInfo.endCursor;
        this.policiesLoaded = !pageInfo.hasNextPage;
      },
      error(error) {
        this.handleError(error);
      },
      skip() {
        return this.policiesLoaded;
      },
    },
  },

  computed: {
    policies() {
      const compliancePoliciesSet = new Set(
        this.rawPolicies.compliancePolicies.map((p) => `${p.type}:${p.name}`),
      );

      return this.rawPolicies.namespaceSecurityPolicies
        .filter((p) =>
          compliancePoliciesSet.has(`${this.$options.normalizeType(p.type)}:${p.name}`),
        )
        .map(({ policyAttributes, ...rest }) => ({
          ...rest,
          source: policyAttributes?.source,
          isLinked: true,
        }))
        .sort((a, b) => (a.name > b.name ? 1 : -1));
    },

    policyType() {
      return this.selectedPolicy ? getPolicyType(this.selectedPolicy.type, 'value', false) : '';
    },
    isLoading() {
      return (
        this.$apollo.queries.complianceFrameworkPolicies.loading ||
        this.$apollo.queries.namespacePolicies.loading
      );
    },
  },

  watch: {
    policiesLoaded(loaded) {
      if (loaded) {
        this.$emit('policies-count-loaded', this.rawPolicies.compliancePolicies.length);
      }
    },
  },

  methods: {
    handleError(error) {
      this.errorMessage = this.$options.i18n.fetchError;
      Sentry.captureException(error);
    },

    openPolicyDrawerFromRow(rows) {
      if (this.isInherited || rows.length === 0) return;
      this.openPolicyDrawer(rows[0]);
    },

    openPolicyDrawer(policy) {
      if (this.isInherited) return;
      this.selectedPolicy = policy;
    },

    deselectPolicy() {
      this.selectedPolicy = null;
      this.$refs.policiesTable.$children[0].clearSelected();
    },
  },

  normalizeType(type) {
    return type === 'scan_result_policy' ? 'approval_policy' : type;
  },
  tableFields: [
    {
      key: 'name',
      label: i18n.policiesTableFields.name,
      thClass: '!gl-border-t-0',
      tdClass: '!gl-bg-default @md/panel:gl-w-2/5 !gl-border-b-white',
    },
    {
      key: 'description',
      label: i18n.policiesTableFields.desc,
      thClass: '!gl-border-t-0',
      tdClass: '!gl-bg-default @md/panel:gl-w-2/5 !gl-border-b-white',
    },
    {
      key: 'action',
      label: i18n.policiesTableFields.action,
      thAlignRight: true,
      thClass: '!gl-border-t-0',
      tdClass: 'gl-text-right @md/panel:gl-w-1/5 !gl-bg-default !gl-border-b-white',
    },
  ],
  i18n,
};
</script>

<template>
  <edit-section
    :title="$options.i18n.policies"
    :description="$options.i18n.policiesDescription"
    :items-count="count"
  >
    <gl-table
      v-if="count"
      ref="policiesTable"
      :items="policies"
      :fields="$options.tableFields"
      :busy="isLoading"
      responsive
      stacked="md"
      hover
      :selectable="!isInherited"
      select-mode="single"
      selected-variant="primary"
      class="gl-mb-6"
      @row-selected="openPolicyDrawerFromRow"
    >
      <template #cell(name)="{ item }">
        <span>{{ item.name }}</span>
        <gl-badge v-if="!item.enabled" variant="neutral" class="gl-ml-2">
          {{ __('Disabled') }}
        </gl-badge>
      </template>
      <template #cell(action)="{ item }">
        <gl-button v-if="!isInherited" variant="link" @click="openPolicyDrawer(item)">
          {{ __('View details') }}
        </gl-button>
      </template>

      <template #table-busy>
        <gl-skeleton-loader :lines="count" equal-width-lines />
      </template>
    </gl-table>
    <drawer-wrapper
      v-if="!isInherited"
      container-class=".content-wrapper"
      :open="Boolean(selectedPolicy)"
      :policy="selectedPolicy"
      :policy-type="policyType"
      :disable-scan-policy-update="disableScanPolicyUpdate"
      @close="deselectPolicy"
    />
    <div class="gl-ml-5" data-testid="info-text">
      <gl-icon name="information-o" variant="subtle" class="gl-mr-2" />
      <gl-sprintf :message="$options.i18n.policiesInfoText">
        <template #link="{ content }">
          <gl-link :href="groupSecurityPoliciesPath">{{ content }}</gl-link>
        </template>
      </gl-sprintf>
    </div>
  </edit-section>
</template>
