<script>
import {
  GlButton,
  GlAlert,
  GlDisclosureDropdown,
  GlFormCheckbox,
  GlIcon,
  GlLink,
  GlSprintf,
  GlTable,
  GlKeysetPagination,
  GlTooltipDirective,
  GlToastMixin,
} from '@gitlab/ui';
import { __, s__, n__, sprintf } from '~/locale';
import { createAlert } from '~/alert';
import { confirmAction } from '~/lib/utils/confirm_via_gl_modal/confirm_via_gl_modal';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_GROUP } from '~/graphql_shared/constants';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import groupScannerDetailsProjectsQuery from 'ee/security_configuration/graphql/scan_profiles/group_scanner_details_projects.query.graphql';
import groupAvailableSecurityScanProfilesQuery from 'ee/security_configuration/graphql/scan_profiles/group_available_security_scan_profiles.query.graphql';
import groupAnalyzerStatusesQuery from 'ee/security_configuration/graphql/scan_profiles/group_analyzer_statuses.query.graphql';
import attachMutation from 'ee/security_configuration/graphql/scan_profiles/security_scan_profile_attach.mutation.graphql';
import detachMutation from 'ee/security_configuration/graphql/scan_profiles/security_scan_profile_detach.mutation.graphql';
import InventoryDashboardFilteredSearchBar from 'ee/security_inventory/components/inventory_dashboard_filtered_search_bar.vue';
import NameCell from 'ee/security_inventory/components/name_cell.vue';
import AttributesCell from 'ee/security_inventory/components/attributes_cell.vue';
import CheckboxCell from 'ee/security_inventory/components/checkbox_cell.vue';
import { MAX_SELECTED_COUNT } from 'ee/security_inventory/constants';
import { smoothScrollTop } from '~/lib/utils/scroll_utils';
import { SCAN_PROFILE_CATEGORIES } from '~/security_configuration/constants';
import ScannerStatusIcon from 'ee/security_configuration/components/scan_profiles/scanner_status_icon.vue';
import {
  ANALYZER_STATUSES_FAILED,
  GROUP_STATUS_ENABLED,
  GROUP_STATUS_FAILED,
  GROUP_STATUS_NOT_ENABLED,
  GROUP_STATUS_PENDING,
  STATUS_NORMALIZATION_MAP,
} from 'ee/security_configuration/constants';
import { ROUTE_REVIEW } from '../enable_scanners_wizard/constants';
import ActionsCell from './actions_cell.vue';
import StatisticsCardRow from './statistics_card_row.vue';
import LastScanCell from './last_scan_cell.vue';
import SourceCell from './source_cell.vue';
import TroubleshootJobDrawer from './troubleshoot_job_drawer.vue';

const PAGE_SIZE = 20;
const TD_CLASS = '!gl-bg-default !gl-align-middle';
const TH_CLASS = 'gl-w-1/6';

// Profile statuses that read as "healthy": they can hide a failed analyzer
// status if we let the profile win. Other profile statuses (warning, failed,
// stale) already convey a concern with a more refined signal than the
// analyzer's raw failed/success, so we prefer the profile in those cases.
// A profile warning, for example, is a failed job with < 3 consecutive
// failures (see ScanProfileStatus::UpdateService#resolve_status).
const HEALTHY_LOOKING_PROFILE_STATUSES = [GROUP_STATUS_ENABLED, GROUP_STATUS_PENDING];

export default {
  name: 'ScannerDetails',
  components: {
    GlButton,
    ScannerStatusIcon,
    PageHeading,
    GlAlert,
    GlDisclosureDropdown,
    GlFormCheckbox,
    GlIcon,
    GlLink,
    GlSprintf,
    GlTable,
    GlKeysetPagination,
    InventoryDashboardFilteredSearchBar,
    NameCell,
    AttributesCell,
    ActionsCell,
    CheckboxCell,
    StatisticsCardRow,
    LastScanCell,
    SourceCell,
    TroubleshootJobDrawer,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [GlToastMixin],
  inject: ['groupFullPath', 'groupId', 'groupName', 'canReadAttributes', 'canApplyProfiles'],
  apollo: {
    availableSecurityScanProfiles: {
      query: groupAvailableSecurityScanProfilesQuery,
      variables() {
        return { fullPath: this.groupFullPath, gitlabRecommended: true };
      },
      update: (data) => data?.group?.availableSecurityScanProfiles ?? [],
    },
    groupAnalyzerStatuses: {
      query: groupAnalyzerStatusesQuery,
      fetchPolicy: 'cache-and-network',
      variables() {
        return { fullPath: this.groupFullPath };
      },
      update: (data) => data?.group?.analyzerStatuses ?? [],
      result() {
        if (!this.scannerStatus) {
          this.handleCardError();
        }
      },
      error() {
        this.handleCardError();
      },
    },
    namespaceSecurityProjects: {
      query: groupScannerDetailsProjectsQuery,
      fetchPolicy: 'cache-and-network',
      variables() {
        const {
          search = '',
          securityAnalyzerFilters = [],
          vulnerabilityCountFilters = [],
          attributeFilters = [],
        } = this.filters;
        return {
          namespaceId: convertToGraphQLId(TYPENAME_GROUP, this.groupId),
          first: this.after || !this.before ? PAGE_SIZE : null,
          after: this.after,
          last: this.before ? PAGE_SIZE : null,
          before: this.before,
          search,
          securityAnalyzerFilters,
          vulnerabilityCountFilters,
          attributeFilters,
          sortBy: this.scannerKey,
          canReadAttributes: this.canReadAttributes,
        };
      },
    },
  },
  data() {
    return {
      availableSecurityScanProfiles: [],
      groupAnalyzerStatuses: [],
      namespaceSecurityProjects: {},
      after: null,
      before: null,
      filters: {},
      hasCardError: false,
      drawerData: null,
      isDrawerOpen: false,
      cardFilter: null,
      selectedItems: [],
    };
  },
  computed: {
    scannerKey() {
      return this.$route.params.scanner_key;
    },
    scannerName() {
      return SCAN_PROFILE_CATEGORIES[this.scannerKey]?.name ?? this.scannerKey;
    },
    defaultProfile() {
      return this.availableSecurityScanProfiles.find(
        (profile) => profile.scanType === this.scannerKey,
      );
    },
    isLoading() {
      return this.$apollo.queries.namespaceSecurityProjects.loading;
    },
    areCardsLoading() {
      return this.$apollo.queries.groupAnalyzerStatuses.loading;
    },
    scannerStatus() {
      return this.groupAnalyzerStatuses.find((status) => status.analyzerType === this.scannerKey);
    },
    statCards() {
      return [
        {
          title: s__('SecurityConfiguration|Enabled'),
          value: this.scannerStatus?.success ?? 0,
          description: sprintf(
            n__(
              'SecurityConfiguration|Project with %{scannerName} running successfully',
              'SecurityConfiguration|Projects with %{scannerName} running successfully',
              this.scannerStatus?.success ?? 0,
            ),
            { scannerName: this.scannerName },
          ),
          filters: {
            securityAnalyzerFilters: [{ analyzerType: this.scannerKey, status: 'SUCCESS' }],
          },
        },
        {
          title: s__('SecurityConfiguration|Not enabled'),
          value: this.scannerStatus?.notConfigured ?? 0,
          description: sprintf(
            n__(
              'SecurityConfiguration|Project without %{scannerName} enabled',
              'SecurityConfiguration|Projects without %{scannerName} enabled',
              this.scannerStatus?.notConfigured ?? 0,
            ),
            {
              scannerName: this.scannerName,
            },
          ),
          filters: {
            securityAnalyzerFilters: [{ analyzerType: this.scannerKey, status: 'NOT_CONFIGURED' }],
          },
        },
        {
          title: s__('SecurityConfiguration|Needs attention'),
          value: this.scannerStatus?.failure ?? 0,
          description: n__(
            'SecurityConfiguration|Project with scan failures',
            'SecurityConfiguration|Projects with scan failures',
            this.scannerStatus?.failure ?? 0,
          ),
          filters: {
            securityAnalyzerFilters: [{ analyzerType: this.scannerKey, status: 'FAILED' }],
          },
        },
        {
          title: s__('SecurityConfiguration|Stale'),
          value: this.scannerStatus?.stale ?? 0,
          description: n__(
            'SecurityConfiguration|Project not scanned in 90+ days',
            'SecurityConfiguration|Projects not scanned in 90+ days',
            this.scannerStatus?.stale ?? 0,
          ),
          filters: {
            securityAnalyzerFilters: [{ analyzerType: this.scannerKey, status: 'STALE' }],
          },
        },
      ];
    },
    projects() {
      return (this.namespaceSecurityProjects.nodes ?? []).map((project) => ({
        ...project,
        scanStatus: this.getStatusForItem(project),
      }));
    },
    pageInfo() {
      return this.namespaceSecurityProjects.pageInfo ?? {};
    },
    headingText() {
      return sprintf(s__('SecurityConfiguration|%{scanner} configuration'), {
        scanner: this.scannerName,
      });
    },
    isEnableScannerLoading() {
      return this.isLoading || this.areCardsLoading;
    },
    hasNotEnabledProjects() {
      if ((this.scannerStatus?.notConfigured ?? 0) > 0) return true;
      return (this.namespaceSecurityProjects.nodes ?? []).some(
        (project) => !this.matchingProfile(project),
      );
    },
    isEnableScannerDisabled() {
      return this.isEnableScannerLoading || !this.hasNotEnabledProjects;
    },
    enableScannerRoute() {
      return this.isEnableScannerDisabled
        ? null
        : { name: ROUTE_REVIEW, query: { scanner: this.scannerKey } };
    },
    enableScannerTooltip() {
      if (this.isEnableScannerLoading || this.hasNotEnabledProjects) return '';
      return s__('SecurityConfiguration|This scanner is already enabled on all projects.');
    },
    profileTooltipText() {
      return sprintf(
        s__(
          'SecurityConfiguration|How %{scannerName} is configured for each project. Management actions on this page are only available for projects using profile-based configuration. Other sources must be managed at their origin.',
        ),
        { scannerName: this.scannerName },
      );
    },
    isAnyItemSelected() {
      return this.selectedItems.length > 0;
    },
    areAllItemsSelected() {
      return this.projects.length > 0 && this.projects.every((item) => this.isSelected(item));
    },
    isSelectAllIndeterminate() {
      return this.isAnyItemSelected && !this.areAllItemsSelected;
    },
    isSelectAllDisabled() {
      return this.isLoading || this.projects.length === 0;
    },
    isSelectedLimitReached() {
      return this.selectedItems.length >= MAX_SELECTED_COUNT;
    },
    selectedCountMessage() {
      return sprintf(
        n__(
          '%{strongStart}%{selectedCount}%{strongEnd} item selected',
          '%{strongStart}%{selectedCount}%{strongEnd} items selected',
          this.selectedItems.length,
        ),
        { selectedCount: this.selectedItems.length },
      );
    },
    bulkActions() {
      return [
        {
          text: s__('SecurityConfiguration|Enable profile-based scanning'),
          action: () => this.bulkEnableProfileScanning(),
        },
        {
          text: s__('SecurityConfiguration|Disable profile-based scanning'),
          action: () => this.bulkDisableProfileScanning(),
          extraAttrs: { class: 'gl-text-danger' },
        },
      ];
    },
    fields() {
      const fields = [];

      if (this.canApplyProfiles) {
        fields.push({
          key: 'checkbox',
          label: '',
          tdClass: `${TD_CLASS} gl-w-0`,
          thClass: 'gl-w-0',
        });
      }

      fields.push(
        {
          key: 'name',
          label: s__('SecurityConfiguration|Project'),
          tdClass: TD_CLASS,
          thClass: TH_CLASS,
        },
        {
          key: 'securityScanProfile',
          label: s__('SecurityConfiguration|Source'),
          tdClass: TD_CLASS,
          thClass: TH_CLASS,
        },
        {
          key: 'analyzerStatus',
          label: s__('SecurityConfiguration|Status'),
          tdClass: TD_CLASS,
          thClass: TH_CLASS,
        },
        {
          key: 'lastScan',
          label: s__('SecurityConfiguration|Last scan'),
          tdClass: TD_CLASS,
          thClass: TH_CLASS,
        },
        {
          key: 'actions',
          label: '',
          tdClass: `${TD_CLASS} gl-text-right`,
          thClass: `${TH_CLASS} !gl-align-middle`,
        },
      );

      if (this.canReadAttributes) {
        fields.splice(-1, 0, {
          key: 'securityAttributes',
          label: s__('SecurityConfiguration|Security attributes'),
          tdClass: TD_CLASS,
          thClass: TH_CLASS,
        });
      }

      return fields;
    },
  },
  methods: {
    isSelected(item) {
      return this.selectedItems.includes(item.id);
    },
    selectItem(item, checked) {
      if (checked) {
        if (this.isSelectedLimitReached) return;
        this.selectedItems.push(item.id);
      } else {
        this.selectedItems = this.selectedItems.filter((id) => id !== item.id);
      }
    },
    selectAll(checked) {
      if (checked) {
        this.selectedItems = this.projects.map((item) => item.id).slice(0, MAX_SELECTED_COUNT);
      } else {
        this.selectedItems = [];
      }
    },
    clearSelection() {
      this.selectedItems = [];
    },
    partitionSelectedIds() {
      return this.selectedItems.reduce(
        (acc, id) => {
          if (id.includes('Group')) acc.groupIds.push(id);
          if (id.includes('Project')) acc.projectIds.push(id);
          return acc;
        },
        { groupIds: [], projectIds: [] },
      );
    },
    confirmDisable(message) {
      return confirmAction(message, {
        primaryBtnText: __('Disable profile-based scanning'),
        primaryBtnVariant: 'danger',
      });
    },
    async runProfileMutation({ mutation, variables, successMessage, errorMessage }) {
      try {
        await this.$apollo.mutate({ mutation, variables });
        this.$toast.show(successMessage);
        this.$apollo.queries.namespaceSecurityProjects.refetch();
        this.$apollo.queries.groupAnalyzerStatuses.refetch();
        return true;
      } catch (error) {
        createAlert({ message: errorMessage, error });
        return false;
      }
    },
    async bulkEnableProfileScanning() {
      if (!this.defaultProfile) {
        this.handleError();
        return;
      }

      const success = await this.runProfileMutation({
        mutation: attachMutation,
        variables: {
          input: {
            securityScanProfileId: this.defaultProfile.id,
            ...this.partitionSelectedIds(),
          },
        },
        successMessage: n__(
          'SecurityConfiguration|Profile-based scanning enabled for %d item',
          'SecurityConfiguration|Profile-based scanning enabled for %d items',
          this.selectedItems.length,
        ),
        errorMessage: s__(
          'SecurityConfiguration|An error occurred while enabling profile-based scanning.',
        ),
      });
      if (success) this.clearSelection();
    },
    async bulkDisableProfileScanning() {
      if (!this.defaultProfile) {
        this.handleError();
        return;
      }

      const confirmed = await this.confirmDisable(
        sprintf(
          n__(
            'SecurityConfiguration|You are about to disable profile-based scanning for %{count} item. Are you sure you want to proceed?',
            'SecurityConfiguration|You are about to disable profile-based scanning for %{count} items. Are you sure you want to proceed?',
            this.selectedItems.length,
          ),
          { count: this.selectedItems.length },
        ),
      );
      if (!confirmed) return;

      const success = await this.runProfileMutation({
        mutation: detachMutation,
        variables: {
          input: {
            securityScanProfileId: this.defaultProfile.id,
            ...this.partitionSelectedIds(),
          },
        },
        successMessage: n__(
          'SecurityConfiguration|Profile-based scanning disabled for %d item',
          'SecurityConfiguration|Profile-based scanning disabled for %d items',
          this.selectedItems.length,
        ),
        errorMessage: s__(
          'SecurityConfiguration|An error occurred while disabling profile-based scanning.',
        ),
      });
      if (success) this.clearSelection();
    },
    handleViewProjects(card) {
      this.cardFilter = card;
      this.filters = { ...card.filters };
      this.after = null;
      this.before = null;
      this.clearSelection();
    },
    clearCardFilter() {
      this.cardFilter = null;
      this.filters = {};
      this.after = null;
      this.before = null;
      this.clearSelection();
    },
    matchingProfile(item) {
      return item.securityScanProfiles?.find((profile) => profile.scanType === this.scannerKey);
    },
    getStatusForItem(item) {
      const profileMatch = item.scanProfileStatuses?.find(
        (s) => s.scanProfile?.scanType === this.scannerKey,
      );
      const analyzerMatch = item.analyzerStatuses?.find((s) => s.analyzerType === this.scannerKey);
      const analyzerStatus = analyzerMatch?.status?.toLowerCase();

      if (profileMatch) {
        const profileStatus = profileMatch.status?.toLowerCase();
        const profileNormalized = STATUS_NORMALIZATION_MAP[profileStatus] ?? profileStatus;

        // An analyzer failure must surface when the profile status looks
        // healthy (enabled/pending). For warning/failed/stale the profile
        // already communicates the concern with more nuance than the raw
        // analyzer status, so we trust it.
        const profileHidesFailure =
          analyzerStatus === ANALYZER_STATUSES_FAILED &&
          HEALTHY_LOOKING_PROFILE_STATUSES.includes(profileNormalized);

        if (profileHidesFailure) {
          return {
            ...profileMatch,
            rawStatus: analyzerStatus,
            status: GROUP_STATUS_FAILED,
            profileStatus: profileNormalized,
            lastScanAt: analyzerMatch.updatedAt,
          };
        }

        return {
          ...profileMatch,
          rawStatus: profileStatus,
          status: profileNormalized,
        };
      }

      if (!analyzerMatch) return { status: GROUP_STATUS_NOT_ENABLED };
      return {
        ...analyzerMatch,
        rawStatus: analyzerStatus,
        status: STATUS_NORMALIZATION_MAP[analyzerStatus] ?? analyzerStatus,
        lastScanAt: analyzerMatch.updatedAt,
      };
    },
    openDrawer(item, jobData = {}) {
      this.drawerData = {
        jobData: { ...jobData },
        buildId: item.scanStatus.buildId,
        status: item.scanStatus.rawStatus,
        fullPath: item.fullPath,
      };
      this.isDrawerOpen = true;
    },
    handleError() {
      createAlert({
        message: s__('SecurityConfiguration|An error occurred managing scan profiles.'),
      });
    },
    handleCardError() {
      if (this.hasCardError) return;

      this.hasCardError = true;
      createAlert({
        message: s__('SecurityConfiguration|Failed to load scanner statistics'),
      });
    },
    async applyDefaultProfile(item) {
      if (!this.defaultProfile) {
        this.handleError();
        return;
      }

      await this.runProfileMutation({
        mutation: attachMutation,
        variables: {
          input: { securityScanProfileId: this.defaultProfile.id, projectIds: [item.id] },
        },
        successMessage: sprintf(
          s__('SecurityConfiguration|Profile-based scanning enabled for %{name}'),
          { name: item.name },
        ),
        errorMessage: s__(
          'SecurityConfiguration|An error occurred while enabling profile-based scanning.',
        ),
      });
    },
    async disableProfile(item) {
      const profile = this.matchingProfile(item);
      if (!profile) {
        this.handleError();
        return;
      }

      const confirmed = await this.confirmDisable(
        sprintf(
          s__(
            'SecurityConfiguration|You are about to disable profile-based scanning for %{name}. Are you sure you want to proceed?',
          ),
          { name: item.name },
        ),
      );
      if (!confirmed) return;

      await this.runProfileMutation({
        mutation: detachMutation,
        variables: { input: { securityScanProfileId: profile.id, projectIds: [item.id] } },
        successMessage: sprintf(
          s__('SecurityConfiguration|Profile-based scanning disabled for %{name}'),
          { name: item.name },
        ),
        errorMessage: s__(
          'SecurityConfiguration|An error occurred while disabling profile-based scanning.',
        ),
      });
    },
    subgroupHref(item) {
      const lastSlashIndex = item.fullPath?.lastIndexOf('/');
      const parentPath = item.fullPath?.substring(0, lastSlashIndex);
      if (!parentPath || parentPath === this.groupFullPath) return '';

      const configurationPath = window.location.pathname.replace(
        `/${this.groupFullPath}/`,
        `/${parentPath}/`,
      );
      return `${configurationPath}#/scanners/${this.scannerKey}`;
    },
    handleFilter(filters) {
      this.filters = filters;
      this.after = null;
      this.before = null;
      this.clearSelection();
    },
    handleNext(endCursor) {
      this.after = endCursor;
      this.before = null;
      smoothScrollTop();
      this.clearSelection();
    },
    handlePrev(startCursor) {
      this.before = startCursor;
      this.after = null;
      smoothScrollTop();
      this.clearSelection();
    },
  },
  MAX_SELECTED_COUNT,
  i18n: {
    selectBulkAction: s__('SecurityConfiguration|Select bulk action'),
    selectAllTitle: __('Select all items'),
    selectLimitReached: __('You can edit up to %{maximumCount} items at once'),
  },
};
</script>
<template>
  <div>
    <page-heading :heading="headingText" />
    <div class="gl-mb-4 gl-flex gl-items-start gl-justify-between gl-gap-3">
      <span>
        <gl-sprintf
          :message="
            s__(
              'SecurityConfiguration|View and manage %{scanner} configuration across projects in the %{group} group.',
            )
          "
        >
          <template #scanner>
            {{ scannerName }}
          </template>
          <template #group>
            <gl-link :href="`/${groupFullPath}`">{{ groupName }}</gl-link>
          </template>
        </gl-sprintf>
      </span>
      <span
        v-gl-tooltip="enableScannerTooltip"
        class="gl-inline-block gl-shrink-0"
        data-testid="enable-scanner-button-wrapper"
      >
        <gl-button
          category="primary"
          variant="confirm"
          :to="enableScannerRoute"
          :disabled="isEnableScannerDisabled"
          data-testid="enable-scanner-button"
        >
          {{ s__('SecurityConfiguration|Enable scanner') }}
        </gl-button>
      </span>
    </div>

    <statistics-card-row
      :cards="statCards"
      :loading="areCardsLoading"
      :error="hasCardError"
      @view-projects="handleViewProjects"
    />

    <gl-alert
      v-if="cardFilter"
      variant="info"
      class="gl-mb-4"
      :title="cardFilter.title"
      @dismiss="clearCardFilter"
    >
      {{
        s__(
          'SecurityConfiguration|Showing projects that match this statistic. Dismiss to view all.',
        )
      }}
    </gl-alert>
    <inventory-dashboard-filtered-search-bar
      v-else
      :namespace="groupFullPath"
      class="gl-mb-4"
      @filter-subgroups-and-projects="handleFilter"
    />

    <div
      v-if="canApplyProfiles && isAnyItemSelected"
      data-testid="bulk-selection-bar"
      class="gl-border gl-mb-4 gl-flex gl-items-center gl-justify-between gl-rounded-base gl-border-default gl-bg-default gl-px-4 gl-py-3"
    >
      <span>
        <gl-sprintf :message="selectedCountMessage">
          <template #strong="{ content }">
            <strong>{{ content }}</strong>
          </template>
        </gl-sprintf>
        <gl-icon
          v-if="isSelectedLimitReached"
          v-gl-tooltip="
            sprintf($options.i18n.selectLimitReached, { maximumCount: $options.MAX_SELECTED_COUNT })
          "
          name="warning"
          variant="warning"
          class="gl-ml-2"
        />
      </span>
      <gl-disclosure-dropdown
        data-testid="bulk-actions-dropdown"
        :toggle-text="$options.i18n.selectBulkAction"
        :items="bulkActions"
        placement="bottom-end"
      />
    </div>

    <gl-table
      :fields="fields"
      :items="projects"
      :busy="isLoading"
      table-class="!gl-bg-strong gl-rounded-xl gl-table-fixed"
      show-empty
      borderless
    >
      <template v-if="canApplyProfiles" #head(checkbox)>
        <gl-form-checkbox
          v-gl-tooltip.right
          :title="$options.i18n.selectAllTitle"
          :checked="isAnyItemSelected"
          :indeterminate="isSelectAllIndeterminate"
          :disabled="isSelectAllDisabled"
          class="gl-min-h-4"
          data-testid="bulk-select-all-checkbox"
          @change="selectAll"
        />
      </template>
      <template v-if="canApplyProfiles" #cell(checkbox)="{ item }">
        <checkbox-cell
          :item="item"
          :is-selected="isSelected(item)"
          :is-selected-limit-reached="isSelectedLimitReached"
          @select-item="selectItem"
        />
      </template>
      <template #cell(name)="{ item }">
        <name-cell :item="item" show-search-param :subgroup-href="subgroupHref(item)" />
      </template>
      <template #head(securityScanProfile)="{ label }">
        <div class="gl-flex gl-items-center">
          <span>{{ label }}</span>
          <gl-icon
            v-gl-tooltip
            :title="profileTooltipText"
            name="information-o"
            variant="info"
            class="gl-ml-2"
          />
        </div>
      </template>
      <template #cell(securityScanProfile)="{ item }">
        <source-cell :item="item" :scanner-key="scannerKey" />
      </template>
      <template #cell(analyzerStatus)="{ item }">
        <scanner-status-icon
          data-testid="status-icon"
          class="gl-self-start"
          :status="item.scanStatus.status"
          :profile-status="item.scanStatus.profileStatus"
          :consecutive-success-count="item.scanStatus.consecutiveSuccessCount"
          :consecutive-failure-count="item.scanStatus.consecutiveFailureCount"
        />
      </template>
      <template #cell(lastScan)="{ item }">
        <last-scan-cell
          :target-id="`scanner-details-${item.id}`"
          :last-scan-at="item.scanStatus?.lastScanAt"
          :build-id="item.scanStatus?.buildId"
          :status="item.scanStatus?.rawStatus"
          :project-full-path="item.fullPath"
          link-variant="pipeline-job"
          @open-drawer="openDrawer(item, $event)"
        />
      </template>
      <template #cell(securityAttributes)="{ item, index }">
        <attributes-cell :item="item" :index="index" />
      </template>
      <template #cell(actions)="{ item }">
        <actions-cell
          :item="item"
          :has-profile="Boolean(matchingProfile(item))"
          @apply-profile="applyDefaultProfile(item)"
          @disable-profile="disableProfile(item)"
          @troubleshoot-failure="openDrawer(item)"
        />
      </template>
    </gl-table>

    <div
      v-if="pageInfo.hasNextPage || pageInfo.hasPreviousPage"
      class="gl-mt-5 gl-flex gl-justify-center"
    >
      <gl-keyset-pagination v-bind="pageInfo" @prev="handlePrev" @next="handleNext" />
    </div>

    <troubleshoot-job-drawer
      v-if="isDrawerOpen"
      :job-data="drawerData.jobData"
      :build-id="drawerData.buildId"
      :scan-type="scannerKey"
      :status="drawerData.status"
      :full-path="drawerData.fullPath"
      :open-drawer="isDrawerOpen"
      @close-drawer="isDrawerOpen = false"
    />
  </div>
</template>
