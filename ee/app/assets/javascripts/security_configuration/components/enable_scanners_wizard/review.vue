<script>
import { GlSingleStat } from '@gitlab/ui/src/charts';
import { GlCard, GlIcon, GlButton, GlTableLite, GlTooltipDirective, GlLink } from '@gitlab/ui';
import { __ } from '~/locale';
import NameCell from 'ee/security_inventory/components/name_cell.vue';
import ScanProfileDetailsModal from 'ee/security_configuration/components/scan_profiles/scan_profile_details_modal.vue';
import ScanTypeCell from '~/security_configuration/components/scan_profiles/scan_type_cell.vue';
import { ROUTE_ITEMS, ROUTE_SCANNERS, APPROACH_ADVANCED } from './constants';

export default {
  name: 'EnableScannersReview',
  components: {
    GlSingleStat,
    GlCard,
    GlIcon,
    GlButton,
    GlTableLite,
    GlLink,
    NameCell,
    ScanProfileDetailsModal,
    ScanTypeCell,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  inject: ['enableScanners'],
  data() {
    return {
      previewProfile: null,
    };
  },
  methods: {
    openPreview(profile) {
      this.previewProfile = profile;
    },
    closePreview() {
      this.previewProfile = null;
    },
  },
  ROUTE_ITEMS,
  ROUTE_SCANNERS,
  APPROACH_ADVANCED,
  projectFields: [
    { key: 'name', label: __('Item'), thClass: 'gl-w-1/2' },
    { key: 'group', label: __('Group'), thClass: 'gl-w-1/2' },
  ],
  scannerFields: [
    { key: 'scanType', label: __('Scanner'), thClass: 'gl-w-1/2', tdClass: '!gl-align-middle' },
    { key: 'name', label: __('Profile'), thClass: 'gl-w-1/2', tdClass: '!gl-align-middle' },
  ],
};
</script>
<template>
  <div>
    <div class="gl-my-5 gl-grid gl-grid-cols-2 gl-gap-5">
      <gl-card>
        <template #header>
          <strong>{{ s__('SecurityConfiguration|Items impacted') }}</strong>
        </template>
        <gl-single-stat
          title=""
          data-testid="items-impacted-stat"
          :value="
            enableScanners.areAllItemsSelected
              ? __('All')
              : `${enableScanners.selectedItems.length}`
          "
        />
      </gl-card>
      <gl-card>
        <template #header>
          <strong>{{ s__('SecurityConfiguration|Scanners configured') }}</strong>
        </template>
        <gl-single-stat
          title=""
          data-testid="scanners-configured-stat"
          :value="enableScanners.selectedScanners.length"
        />
      </gl-card>
    </div>

    <gl-card class="gl-my-5">
      <template #header>
        <div class="gl-flex gl-items-center gl-justify-between">
          <span class="gl-flex gl-items-center gl-gap-2">
            <gl-icon name="project" />
            <strong>{{ __('Items') }}</strong>
          </span>
          <gl-button
            v-if="enableScanners.approach === $options.APPROACH_ADVANCED"
            v-gl-tooltip
            :title="s__('SecurityConfiguration|Edit project scope')"
            icon="pencil"
            category="tertiary"
            size="small"
            :to="{ name: $options.ROUTE_ITEMS }"
          />
        </div>
      </template>
      <p v-if="enableScanners.areAllItemsSelected" class="gl-m-3">
        {{ s__('SecurityConfiguration|All uncovered projects are selected.') }}
      </p>
      <gl-table-lite
        v-else
        :fields="$options.projectFields"
        :items="enableScanners.selectedItems"
        table-class="!gl-bg-transparent"
        data-testid="items-table"
        borderless
      >
        <template #cell(name)="{ item }">
          <name-cell :item="item" />
        </template>
        <template #cell(group)="{ item }">
          <gl-link :href="item.group.webPath" target="_blank">
            {{ item.group.name }}
          </gl-link>
        </template>
      </gl-table-lite>
    </gl-card>

    <gl-card class="gl-my-5">
      <template #header>
        <div class="gl-flex gl-items-center gl-justify-between">
          <span class="gl-flex gl-items-center gl-gap-2">
            <gl-icon name="shield" />
            <strong>{{ __('Scanners') }}</strong>
          </span>
          <gl-button
            v-if="enableScanners.approach === $options.APPROACH_ADVANCED"
            v-gl-tooltip
            :title="s__('SecurityConfiguration|Edit scanners')"
            icon="pencil"
            category="tertiary"
            size="small"
            :to="{ name: $options.ROUTE_SCANNERS }"
          />
        </div>
      </template>
      <gl-table-lite
        :fields="$options.scannerFields"
        :items="enableScanners.selectedScanners"
        table-class="!gl-bg-transparent"
        data-testid="scanners-table"
        borderless
      >
        <template #cell(scanType)="{ item }">
          <scan-type-cell :scan-type="item.scanType" solid />
        </template>
        <template #cell(name)="{ item }">
          <gl-button variant="link" data-testid="preview-profile-link" @click="openPreview(item)">
            {{ item.name }}
          </gl-button>
        </template>
      </gl-table-lite>
    </gl-card>

    <scan-profile-details-modal
      :profile-id="previewProfile?.id ?? ''"
      :scan-type="previewProfile?.scanType ?? ''"
      :visible="Boolean(previewProfile)"
      :with-apply-action="false"
      @close="closePreview"
    />
  </div>
</template>
