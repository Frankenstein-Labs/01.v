<script>
import {
  GlBadge,
  GlButtonGroup,
  GlDisclosureDropdown,
  GlLink,
  GlLoadingIcon,
  GlSprintf,
  GlTable,
  GlKeysetPagination,
  GlPopover,
} from '@gitlab/ui';
import { __, s__ } from '~/locale';
import { createAlert } from '~/alert';
import { getSecurityPolicyListUrl } from '~/editor/extensions/source_editor_security_policy_schema_ext';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import { DATE_ONLY_FORMAT } from '~/lib/utils/datetime_utility';
import { setUrlParams, updateHistory } from '~/lib/utils/url_utility';
import getGroupProjectsCount from 'ee/security_orchestration/graphql/queries/get_group_project_count.query.graphql';
import spepTestRunMutation from 'ee/security_orchestration/graphql/mutations/spep_test_run.mutation.graphql';
import {
  buildPolicyViolationList,
  exceedsActionLimit,
  exceedsScheduleRulesLimit,
  getTestRunsForProject,
} from 'ee/security_orchestration/components/policies/utils';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import {
  fromYaml,
  checkForPerformanceRisk,
  isGroup,
  isPolicyInherited,
  policyHasNamespace,
} from 'ee/security_orchestration/components/utils';
import {
  hasMalwareEligibleScanner,
  hasMalwareBlockingEnabled,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib/rules';
import { getPolicyType } from '../../utils';
import DrawerWrapper from '../policy_drawer/drawer_wrapper.vue';
import { SECURITY_POLICY_ACTIONS } from '../policy_editor/constants';
import { goToPolicyMR } from '../policy_editor/utils';
import OverloadWarningModal from '../overload_warning_modal.vue';
import { APPROVAL_POLICY_TYPE, PIPELINE_EXECUTION_SCHEDULE_POLICY_TYPE } from '../constants';
import {
  POLICY_SOURCE_OPTIONS,
  POLICY_TYPE_FILTER_OPTIONS,
  BREAKING_CHANGES_POPOVER_CONTENTS,
} from './constants';
import BreakingChangesIcon from './breaking_changes_icon.vue';
import SourceFilter from './filters/source_filter.vue';
import TypeFilter from './filters/type_filter.vue';
import EmptyState from './empty_state.vue';
import ListComponentScope from './list_component_scope.vue';
import StatusIcon from './status_icon.vue';
import TestRunStatusBadge from './test_run_status_badge.vue';
import MalwareGapIndicator from './malware_gap_indicator.vue';

const getPoliciesWithType = (policies, policyType) =>
  policies.map((policy) => ({
    ...policy,
    policyType,
  }));

export default {
  name: 'ListComponent',
  apollo: {
    projectsCount: {
      query: getGroupProjectsCount,
      variables() {
        return {
          fullPath: this.namespacePath,
        };
      },
      update(data) {
        return data.group?.projects?.count || 0;
      },
      skip() {
        return !isGroup(this.namespaceType);
      },
      error() {
        this.projectsCount = 0;
      },
    },
  },
  components: {
    BreakingChangesIcon,
    GlBadge,
    GlButtonGroup,
    GlDisclosureDropdown,
    GlLink,
    GlLoadingIcon,
    GlKeysetPagination,
    GlPopover,
    GlSprintf,
    GlTable,
    EmptyState,
    ListComponentScope,
    SourceFilter,
    TypeFilter,
    DrawerWrapper,
    OverloadWarningModal,
    TestRunStatusBadge,
    MalwareGapIndicator,
    TimeAgoTooltip,
    StatusIcon,
  },
  mixins: [glFeatureFlagsMixin()],
  inject: [
    'assignedPolicyProject',
    'namespacePath',
    'namespaceType',
    'disableScanPolicyUpdate',
    'maxScanExecutionPolicyActions',
    'maxScanExecutionPolicySchedules',
  ],
  props: {
    hasPolicyProject: {
      type: Boolean,
      required: false,
      default: false,
    },
    isLoadingPolicies: {
      type: Boolean,
      required: false,
      default: false,
    },
    policiesByType: {
      type: Object,
      required: true,
    },
    selectedPolicySource: {
      type: String,
      required: false,
      default: POLICY_SOURCE_OPTIONS.ALL.value,
    },
    selectedPolicyType: {
      type: String,
      required: false,
      default: POLICY_TYPE_FILTER_OPTIONS.ALL.value,
    },
    linkedSppItems: {
      type: Array,
      required: false,
      default: () => [],
    },
    shouldUpdatePolicyList: {
      type: Boolean,
      required: false,
      default: false,
    },
    pageInfo: {
      type: Object,
      required: false,
      default: null,
    },
  },
  emits: [
    'cleared-selected',
    'next-page',
    'prev-page',
    'update-policy-source',
    'update-policy-type',
  ],
  data() {
    return {
      activeTestRuns: {},
      alert: null,
      dismissPerformanceWarningModal: false,
      isProcessingAction: false,
      policyToDelete: null,
      projectsCount: 0,
      selectedPolicy: null,
      showPerformanceWarningModal: false,
    };
  },
  computed: {
    disabledPopoverTitle() {
      return this.disableScanPolicyUpdate
        ? this.$options.i18n.popoverPermissionTitle
        : this.$options.i18n.popoverTitle;
    },
    hasNextPage() {
      return this.pageInfo?.hasNextPage;
    },
    hasPreviousPage() {
      return this.pageInfo?.hasPreviousPage;
    },
    startCursor() {
      return this.pageInfo?.startCursor;
    },
    endCursor() {
      return this.pageInfo?.endCursor;
    },
    showPagination() {
      return this.pageInfo?.hasNextPage || this.pageInfo?.hasPreviousPage;
    },
    isBusy() {
      return this.isLoadingPolicies || this.isProcessingAction;
    },
    isGroup() {
      return isGroup(this.namespaceType);
    },
    policies() {
      const policyTypes =
        this.selectedPolicyType === POLICY_TYPE_FILTER_OPTIONS.ALL.value
          ? Object.keys(this.policiesByType)
          : [this.selectedPolicyType];

      const policies = policyTypes.map((type) =>
        getPoliciesWithType(this.policiesByType[type], POLICY_TYPE_FILTER_OPTIONS[type].text),
      );

      return policies.flat();
    },
    hasSelectedPolicy() {
      return Boolean(this.selectedPolicy);
    },
    typeLabel() {
      if (this.isGroup) {
        return this.$options.i18n.groupTypeLabel;
      }
      return this.$options.i18n.projectTypeLabel;
    },
    policyTypeFromSelectedPolicy() {
      if (!this.selectedPolicy) {
        return '';
      }

      return getPolicyType(this.selectedPolicy.type, 'value', false);
    },
    activeTestRunForSelectedPolicy() {
      return this.activeTestRuns[this.selectedPolicy?.id];
    },
    hasExistingPolicies() {
      return !(
        this.selectedPolicyType === POLICY_TYPE_FILTER_OPTIONS.ALL.value &&
        this.selectedPolicySource === POLICY_SOURCE_OPTIONS.ALL.value &&
        !this.policies.length
      );
    },
    fields() {
      return [
        {
          key: 'status',
          label: __('Status'),
          tdAttr: { 'data-testid': 'policy-status-cell' },
        },
        {
          key: 'name',
          label: __('Name'),
          thClass: 'gl-w-3/10',
          sortable: true,
        },
        {
          key: 'policyType',
          label: s__('SecurityOrchestration|Policy type'),
          sortable: true,
          tdAttr: { 'data-testid': 'policy-type-cell' },
        },
        {
          key: 'source',
          label: s__('SecurityOrchestration|Source'),
          sortable: true,
          tdAttr: { 'data-testid': 'policy-source-cell' },
        },
        {
          key: 'scope',
          label: s__('SecurityOrchestration|Scope'),
          sortable: true,
          tdAttr: { 'data-testid': 'policy-scope-cell' },
        },
        {
          key: 'updatedAt',
          label: __('Last modified'),
          sortable: true,
        },
        {
          key: 'actions',
          label: __('Actions'),
          tdAttr: { 'data-testid': 'policy-action-cell' },
        },
      ];
    },
  },
  watch: {
    shouldUpdatePolicyList(newShouldUpdatePolicyList) {
      if (newShouldUpdatePolicyList) {
        this.deselectPolicy();
      }
    },
  },
  methods: {
    getPolicyActionOptions(policy) {
      const options = [
        { text: __('Edit'), href: policy.editPath },
        {
          text: __('Delete'),
          action: () => this.handleDelete(policy),
          variant: 'danger',
        },
      ];

      if (this.showStartDryRunAction(policy.type)) {
        options.unshift({
          text: s__('SecurityOrchestration|Start dry run'),
          action: () => this.handleTestRun(policy),
        });
      }

      return options;
    },
    showStartDryRunAction(type) {
      return this.isPipelineExecutionSchedulePolicy(type) && !this.isGroup;
    },
    async handleTestRun(policy) {
      if (this.alert) this.alert.dismiss();
      this.isProcessingAction = true;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: spepTestRunMutation,
          variables: {
            policyId: policy.id,
            projectPath: this.namespacePath,
          },
        });

        const { testRun, errors } = data?.pipelineExecutionSchedulePolicyTestRun ?? {};

        if (errors?.length) {
          this.alert = createAlert({ message: errors.join(', ') });
        } else if (testRun) {
          this.activeTestRuns = { ...this.activeTestRuns, [policy.id]: testRun };
        }
      } catch (error) {
        this.alert = createAlert({
          message:
            error.message ||
            s__('SecurityOrchestration|Failed to start dry run. Please try again.'),
        });
      } finally {
        this.isProcessingAction = false;
      }
    },
    onTestRunCreated(testRun) {
      const policyId = this.selectedPolicy?.id;
      if (policyId && testRun) {
        this.activeTestRuns = { ...this.activeTestRuns, [policyId]: testRun };
      }
    },
    cancelPolicySubmit() {
      this.policyToDelete = null;
      this.showPerformanceWarningModal = false;
    },
    confirmPolicySubmit() {
      this.showPerformanceWarningModal = false;
      this.dismissPerformanceWarningModal = true;
      this.handleDelete(this.policyToDelete);
    },
    async handleDelete(policy) {
      if (this.hasPerformanceRisk(policy) && !this.dismissPerformanceWarningModal) {
        this.policyToDelete = policy;
        this.showPerformanceWarningModal = true;
        return;
      }

      const action = SECURITY_POLICY_ACTIONS.REMOVE;
      if (this.alert) this.alert.dismiss();
      this.isProcessingAction = true;

      const policyType = getPolicyType(policy.type, 'urlParameter', false);

      try {
        await goToPolicyMR({
          action,
          assignedPolicyProject: this.assignedPolicyProject,
          name: policy.name,
          namespacePath: this.namespacePath,
          yamlEditorValue: policy.yaml.concat(`type: ${policyType}`),
        });
      } catch (e) {
        this.alert = createAlert({ message: e.message });
        this.isProcessingAction = false;
      }
    },
    hasPerformanceRisk(policy) {
      return checkForPerformanceRisk({
        namespaceType: this.namespaceType,
        policy,
        projectsCount: this.projectsCount,
      });
    },
    showBreakingChangesIcon(policyType, deprecatedProperties, yaml) {
      return (
        (Boolean(BREAKING_CHANGES_POPOVER_CONTENTS[policyType]) &&
          deprecatedProperties?.length > 0) ||
        this.exceedsActionLimit(policyType, yaml) ||
        exceedsScheduleRulesLimit({
          policyType,
          yaml,
          maxScanExecutionPolicySchedules: this.maxScanExecutionPolicySchedules,
        })
      );
    },
    isPipelineExecutionSchedulePolicy(type) {
      return type === PIPELINE_EXECUTION_SCHEDULE_POLICY_TYPE;
    },
    showMalwareGapIndicator(type, yaml) {
      if (!this.glFeatures?.securityPoliciesMalwareAttribute || type !== APPROVAL_POLICY_TYPE) {
        return false;
      }

      const rules = fromYaml({ manifest: yaml, type: APPROVAL_POLICY_TYPE })?.rules || [];
      return hasMalwareEligibleScanner(rules) && !hasMalwareBlockingEnabled(rules);
    },
    testRunsForProject(testRuns, id, source) {
      if (this.activeTestRuns[id]) return this.activeTestRuns[id];
      const collection = getTestRunsForProject(testRuns, {
        isGroup: this.isGroup,
        source,
        namespacePath: this.namespacePath,
      });
      return collection?.nodes?.[0] || null;
    },
    policyListUrlArgs(source) {
      return { namespacePath: source?.namespace?.fullPath || '' };
    },
    getPolicyText(source) {
      return source?.namespace?.name || '';
    },
    getSecurityPolicyListUrl,
    isPolicyInherited,
    policyHasNamespace,
    presentPolicyDrawer(rows) {
      if (rows.length === 0) return;

      const [selectedPolicy] = rows;
      this.selectedPolicy = null;

      /**
       * According to design spec drawer should be closed
       * and opened when drawer content changes
       * it forces drawer to close and open with new content
       */
      this.$nextTick(() => {
        this.selectedPolicy = selectedPolicy;
      });
    },
    deselectPolicy() {
      this.selectedPolicy = null;

      // Refs are required by BTable to manipulate the selection
      // issue: https://gitlab.com/gitlab-org/gitlab-services/design.gitlab.com/-/issues/2831
      const bTable = this.$refs.policiesTable.$children[0];
      bTable.clearSelected();

      if (this.shouldUpdatePolicyList) {
        this.$emit('cleared-selected');
      }
    },
    convertFilterValue(defaultValue, value) {
      return value === defaultValue ? undefined : value;
    },
    setTypeFilter(type) {
      this.deselectPolicy();

      const value = this.convertFilterValue(POLICY_TYPE_FILTER_OPTIONS.ALL.value, type);
      updateHistory({
        url: setUrlParams({ type: value }),
        title: document.title,
        replace: true,
      });
      this.$emit('update-policy-type', type);
    },
    setSourceFilter(source) {
      this.deselectPolicy();

      const value = this.convertFilterValue(POLICY_SOURCE_OPTIONS.ALL.value, source);
      updateHistory({
        url: setUrlParams({ source: value }),
        title: document.title,
        replace: true,
      });
      this.$emit('update-policy-source', source);
    },
    exceedsActionLimit(policyType, yaml) {
      return exceedsActionLimit({
        policyType,
        yaml,
        maxScanExecutionPolicyActions: this.maxScanExecutionPolicyActions,
      });
    },
    violationList(policyType, deprecatedProperties, yaml) {
      return buildPolicyViolationList({
        policyType,
        deprecatedProperties,
        yaml,
        maxScanExecutionPolicyActions: this.maxScanExecutionPolicyActions,
        maxScanExecutionPolicySchedules: this.maxScanExecutionPolicySchedules,
      });
    },
    handlePageChange(eventName) {
      this.deselectPolicy();
      this.$emit(eventName);
    },
    handleNextPage() {
      this.handlePageChange('next-page');
    },
    handlePrevPage() {
      this.handlePageChange('prev-page');
    },
    isPolicyMenuDisabled(source) {
      return isPolicyInherited(source) || this.disableScanPolicyUpdate;
    },
    showDisabledPopover(source) {
      return (
        (isPolicyInherited(source) && policyHasNamespace(source)) || this.disableScanPolicyUpdate
      );
    },
  },
  dateTimeFormat: DATE_ONLY_FORMAT,
  i18n: {
    actionsDisabled: s__(
      'SecurityOrchestration|This policy is inherited from %{linkStart}namespace%{linkEnd} and must be edited there',
    ),
    inheritedLabel: s__('SecurityOrchestration|Inherited from %{namespace}'),
    inheritedShortLabel: s__('SecurityOrchestration|Inherited'),
    statusEnabled: __('The policy is enabled'),
    statusDisabled: __('The policy is disabled'),
    groupTypeLabel: s__('SecurityOrchestration|This group'),
    projectTypeLabel: s__('SecurityOrchestration|This project'),
    openPolicyActionsDropdown: s__('SecurityOrchestration|Open policy actions dropdown'),
    popoverTitle: s__('SecurityOrchestration|Inherited policy'),
    popoverPermissionTitle: s__(
      'SecurityOrchestration|You do not have the permission required to edit policies',
    ),
    popoverPermissionText: s__(
      'SecurityOrchestration|You need the Developer, Maintainer, or Owner role in the project or group. You also need one one of these roles in the security policy project.',
    ),
  },
  BREAKING_CHANGES_POPOVER_CONTENTS,
};
</script>

<template>
  <div>
    <div class="gl-bg-subtle gl-px-5 gl-pt-5">
      <div class="row gl-items-center gl-justify-between">
        <div class="gl-col-12 gl-col-sm-8 gl-col-md-6 gl-col-lg-5 row">
          <type-filter
            :value="selectedPolicyType"
            class="gl-col-6"
            data-testid="policy-type-filter"
            @input="setTypeFilter"
          />
          <source-filter
            :value="selectedPolicySource"
            class="gl-col-6"
            data-testid="policy-source-filter"
            @input="setSourceFilter"
          />
        </div>
      </div>
    </div>

    <gl-table
      ref="policiesTable"
      data-testid="policies-list"
      :busy="isBusy"
      :items="policies"
      :fields="fields"
      sort-by="updatedAt"
      sort-desc
      stacked="md"
      show-empty
      hover
      selectable
      select-mode="single"
      selected-variant="primary"
      @row-selected="presentPolicyDrawer"
    >
      <template #cell(name)="{ item: { name, type, yaml } }">
        <span>{{ name }}</span>
        <malware-gap-indicator v-if="showMalwareGapIndicator(type, yaml)" class="gl-ml-2" />
      </template>

      <template
        #cell(status)="{
          item: {
            deprecatedProperties,
            enabled,
            id,
            name,
            policyType,
            source,
            testRuns,
            type,
            yaml,
          },
        }"
      >
        <div class="gl-flex gl-flex-col gl-gap-2">
          <div class="gl-flex gl-justify-end gl-gap-4 @md/panel:gl-justify-start">
            <status-icon :enabled="enabled" />

            <breaking-changes-icon
              v-if="showBreakingChangesIcon(policyType, deprecatedProperties, yaml)"
              :id="name"
              :violation-list="violationList(policyType, deprecatedProperties, yaml)"
            />
          </div>
          <test-run-status-badge
            v-if="isPipelineExecutionSchedulePolicy(type)"
            :test-run="testRunsForProject(testRuns, id, source)"
          />
        </div>
      </template>

      <template #cell(policyType)="{ item: { policyType } }">
        <span>{{ policyType }}</span>
      </template>

      <template #cell(source)="{ item: { csp, source } }">
        <div>
          <span
            v-if="isPolicyInherited(source) && policyHasNamespace(source)"
            class="gl-whitespace-nowrap"
          >
            <gl-sprintf :message="$options.i18n.inheritedLabel">
              <template #namespace>
                <gl-link
                  :href="getSecurityPolicyListUrl(policyListUrlArgs(source))"
                  target="_blank"
                >
                  {{ getPolicyText(source) }}
                </gl-link>
              </template>
            </gl-sprintf>
          </span>
          <span v-else-if="isPolicyInherited(source) && !policyHasNamespace(source)">{{
            $options.i18n.inheritedShortLabel
          }}</span>
          <span v-else class="gl-whitespace-nowrap">{{ typeLabel }}</span>
        </div>
        <gl-badge v-if="csp" class="gl-inline-block">
          {{ s__('SecurityOrchestration|instance policy') }}
        </gl-badge>
      </template>

      <template #cell(scope)="{ item: { csp, policyScope } }">
        <list-component-scope
          :is-instance-level="csp"
          :policy-scope="policyScope"
          :linked-spp-items="linkedSppItems"
        />
      </template>

      <template #cell(updatedAt)="{ value: updatedAt }">
        <time-ago-tooltip
          v-if="updatedAt"
          :time="updatedAt"
          :date-time-format="$options.dateTimeFormat"
        />
      </template>

      <template #head(actions)="{ label }">
        <span class="gl-sr-only">{{ label }}</span>
      </template>

      <template #cell(actions)="{ item }">
        <gl-button-group>
          <span :ref="item.editPath">
            <gl-disclosure-dropdown
              :items="getPolicyActionOptions(item)"
              no-caret
              category="tertiary"
              icon="ellipsis_v"
              placement="bottom-end"
              class="-gl-my-3"
              :disabled="isPolicyMenuDisabled(item.source)"
              :toggle-text="$options.i18n.openPolicyActionsDropdown"
              text-sr-only
            />
          </span>
        </gl-button-group>
        <gl-popover v-if="showDisabledPopover(item.source)" :target="() => $refs[item.editPath]">
          <template #title>{{ disabledPopoverTitle }}</template>
          <div v-if="disableScanPolicyUpdate">
            {{ $options.i18n.popoverPermissionText }}
          </div>
          <gl-sprintf v-else :message="$options.i18n.actionsDisabled">
            <template #link>
              <gl-link
                :href="getSecurityPolicyListUrl(policyListUrlArgs(item.source))"
                target="_blank"
              >
                {{ getPolicyText(item.source) }}
              </gl-link>
            </template>
          </gl-sprintf>
        </gl-popover>
      </template>

      <template #table-busy>
        <gl-loading-icon size="lg" />
      </template>

      <template #empty>
        <empty-state
          :has-existing-policies="hasExistingPolicies"
          :has-policy-project="hasPolicyProject"
        />
      </template>
    </gl-table>

    <gl-keyset-pagination
      v-if="showPagination"
      class="gl-mt-3 gl-text-center"
      :has-previous-page="hasPreviousPage"
      :has-next-page="hasNextPage"
      :start-cursor="startCursor"
      :end-cursor="endCursor"
      @prev="handlePrevPage"
      @next="handleNextPage"
    />

    <overload-warning-modal
      :visible="showPerformanceWarningModal"
      @cancel-submit="cancelPolicySubmit"
      @confirm-submit="confirmPolicySubmit"
    />

    <drawer-wrapper
      :open="hasSelectedPolicy"
      :policy="selectedPolicy"
      :policy-type="policyTypeFromSelectedPolicy"
      :disable-scan-policy-update="disableScanPolicyUpdate"
      :active-test-run="activeTestRunForSelectedPolicy"
      data-testid="policyDrawer"
      @close="deselectPolicy"
      @test-run-created="onTestRunCreated"
    />
  </div>
</template>
