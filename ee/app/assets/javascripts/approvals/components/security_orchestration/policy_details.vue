<script>
import { GlButton } from '@gitlab/ui';
import { s__ } from '~/locale';
import {
  humanizeRules,
  mapApproversToArray,
} from 'ee/security_orchestration/components/policy_drawer/scan_result/utils';
import { policyHasNamespace } from 'ee/security_orchestration/components/utils';
import PolicyApprovals from 'ee/security_orchestration/components/policy_drawer/scan_result/policy_approvals.vue';
import { REQUIRE_APPROVAL_TYPE } from 'ee/security_orchestration/components/policy_editor/scan_result/lib';

export default {
  name: 'PolicyDetails',
  i18n: {
    policyDetails: s__('SecurityOrchestration|Edit policy'),
  },
  components: {
    GlButton,
    PolicyApprovals,
  },
  props: {
    policy: {
      type: Object,
      required: true,
    },
  },
  computed: {
    humanizedRules() {
      return humanizeRules(this.policy.rules);
    },
    showEditLink() {
      return this.policy?.source?.inherited ? policyHasNamespace(this.policy.source) : true;
    },
    actionApprovers() {
      return this.policy?.actionApprovers || [];
    },
    actions() {
      return this.policy?.actions || [];
    },
    requireApprovals() {
      return this.actions?.filter((action) => action.type === REQUIRE_APPROVAL_TYPE) || [];
    },
    colSpan() {
      return this.showEditLink ? 3 : 4;
    },
  },
  methods: {
    mapApproversToArray(index) {
      return mapApproversToArray(this.actionApprovers[index]);
    },
  },
};
</script>

<template>
  <tr v-if="policy.isSelected">
    <td :colspan="colSpan" class="!gl-border-t-0">
      <policy-approvals
        v-for="(approval, index) in requireApprovals"
        :key="index"
        :action="approval"
        :approvers="mapApproversToArray(index)"
      />
      <div
        v-for="{ summary, criteriaList } in humanizedRules"
        :key="summary"
        class="gl-mb-1 gl-mt-5"
      >
        {{ summary }}
        <ul class="gl-m-0">
          <li v-for="criteria in criteriaList" :key="criteria">
            {{ criteria }}
          </li>
        </ul>
      </div>
    </td>
    <td v-if="showEditLink" class="!gl-border-t-0">
      <gl-button
        v-if="showEditLink"
        :href="policy.editPath"
        size="small"
        variant="confirm"
        category="tertiary"
      >
        {{ $options.i18n.policyDetails }}
      </gl-button>
    </td>
  </tr>
</template>
