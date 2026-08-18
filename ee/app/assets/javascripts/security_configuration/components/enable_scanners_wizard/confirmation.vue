<script>
import { GlEmptyState, GlButton, GlSprintf, GlCard, GlTable, GlIcon } from '@gitlab/ui';
import confirmationSvgPath from '@gitlab/svgs/dist/illustrations/empty-state/empty-devops-md.svg?url';
import { __, s__, n__, sprintf } from '~/locale';
import ScanTypeCell from '~/security_configuration/components/scan_profiles/scan_type_cell.vue';

export default {
  name: 'EnableScannersConfirmation',
  components: {
    GlEmptyState,
    GlButton,
    GlSprintf,
    GlCard,
    GlTable,
    GlIcon,
    ScanTypeCell,
  },
  inject: ['enableScanners'],
  computed: {
    projectCount() {
      return this.enableScanners.selectedItems.length;
    },
    rolloutMessage() {
      if (this.enableScanners.areAllItemsSelected) {
        return s__(
          'SecurityConfiguration|Your configuration has been applied and is rolling out to projects in batches. Profiles will be applied to %{strongStart}all uncovered projects%{strongEnd} as each batch completes — this may take a few minutes.',
        );
      }

      return sprintf(
        s__(
          'SecurityConfiguration|Your configuration has been applied and is rolling out to projects in batches. Profiles will be applied to %{strongStart}%{itemCount}%{strongEnd} as each batch completes — this may take a few minutes.',
        ),
        {
          itemCount: n__('%d item', '%d items', this.projectCount),
        },
        false,
      );
    },
  },
  confirmationSvgPath,
  tableFields: [
    { key: 'scanType', label: __('Scanner'), tdClass: '!gl-bg-transparent !gl-align-middle' },
    { key: 'name', label: __('Profile'), tdClass: '!gl-bg-transparent !gl-align-middle' },
    { key: 'items', label: __('Items'), tdClass: '!gl-bg-transparent !gl-align-middle' },
  ],
};
</script>
<template>
  <div>
    <gl-empty-state
      :title="s__('SecurityConfiguration|Security scanning is rolling out')"
      :svg-path="$options.confirmationSvgPath"
    >
      <template #description>
        <gl-sprintf :message="rolloutMessage">
          <template #strong="{ content }">
            <strong>{{ content }}</strong>
          </template>
        </gl-sprintf>
      </template>
      <template #actions>
        <gl-button category="primary" variant="confirm" to="/">{{
          s__('SecurityConfiguration|Go to security configuration')
        }}</gl-button>
      </template>
    </gl-empty-state>

    <gl-card class="gl-mt-5">
      <template #header>
        <span class="gl-flex gl-items-center gl-gap-2">
          <gl-icon name="project" />
          <strong>{{ s__('SecurityConfiguration|Configuration applied') }}</strong>
        </span>
      </template>
      <gl-table
        :fields="$options.tableFields"
        :items="enableScanners.selectedScanners"
        table-class="!gl-bg-transparent !gl-border-collapse"
        borderless
      >
        <template #cell(scanType)="{ item }">
          <scan-type-cell :scan-type="item.scanType" :is-configured="false" solid />
        </template>
        <template #cell(items)>
          {{ enableScanners.areAllItemsSelected ? __('All') : projectCount }}
        </template>
      </gl-table>
    </gl-card>
  </div>
</template>
