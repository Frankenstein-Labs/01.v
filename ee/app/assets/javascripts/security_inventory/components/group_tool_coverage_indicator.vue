<script>
import { GlPopover } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import { itemValidator } from 'ee/security_inventory/utils';
import {
  SCANNER_TYPES,
  SCANNER_POPOVER_GROUPS,
  SAST_ADVANCED_KEY,
  CONTAINER_SCANNING_FOR_REGISTRY_KEY,
  SECRET_DETECTION_KEY,
  SECRET_DETECTION_PIPELINE_BASED_KEY,
  SECRET_PUSH_PROTECTION_KEY,
} from '../constants';
import GroupToolCoverageDetails from './group_tool_coverage_details.vue';
import SegmentedBar from './segmented_bar.vue';

export default {
  components: {
    GroupToolCoverageDetails,
    SegmentedBar,
    GlPopover,
  },
  props: {
    item: {
      type: Object,
      required: true,
      validator: (value) => itemValidator(value),
    },
  },
  computed: {
    scannerSegments() {
      return Object.fromEntries(
        Object.entries(this.$options.SCANNER_POPOVER_GROUPS).map(([key, value]) => [
          key,
          this.buildCoverageSegments(value),
        ]),
      );
    },
  },
  methods: {
    buildCoverageSegments(value) {
      const aggregatedData = this.aggregateScannerData(value);
      return [
        { class: 'gl-bg-green-500', count: aggregatedData.success || 0 },
        { class: 'gl-bg-red-500', count: aggregatedData.failure || 0 },
        { class: 'gl-bg-neutral-600', count: aggregatedData.stale || 0 },
        { class: 'gl-bg-neutral-200', count: aggregatedData.notConfigured || 0 },
      ];
    },
    getLabel(key) {
      return SCANNER_TYPES[key].textLabel;
    },
    getToolCoverageTitle() {
      return s__('ToolCoverage|Project coverage');
    },
    getCalculatedCoverage(scannerTypes) {
      const aggregatedData = this.aggregateScannerData(scannerTypes);
      return `${aggregatedData.success + aggregatedData.failure} ${__('of')} ${aggregatedData.notConfigured}`;
    },
    aggregateScannerData(scannerTypes) {
      if (!scannerTypes || scannerTypes.length === 0) return {};
      const relevantScannerTypes = scannerTypes
        /**
         *  While we're counting the sum of two types 'SAST' and 'SAST_ADVANCED', we encountered a bug and double number of projects were displayed under a group.
         * To fix that, we filter out the 'SAST_ADVANCED' type.
         * After merging https://gitlab.com/gitlab-org/gitlab/-/issues/548276, we need to remove this filter. */
        .filter((type) => type !== SAST_ADVANCED_KEY)
        // Now that container scanning values are backfilled, there's no need to merge them any more
        .filter((type) => type !== CONTAINER_SCANNING_FOR_REGISTRY_KEY)
        // The backend combines the two secret detection types into just SECRET_DETECTION, so
        // filter out one of them and map the other to the right key
        .filter((type) => type !== SECRET_DETECTION_PIPELINE_BASED_KEY)
        .map((type) => (type === SECRET_PUSH_PROTECTION_KEY ? SECRET_DETECTION_KEY : type))
        .map((type) => {
          const existingScanner = this.item.analyzerStatuses.find(
            (scanner) => scanner.analyzerType === type,
          );
          return existingScanner || { analyzerType: type };
        });
      const aggregated = relevantScannerTypes.reduce(
        (acc, curr) => ({
          failure: (acc.failure || 0) + (curr.failure || 0),
          stale: (acc.stale || 0) + (curr.stale || 0),
          success: (acc.success || 0) + (curr.success || 0),
          notConfigured: (acc.notConfigured || 0) + (curr.notConfigured || 0),
        }),
        {},
      );
      const mostRecentDate = relevantScannerTypes
        .filter(({ updatedAt }) => updatedAt)
        .sort(
          (currentDate, latestDate) =>
            new Date(latestDate.updatedAt) - new Date(currentDate.updatedAt),
        )[0]?.updatedAt;

      return {
        ...aggregated,
        analyzerType: relevantScannerTypes[0].analyzerType,
        updatedAt: mostRecentDate,
      };
    },
  },
  SCANNER_POPOVER_GROUPS,
};
</script>

<template>
  <div class="gl-flex gl-flex-row gl-flex-wrap gl-gap-2">
    <div v-for="(value, key) in $options.SCANNER_POPOVER_GROUPS" :key="key" class="gl-w-8">
      <segmented-bar
        :id="`${key}-${item.path}-bar`"
        :aria-labelledby="`${key}-${item.path}-label`"
        :segments="scannerSegments[key]"
        class="gl-mb-1"
        :data-testid="`${key}-${item.path}-bar`"
      />
      <span
        :id="`${key}-${item.path}-label`"
        class="gl-text-sm gl-text-status-neutral"
        :data-testid="`${key}-${item.path}-label`"
      >
        {{ getLabel(key) }}
        <span class="gl-sr-only">
          {{
            sprintf(s__('SecurityInventory|Tool coverage: %{coverage}'), {
              coverage: getCalculatedCoverage(value),
            })
          }}
        </span>
      </span>
      <gl-popover
        :title="getToolCoverageTitle()"
        :target="`${key}-${item.path}-bar`"
        :data-testid="`popover-${key}-bar`"
        show-close-button
      >
        <group-tool-coverage-details :security-scanner="aggregateScannerData(value)" />
      </gl-popover>
    </div>
  </div>
</template>
