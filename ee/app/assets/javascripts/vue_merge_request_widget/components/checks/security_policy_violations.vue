<script>
import { GlIcon, GlPopover } from '@gitlab/ui';
import { get, uniqBy } from 'lodash-es';
import { s__ } from '~/locale';
import MergeChecksMessage from '~/vue_merge_request_widget/components/checks/message.vue';
import ActionButtons from '~/vue_merge_request_widget/components/action_buttons.vue';
import getPolicyViolations from 'ee/merge_requests/reports/queries/policy_violations.query.graphql';
import SecurityPolicyViolationsModal from 'ee/vue_merge_request_widget/components/checks/security_policy_violations_modal.vue';
import { getSelectedModeOption } from './utils';
import { EXCEPTION_MODE, WARN_MODE } from './constants';
import SecurityPolicyViolationsSelector from './security_policy_violations_selector.vue';
import SecurityPolicyBypassStatusesModal from './security_policy_bypass_statuses_modal.vue';

const BYPASS_POLICY_ENFORCEMENT_TYPES = ['WARN'];

export default {
  HELP_ICON_ID: 'security-policy-help-icon',
  name: 'MergeChecksSecurityPolicyViolations',
  components: {
    ActionButtons,
    GlIcon,
    GlPopover,
    MergeChecksMessage,
    SecurityPolicyViolationsModal,
    SecurityPolicyViolationsSelector,
    SecurityPolicyBypassStatusesModal,
  },
  apollo: {
    policies: {
      query: getPolicyViolations,
      variables() {
        return { iid: this.mr.iid.toString(), projectPath: this.mr.targetProjectFullPath };
      },
      context: {
        featureCategory: 'security_policy_management',
      },
      update(data) {
        // policies are only returned if the user is able to approve the MR
        const policies = get(data, 'project.mergeRequest.policyViolations.policies', []);
        return uniqBy(policies, 'securityPolicyId');
      },
      result({ data }) {
        // "policyBypassStatuses" are returned regardless of the users ability to bypass them
        // the `allowBypass` flag is used to signify if a user can bypass the policy
        this.bypassStatuses = get(data, 'project.mergeRequest.policyBypassStatuses', []).filter(
          ({ allowBypass }) => allowBypass,
        );
      },
    },
  },
  props: {
    mr: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    check: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      bypassStatuses: [],
      policies: [],
      showModal: false,
      selectedModeOption: '',
    };
  },
  computed: {
    mode() {
      return getSelectedModeOption({
        hasBypassPolicies: this.hasActiveWarnPolicies,
        hasBypassExceptions: this.hasActiveBypassStatuses,
      });
    },
    activeBypassStatuses() {
      return this.bypassStatuses.filter(({ bypassed }) => !bypassed);
    },
    activeWarnPolicies() {
      return this.bypassPolicies.filter(({ dismissed }) => !dismissed);
    },
    bypassPolicies() {
      return this.policies.filter((policy) =>
        BYPASS_POLICY_ENFORCEMENT_TYPES.includes(policy.enforcementType),
      );
    },
    enableBypassButton() {
      return this.hasActiveWarnPolicies || this.hasActiveBypassStatuses;
    },
    hasActiveBypassStatuses() {
      return Boolean(this.activeBypassStatuses.length);
    },
    hasActiveWarnPolicies() {
      return Boolean(this.activeWarnPolicies.length);
    },
    hasBypassPolicies() {
      return this.bypassPolicies.length > 0;
    },
    hasBypassStatuses() {
      return this.bypassStatuses.length > 0;
    },
    showBypassButton() {
      return this.mr.securityPoliciesPath && (this.hasBypassPolicies || this.hasBypassStatuses);
    },
    tertiaryActionsButtons() {
      return [
        this.mr.securityPoliciesPath && {
          href: this.mr.securityPoliciesPath,
          text: s__('MergeChecks|View policies'),
          testId: 'view-policies-button',
        },
        this.showBypassButton && {
          onClick: () => this.toggleModal(true),
          disabled: !this.enableBypassButton,
          testId: 'bypass-button',
          text: this.bypassButtonText,
        },
      ].filter((x) => x);
    },
    bypassButtonText() {
      return this.enableBypassButton ? s__('MergeChecks|Bypass') : s__('MergeChecks|Bypassed');
    },
    showModeSelector() {
      return this.showModal && this.calculatedMode === '';
    },
    showBypassStatusesModal() {
      return this.showModal && this.calculatedMode === EXCEPTION_MODE;
    },
    showViolationsModal() {
      return this.showModal && this.calculatedMode === WARN_MODE;
    },
    calculatedMode() {
      return this.selectedModeOption || this.mode;
    },
  },
  methods: {
    cancelEdit() {
      this.showModal = false;
      this.selectedModeOption = this.mode;
    },
    toggleModal(value) {
      this.showModal = value;
    },
    selectMode(mode) {
      this.selectedModeOption = mode;
    },
    refetchPolicies() {
      this.$apollo.queries.policies.refetch();
    },
  },
};
</script>

<template>
  <merge-checks-message :check="check">
    <template v-if="check.status !== 'INACTIVE'">
      <div v-if="showBypassButton">
        <gl-icon
          :id="$options.HELP_ICON_ID"
          data-testid="security-policy-help-icon"
          name="information-o"
          variant="info"
          class="gl-mr-3"
        />
        <gl-popover
          :target="$options.HELP_ICON_ID"
          data-testid="security-policy-help-popover"
          placement="top"
        >
          <template #title>{{ s__('MergeChecks|Bypass security policies') }}</template>
          <p class="gl-mb-0">
            {{
              s__(
                'MergeChecks|Bypassing a policy violation creates an audit event. When merged into the default branch, bypassed vulnerability findings are marked as policy violations in the vulnerability report.',
              )
            }}
          </p>
        </gl-popover>
      </div>
      <action-buttons :tertiary-buttons="tertiaryActionsButtons" />

      <security-policy-violations-selector
        v-if="showModeSelector"
        v-model="showModal"
        @select="selectMode"
        @close="cancelEdit"
      />

      <security-policy-bypass-statuses-modal
        v-if="showBypassStatusesModal"
        v-model="showModal"
        :mr="mr"
        :policies="activeBypassStatuses"
        @close="cancelEdit"
        @saved="refetchPolicies"
      />

      <security-policy-violations-modal
        v-if="showViolationsModal"
        v-model="showModal"
        :mr="mr"
        :policies="activeWarnPolicies"
        @close="cancelEdit"
        @saved="refetchPolicies"
      />
    </template>
  </merge-checks-message>
</template>
