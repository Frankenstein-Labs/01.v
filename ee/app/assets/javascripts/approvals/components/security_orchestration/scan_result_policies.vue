<script>
import { GlLink, GlButton, GlFormGroup } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import Container from '../rules/rules.vue';
import { parsePolicies, securityPoliciesQuery } from './utils';
import ScanResultPolicy from './scan_result_policy.vue';
import PolicyDetails from './policy_details.vue';

export default {
  name: 'ScanResultPolicies',
  i18n: {
    securityApprovals: s__('SecurityOrchestration|Security Approvals'),
    description: s__(
      'SecurityOrchestration|Create security policies to enforce security and compliance controls that help keep your project secure.',
    ),
    learnMore: __('Learn more'),
    noPolicies: s__("SecurityOrchestration|You don't have any security policies yet"),
    createPolicy: s__('SecurityOrchestration|Create security policy'),
  },
  components: {
    Container,
    CrudComponent,
    GlLink,
    GlButton,
    ScanResultPolicy,
    PolicyDetails,
    GlFormGroup,
  },
  inject: ['fullPath', 'newPolicyPath'],
  apollo: {
    securityPolicies() {
      return securityPoliciesQuery({ fullPath: this.fullPath });
    },
  },
  data() {
    return {
      securityPolicies: [],
      selectedPolicies: {},
    };
  },
  computed: {
    parsedPolicies() {
      return parsePolicies(this.securityPolicies, this.fullPath);
    },
    policies() {
      return this.parsedPolicies.map((policy) => ({
        ...policy,
        isSelected: Boolean(this.selectedPolicies[policy.name]),
      }));
    },
    hasPolicies() {
      return this.policies.length > 0;
    },
  },
  methods: {
    selectionChanged(index) {
      const policyName = this.parsedPolicies[index]?.name;
      if (!policyName) return;

      this.selectedPolicies = {
        ...this.selectedPolicies,
        [policyName]: !this.selectedPolicies[policyName],
      };
    },
  },
  scanResultPolicyHelpPagePath: helpPagePath(
    'user/application_security/policies/merge_request_approval_policies',
  ),
};
</script>

<template>
  <gl-form-group data-testid="security-policies-approvals">
    <crud-component :title="$options.i18n.securityApprovals" icon="shield" :count="policies.length">
      <template #description>
        {{ $options.i18n.description }}
        <gl-link :href="$options.scanResultPolicyHelpPagePath" target="_blank" class="gl-text-sm"
          >{{ $options.i18n.learnMore }}.</gl-link
        >
      </template>
      <template #actions>
        <gl-button category="secondary" size="small" :href="newPolicyPath">
          {{ $options.i18n.createPolicy }}
        </gl-button>
      </template>

      <container :rules="policies">
        <template #thead="{ name, approvalsRequired, branches }">
          <tr class="!gl-table-row">
            <th class="!gl-w-1/2">{{ name }}</th>
            <th>{{ branches }}</th>
            <th>{{ approvalsRequired }}</th>
            <th></th>
          </tr>
        </template>
        <template #tbody>
          <tr v-if="!hasPolicies">
            <td colspan="4" class="gl-p-5 gl-text-center gl-text-subtle">
              {{ $options.i18n.noPolicies }}.
            </td>
          </tr>
          <template v-for="(policy, index) in policies" v-else>
            <scan-result-policy
              :key="`${policy.name}-policy`"
              :policy="policy"
              @toggle="selectionChanged(index)"
            />
            <policy-details :key="`${policy.name}-details`" :policy="policy" />
          </template>
        </template>
      </container>
    </crud-component>
  </gl-form-group>
</template>
