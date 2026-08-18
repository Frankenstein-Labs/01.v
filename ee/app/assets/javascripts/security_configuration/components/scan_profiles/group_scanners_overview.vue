<script>
import {
  GlIcon,
  GlLink,
  GlSkeletonLoader,
  GlSprintf,
  GlTable,
  GlButton,
  GlTooltipDirective,
} from '@gitlab/ui';
import { __, s__, n__, sprintf, createListFormat } from '~/locale';
import { createAlert } from '~/alert';
import ScanTypeCell from '~/security_configuration/components/scan_profiles/scan_type_cell.vue';
import SegmentedBar from 'ee/security_inventory/components/segmented_bar.vue';
import groupAvailableSecurityScanProfilesQuery from 'ee/security_configuration/graphql/scan_profiles/group_available_security_scan_profiles.query.graphql';
import groupAnalyzerStatusesQuery from 'ee/security_configuration/graphql/scan_profiles/group_analyzer_statuses.query.graphql';
import groupSecurityPostureCountersQuery from 'ee/security_configuration/graphql/scan_profiles/group_security_posture_counters.query.graphql';
import {
  SCAN_PROFILE_SCANNER_HEALTH_PENDING,
  SCAN_PROFILE_CATEGORIES,
} from '~/security_configuration/constants';
import { ROUTE_ENABLE_SCANNERS } from '../enable_scanners_wizard/constants';
import StatisticsCardRow from './statistics_card_row.vue';
import ProjectsListModal from './projects_list_modal.vue';

export default {
  name: 'GroupScannersOverview',
  components: {
    GlLink,
    GlSkeletonLoader,
    GlSprintf,
    GlIcon,
    GlTable,
    GlButton,
    ScanTypeCell,
    SegmentedBar,
    StatisticsCardRow,
    ProjectsListModal,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  inject: ['groupFullPath', 'securityInventoryPath'],
  apollo: {
    availableScanners: {
      query: groupAvailableSecurityScanProfilesQuery,
      variables() {
        return { fullPath: this.groupFullPath };
      },
      update: (data) => {
        // Sort recommended profiles last so they win the Map dedupe below,
        // regardless of API response order.
        const prioritized = (data?.group?.availableSecurityScanProfiles ?? [])
          .filter((profile) => Boolean(SCAN_PROFILE_CATEGORIES[profile.scanType]))
          .sort((a, b) => Number(a.gitlabRecommended) - Number(b.gitlabRecommended));
        return Array.from(
          new Map(prioritized.map((profile) => [profile.scanType, profile])).values(),
        );
      },
    },
    groupAnalyzerStatuses: {
      query: groupAnalyzerStatusesQuery,
      fetchPolicy: 'cache-and-network',
      variables() {
        return { fullPath: this.groupFullPath };
      },
      update: (data) => data?.group?.analyzerStatuses ?? [],
      error() {
        this.handleCardError();
      },
    },
    securityPostureCounters: {
      query: groupSecurityPostureCountersQuery,
      fetchPolicy: 'cache-and-network',
      variables() {
        return { fullPath: this.groupFullPath };
      },
      update: (data) => data?.group?.securityPostureCounters ?? {},
      error() {
        this.handleCardError();
      },
    },
  },
  data() {
    return {
      availableScanners: [],
      groupAnalyzerStatuses: [],
      securityPostureCounters: {},
      hasCardError: false,
      selectedFilters: {},
      selectedTitle: '',
    };
  },
  computed: {
    isScannerListLoading() {
      return this.$apollo.queries.availableScanners.loading;
    },
    isScannerStatusLoading() {
      return this.$apollo.queries.groupAnalyzerStatuses.loading;
    },
    areCardsLoading() {
      return this.isScannerStatusLoading || this.$apollo.queries.securityPostureCounters.loading;
    },
    statusByType() {
      return Object.fromEntries(
        this.groupAnalyzerStatuses.map((status) => [status.analyzerType, status]),
      );
    },
    totalProjectsCount() {
      return this.groupAnalyzerStatuses[0]?.totalProjectsCount ?? 0;
    },
    unprotectedProjectsCount() {
      return Math.max(
        this.totalProjectsCount - (this.securityPostureCounters.withScanners ?? 0),
        0,
      );
    },
    totalScannersCount() {
      return this.availableScanners.length;
    },
    enabledScannersCount() {
      return this.availableScanners.filter((scanner) => {
        const { notConfigured = 0, totalProjectsCount = 0 } =
          this.statusByType[scanner.scanType] ?? {};
        return notConfigured < totalProjectsCount;
      }).length;
    },
    isEnableScannersLoading() {
      return this.isScannerStatusLoading || this.isScannerListLoading;
    },
    hasScannersToEnable() {
      return this.availableScanners.some((scanner) => {
        const { notConfigured = 0 } = this.statusByType[scanner.scanType] ?? {};
        return notConfigured > 0;
      });
    },
    isEnableScannersDisabled() {
      return this.isEnableScannersLoading || !this.hasScannersToEnable;
    },
    enableScannersRoute() {
      return this.isEnableScannersDisabled ? null : { name: this.$options.ROUTE_ENABLE_SCANNERS };
    },
    enableScannersTooltip() {
      if (this.isEnableScannersLoading || this.hasScannersToEnable) return '';
      return s__('SecurityConfiguration|All scanners are already enabled on all projects.');
    },
    coverageTooltipText() {
      return s__(
        'SecurityConfiguration|Show scanner coverage across all configuration methods, including security policies, CI configuration, and configuration profiles.',
      );
    },
    statCards() {
      return [
        {
          title: s__('SecurityConfiguration|Unprotected projects'),
          value: this.unprotectedProjectsCount,
          description: sprintf(
            s__(
              'SecurityConfiguration|%{protectedCount} of %{totalCount} projects have scanners enabled',
            ),
            {
              protectedCount: this.securityPostureCounters.withScanners ?? 0,
              totalCount: this.totalProjectsCount,
            },
          ),
          filters: { hasScanners: false },
        },
        {
          title: s__('SecurityConfiguration|Scanners enabled'),
          value: sprintf(s__('SecurityConfiguration|%{enabledCount} of %{totalCount}'), {
            enabledCount: this.enabledScannersCount,
            totalCount: this.totalScannersCount,
          }),
          description: n__(
            'SecurityConfiguration|%d scanner not enabled',
            'SecurityConfiguration|%d scanners not enabled',
            this.totalScannersCount - this.enabledScannersCount,
          ),
          linkText: s__('SecurityConfiguration|Enable scanners'),
          to: { name: this.$options.ROUTE_ENABLE_SCANNERS },
        },
        {
          title: s__('SecurityConfiguration|Needs attention'),
          value: this.securityPostureCounters.withFailures ?? 0,
          description: n__(
            'SecurityConfiguration|Project with scan failures',
            'SecurityConfiguration|Projects with scan failures',
            this.securityPostureCounters.withFailures ?? 0,
          ),
          filters: { hasFailedOrWarning: true },
        },
        {
          title: s__('SecurityConfiguration|Stale scans'),
          value: this.securityPostureCounters.withStale ?? 0,
          description: n__(
            'SecurityConfiguration|Project not scanned in 90+ days',
            'SecurityConfiguration|Projects not scanned in 90+ days',
            this.securityPostureCounters.withStale ?? 0,
          ),
          filters: { hasStale: true },
        },
      ];
    },
  },
  methods: {
    handleProjectsModalOpen(card) {
      this.selectedFilters = card.filters ?? {};
      this.selectedTitle = card.title;
      this.$refs.projectsModal.show();
    },
    handleProjectsModalClose() {
      this.selectedFilters = {};
      this.selectedTitle = '';
    },
    handleCardError() {
      if (this.hasCardError) return;

      this.hasCardError = true;
      createAlert({
        message: s__('SecurityConfiguration|Failed to load scanner statistics'),
      });
    },
    coverageSegments(item) {
      const status = this.statusByType[item.scanType];
      return [
        {
          class: 'gl-bg-green-500',
          count: status?.success ?? 0,
          template: __('%{count} active'),
        },
        {
          class: 'gl-bg-red-500',
          count: status?.failure ?? 0,
          template: __('%{count} failed'),
        },
        {
          class: 'gl-bg-neutral-600',
          count: status?.stale ?? 0,
          template: __('%{count} stale'),
        },
        {
          class: 'gl-bg-status-neutral',
          count: status?.notConfigured ?? 0,
        },
      ];
    },
    coveragePercentage(item) {
      const {
        success = 0,
        failure = 0,
        stale = 0,
        notConfigured = 0,
      } = this.statusByType[item.scanType] ?? {};
      const total = success + failure + stale + notConfigured;
      return total === 0 ? '0%' : `${Math.round((success / total) * 100)}%`;
    },
    coverageSegmentsText(item) {
      const list = this.coverageSegments(item)
        .filter(({ count, template }) => count && template)
        .map(({ count, template }) => sprintf(template, { count }));

      return createListFormat({ style: 'narrow' }).format(list);
    },
  },
  fields: [
    {
      key: 'scanType',
      label: s__('SecurityConfiguration|Scanner'),
      tdClass: '!gl-bg-default !gl-border-none',
      thClass: 'gl-w-3/8',
    },
    {
      key: 'coverage',
      label: s__('SecurityConfiguration|Project coverage'),
      tdClass: '!gl-bg-default !gl-border-none !gl-align-middle',
      thClass: 'gl-w-1/2',
    },
    {
      key: 'actions',
      label: '',
      tdClass: '!gl-bg-default !gl-border-none gl-text-right',
      thClass: 'gl-w-1/8',
    },
  ],
  SCAN_PROFILE_SCANNER_HEALTH_PENDING,
  ROUTE_ENABLE_SCANNERS,
};
</script>

<template>
  <div>
    <div class="gl-mb-4 gl-mt-3 gl-flex gl-items-start gl-justify-between">
      <span class="gl-my-2">
        <gl-sprintf
          :message="
            s__(
              'SecurityConfiguration|Enable scanners, monitor health, and track coverage across your projects. For full tool coverage, visit the %{linkStart}Security Inventory%{linkEnd}.',
            )
          "
        >
          <template #link="{ content }">
            <gl-link :href="securityInventoryPath">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </span>
      <span
        v-gl-tooltip="enableScannersTooltip"
        class="gl-inline-block gl-shrink-0"
        data-testid="enable-scanners-button-wrapper"
      >
        <gl-button
          category="primary"
          variant="confirm"
          :to="enableScannersRoute"
          :disabled="isEnableScannersDisabled"
          data-testid="enable-scanners-button"
        >
          {{ s__('SecurityConfiguration|Enable scanners') }}
        </gl-button>
      </span>
    </div>

    <statistics-card-row
      :cards="statCards"
      :loading="areCardsLoading"
      :error="hasCardError"
      @view-projects="handleProjectsModalOpen"
    />

    <projects-list-modal
      ref="projectsModal"
      :filters="selectedFilters"
      :title="selectedTitle"
      @hidden="handleProjectsModalClose"
    />

    <gl-table
      :fields="$options.fields"
      :items="availableScanners"
      :busy="isScannerListLoading"
      show-empty
      table-class="!gl-bg-strong gl-rounded-xl"
      borderless
    >
      <template #empty>
        <div class="gl-py-6 gl-text-center">
          <p class="gl-mb-2 gl-font-bold">
            {{ s__('SecurityConfiguration|No scanners enabled yet') }}
          </p>
          <p class="gl-mb-0 gl-text-subtle">
            {{
              s__(
                'SecurityConfiguration|Enable security scanning to automatically detect vulnerabilities in your projects.',
              )
            }}
          </p>
        </div>
      </template>
      <template #head(coverage)="{ label }">
        <div class="gl-flex gl-items-center">
          <span>{{ label }}</span>
          <gl-icon
            v-gl-tooltip
            :title="coverageTooltipText"
            name="information-o"
            variant="info"
            class="gl-ml-2"
            data-testid="coverage-header-info-icon"
          />
        </div>
      </template>
      <template #cell(scanType)="{ item }">
        <scan-type-cell
          :scan-type="item.scanType"
          :status="$options.SCAN_PROFILE_SCANNER_HEALTH_PENDING"
        />
      </template>
      <template #cell(coverage)="{ item }">
        <gl-skeleton-loader
          v-if="isScannerStatusLoading"
          :width="300"
          :height="10"
          preserve-aspect-ratio="none"
        >
          <rect x="0" y="0" width="300" height="10" rx="5" />
        </gl-skeleton-loader>
        <template v-else>
          <segmented-bar :segments="coverageSegments(item)" />
          <div class="gl-flex gl-justify-between">
            <span class="gl-text-sm gl-text-status-neutral">
              {{ coveragePercentage(item) }}
            </span>
            <span class="gl-text-sm gl-text-status-neutral">
              {{ coverageSegmentsText(item) }}
            </span>
          </div>
        </template>
      </template>
      <template #cell(actions)="{ item }">
        <gl-button
          :to="{ name: 'scanner_details', params: { scanner_key: item.scanType } }"
          data-testid="view-details-button"
          >{{ __('View details') }}</gl-button
        >
      </template>
    </gl-table>
  </div>
</template>
