<script>
import { GlLoadingIcon, GlSprintf } from '@gitlab/ui';
import { isEmpty } from 'lodash-es';
import { s__ } from '~/locale';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { capitalizeFirstCharacter } from '~/lib/utils/text_utility';
import { parseAllowDenyLicenseList } from 'ee/security_orchestration/components/policy_editor/utils';
import { APPROVAL_POLICY_TYPE } from 'ee/security_orchestration/components/constants';
import { fromYaml } from 'ee/security_orchestration/components/utils';
import ToggleList from 'ee/security_orchestration/components/scope/toggle_list.vue';
import {
  BOT_MESSAGE_TYPE,
  REQUIRE_APPROVAL_TYPE,
  WARN_VALUE,
} from '../../policy_editor/scan_result/lib';
import { hasMalwareBlockingEnabled } from '../../policy_editor/scan_result/lib/rules';
import { SUMMARY_TITLE } from '../constants';
import InfoRow from '../info_row.vue';
import DrawerLayout from '../drawer_layout.vue';
import MalwareBlockingAlert from './malware_blocking_alert.vue';
import DenyAllowViewList from './deny_allow_view_list.vue';
import LicenseOverridesViewList from './license_overrides_view_list.vue';
import Approvals from './policy_approvals.vue';
import EdgeCaseSettings from './edge_case_settings.vue';
import PolicyExceptions from './policy_exceptions/policy_exceptions.vue';
import Settings from './policy_settings.vue';
import { humanizeRules, mapApproversToArray } from './utils';

export default {
  name: 'ScanResultDetailsDrawer',
  i18n: {
    botActionText: s__('SecurityOrchestration|Send a bot message when the conditions match.'),
    approvalsSubheader: s__('SecurityOrchestration|If any of the following occur:'),
    fallbackTitle: s__('SecurityOrchestration|Fallback behavior in case of policy failure'),
    loadingApprovers: s__('SecurityOrchestration|Loading approvers...'),
    summary: SUMMARY_TITLE,
    scanResult: s__('SecurityOrchestration|Merge request approval'),
  },
  components: {
    DenyAllowViewList,
    GlLoadingIcon,
    LicenseOverridesViewList,
    GlSprintf,
    MalwareBlockingAlert,
    ToggleList,
    DrawerLayout,
    InfoRow,
    Approvals,
    EdgeCaseSettings,
    PolicyExceptions,
    Settings,
  },
  mixins: [glFeatureFlagsMixin()],
  props: {
    policy: {
      type: Object,
      required: true,
    },
    loadingDetails: {
      type: Boolean,
      required: false,
      default: false,
    },
    showPolicyScope: {
      type: Boolean,
      required: false,
      default: true,
    },
    showStatus: {
      type: Boolean,
      required: false,
      default: true,
    },
  },
  computed: {
    actions() {
      return this.parsedYaml?.actions;
    },
    description() {
      return this.parsedYaml?.description || '';
    },
    fallbackBehaviorText() {
      switch (this.parsedYaml?.fallback_behavior?.fail) {
        case 'open':
          return s__(
            'ScanResultPolicy|Fail open: Allow the merge request to proceed, even if not all criteria are met',
          );
        case 'closed':
          return s__(
            'ScanResultPolicy|Fail closed: Block the merge request until all criteria are met',
          );
        default:
          return null;
      }
    },
    humanizedRules() {
      return humanizeRules(this.parsedYaml?.rules);
    },
    parsedYaml() {
      return fromYaml({
        manifest: this.policy.yaml,
        type: APPROVAL_POLICY_TYPE,
      });
    },
    hasRequireApprovals() {
      return this.requireApprovals.length > 0;
    },
    isWarnMode() {
      return this.parsedYaml?.enforcement_type === WARN_VALUE;
    },
    requireApprovals() {
      return this.actions?.filter((action) => action.type === REQUIRE_APPROVAL_TYPE) || [];
    },
    policyScope() {
      return this.policy?.policyScope;
    },
    actionApprovers() {
      return this.policy?.actionApprovers || [];
    },
    edgeCaseSettings() {
      return this.parsedYaml?.policy_tuning || {};
    },
    hasEdgeCaseSettings() {
      return Object.values(this.edgeCaseSettings).some((v) => v);
    },
    hasPolicyExceptions() {
      return !isEmpty(this.policyExceptions);
    },
    policyExceptions() {
      return this.parsedYaml?.bypass_settings || {};
    },
    settings() {
      return this.parsedYaml?.approval_settings || {};
    },
    hasBotMessage() {
      return !this.actions?.some(({ type, enabled }) => type === BOT_MESSAGE_TYPE && !enabled);
    },
    shouldRenderBotMessage() {
      return this.hasBotMessage && !this.isWarnMode;
    },
    hasMaliciousRule() {
      return hasMalwareBlockingEnabled(this.parsedYaml?.rules || []);
    },
    showMalwareBlockingAlert() {
      return Boolean(this.glFeatures?.securityPoliciesMalwareAttribute) && this.hasMaliciousRule;
    },
  },
  methods: {
    capitalizedCriteriaMessage(message) {
      return capitalizeFirstCharacter(message.trim());
    },
    showItems(items) {
      return items?.length > 0;
    },
    mapApproversToArray(index) {
      return mapApproversToArray(this.actionApprovers[index]);
    },
    getDenyAllowList(licenses) {
      return parseAllowDenyLicenseList({ licenses });
    },
    showDenyAllowList(licenses = {}) {
      return this.getDenyAllowList(licenses).licenses.length > 0;
    },
  },
};
</script>

<template>
  <drawer-layout
    key="scan_result_policy"
    :description="description"
    :policy="policy"
    :policy-scope="policyScope"
    :type="$options.i18n.scanResult"
    :show-policy-scope="showPolicyScope"
    :show-status="showStatus"
  >
    <template v-if="parsedYaml" #summary>
      <info-row data-testid="policy-summary" :label="$options.i18n.summary">
        <div v-if="loadingDetails && !actionApprovers.length" class="gl-mb-2">
          <gl-loading-icon size="sm" inline />
          <span class="gl-ml-2 gl-text-subtle">{{ $options.i18n.loadingApprovers }}</span>
        </div>
        <template v-else>
          <approvals
            v-for="(action, index) in requireApprovals"
            :key="action.id"
            class="gl-mb-2 gl-block"
            :action="action"
            :approvers="mapApproversToArray(index)"
            :is-last-item="!hasBotMessage"
            :is-warn-mode="isWarnMode"
          />
        </template>

        <div v-if="shouldRenderBotMessage" class="gl-mt-2" data-testid="policy-bot-message">
          {{ $options.i18n.botActionText }}
        </div>

        <malware-blocking-alert v-if="showMalwareBlockingAlert" class="gl-mt-4" />

        <p
          v-if="hasRequireApprovals"
          data-testid="approvals-subheader"
          class="gl-mb-0 gl-mt-6 gl-block"
        >
          {{ $options.i18n.approvalsSubheader }}
        </p>

        <div
          v-for="(
            {
              summary,
              branchExceptions,
              licenses,
              criteriaMessage,
              criteriaList,
              denyAllowList,
              scannerDetails,
              licenseOverrides,
            },
            idx
          ) in humanizedRules"
          :key="idx"
          class="gl-pt-5"
        >
          <gl-sprintf :message="summary">
            <template #licenses>
              <toggle-list v-if="showItems(licenses)" class="gl-mb-2" :items="licenses" />
            </template>
          </gl-sprintf>
          <deny-allow-view-list
            v-if="showDenyAllowList(denyAllowList)"
            class="gl-my-4"
            :is-denied="getDenyAllowList(denyAllowList).isDenied"
            :items="getDenyAllowList(denyAllowList).licenses"
          />
          <license-overrides-view-list
            v-if="showItems(licenseOverrides)"
            class="gl-my-4"
            :items="licenseOverrides"
          />
          <toggle-list
            v-if="showItems(branchExceptions)"
            class="gl-mb-2"
            :items="branchExceptions"
          />
          <p v-if="criteriaMessage" class="gl-mb-3">
            {{ capitalizedCriteriaMessage(criteriaMessage) }}
          </p>
          <ul v-if="criteriaList && criteriaList.length" class="gl-m-0">
            <li v-for="(criteria, criteriaIdx) in criteriaList" :key="criteriaIdx" class="gl-mt-2">
              {{ criteria }}
            </li>
          </ul>
          <div
            v-if="scannerDetails && scannerDetails.length"
            data-testid="scanner-details"
            class="gl-mt-3"
          >
            <div
              v-for="(scanner, scannerIdx) in scannerDetails"
              :key="scannerIdx"
              class="gl-mt-3"
              data-testid="scanner-detail-item"
            >
              <p class="gl-mb-2 gl-font-bold">{{ scanner.name }}</p>
              <ul v-if="scanner.criteriaList.length" class="gl-m-0">
                <li v-for="(criteria, cIdx) in scanner.criteriaList" :key="cIdx" class="gl-mt-2">
                  {{ criteria }}
                </li>
              </ul>
            </div>
          </div>
          <settings :settings="settings" />

          <policy-exceptions
            v-if="hasPolicyExceptions"
            class="gl-mt-6"
            :exceptions="policyExceptions"
          />
        </div>
      </info-row>
    </template>

    <template #additional-details>
      <info-row
        v-show="fallbackBehaviorText"
        :label="$options.i18n.fallbackTitle"
        data-testid="fallback-details"
      >
        {{ fallbackBehaviorText }}
      </info-row>
      <edge-case-settings v-if="hasEdgeCaseSettings" :settings="edgeCaseSettings" />
      <slot name="additional-details"></slot>
    </template>
  </drawer-layout>
</template>
