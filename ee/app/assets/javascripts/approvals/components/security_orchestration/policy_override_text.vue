<script>
import { GlLink, GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  name: 'PolicyOverrideText',
  components: {
    GlLink,
    GlSprintf,
  },
  props: {
    policies: {
      type: Array,
      required: false,
      default: () => [],
    },
    isWarn: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    hasPolicies() {
      return this.policies.length > 0;
    },
    hasMultiplePolicies() {
      return this.policies.length > 1;
    },
    multiplePoliciesText() {
      return this.isWarn
        ? s__(
            'SecurityOrchestration|Approval settings might be affected by rules in the following policies if the policies change from warn mode to strictly enforced:',
          )
        : s__(
            'SecurityOrchestration|Approval settings might be affected by rules in the following policies. These properties are only enforced when there are merge request policy violations:',
          );
    },
    singlePolicyText() {
      return this.isWarn
        ? s__(
            'SecurityOrchestration|Approval settings might be affected by the rules in policy %{policyName} if the policy changes from warn mode to strictly enforced.',
          )
        : s__(
            'SecurityOrchestration|Approval settings might be affected by the rules in policy %{policyName}. Enforcement of these properties is conditional on merge request policy violations.',
          );
    },
  },
};
</script>

<template>
  <div v-if="hasPolicies">
    <template v-if="hasMultiplePolicies">
      {{ multiplePoliciesText }}
      <ul class="gl-pl-5">
        <li v-for="(policy, index) in policies" :key="index">
          <gl-link :href="policy.editPath" target="_blank" :data-testid="`policy-item-${index}`">
            {{ policy.name }}
          </gl-link>
        </li>
      </ul>
    </template>
    <template v-else>
      <gl-sprintf :message="singlePolicyText">
        <template #policyName>
          <gl-link :href="policies[0].editPath" target="_blank">
            {{ policies[0].name }}
          </gl-link>
        </template>
      </gl-sprintf>
    </template>
  </div>
</template>
