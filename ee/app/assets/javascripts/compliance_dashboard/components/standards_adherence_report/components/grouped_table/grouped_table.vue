<script>
import { GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';

import { GROUP_BY } from '../../constants';
import FrameworkBadge from '../../../shared/framework_badge.vue';

import GroupedPart from './grouped_part.vue';
import TablePart from './table_part.vue';

const BANNED_FIELD = {
  [GROUP_BY.REQUIREMENTS]: 'requirement',
  [GROUP_BY.FRAMEWORKS]: 'framework',
  [GROUP_BY.PROJECTS]: 'project',
};

const FIELD_WIDTHS = {
  null: {
    requirement: '@md/panel:gl-w-3/20',
    framework: '@md/panel:gl-w-3/20',
    project: '@md/panel:gl-w-4/20',
  },
  [GROUP_BY.REQUIREMENTS]: {
    framework: '@md/panel:gl-w-5/20',
    project: '@md/panel:gl-w-5/20',
  },
  [GROUP_BY.FRAMEWORKS]: {
    requirement: '@md/panel:gl-w-5/20',
    project: '@md/panel:gl-w-5/20',
  },
  [GROUP_BY.PROJECTS]: {
    requirement: '@md/panel:gl-w-5/20',
    framework: '@md/panel:gl-w-5/20',
  },
};

const tableHeaders = {
  status: s__('ComplianceStandardsAdherence|Status'),
  requirement: s__('ComplianceStandardsAdherence|Requirement'),
  framework: s__('ComplianceStandardsAdherence|Framework'),
  project: s__('ComplianceStandardsAdherence|Project'),
  lastScanned: s__('ComplianceStandardsAdherence|Last scanned'),
  fixSuggestions: s__('ComplianceStandardsAdherence|Fix suggestions'),
};

const column = (options) => ({
  label: tableHeaders[options.key],
  sortable: false,
  ...options,
  thClass: options.tdClass || '',
  tdClass: options.tdClass || '',
});

export default {
  components: {
    GlSprintf,

    TablePart,
    GroupedPart,
    FrameworkBadge,
  },
  props: {
    items: {
      type: Array,
      required: true,
    },
    groupBy: {
      type: String,
      required: false,
      default: null,
    },
  },
  emits: ['row-selected'],
  computed: {
    fields() {
      const widths = FIELD_WIDTHS[this.groupBy];
      const bannedField = BANNED_FIELD[this.groupBy] ?? null;
      const basicColumns = [
        column({
          key: 'status',
          tdClass: '@md/panel:gl-w-4/20',
        }),
        column({ key: 'requirement', tdClass: widths.requirement }),
        column({ key: 'framework', tdClass: widths.framework }),
        column({ key: 'project', tdClass: widths.project }),
        column({ key: 'lastScanned', tdClass: '@md/panel:gl-w-3/20' }),
        column({ key: 'fixSuggestions', tdClass: '@md/panel:gl-w-3/20' }),
      ].filter((field) => field.key !== bannedField);

      return basicColumns;
    },
  },
  i18n: {
    viewDetails: s__('ComplianceStandardsAdherence|View details'),
    failedControls: s__('ComplianceStandardsAdherence|%{failedCount} failed'),
  },
  EMPTY_ARRAY: [],
  GROUP_BY,
};
</script>

<template>
  <div>
    <table-part
      v-if="!groupBy"
      :items="items[0].children"
      :fields="fields"
      @row-selected="$emit('row-selected', $event)"
    />
    <template v-else>
      <table-part :fields="fields" :items="$options.EMPTY_ARRAY" />
      <grouped-part v-for="item in items" :key="item.id">
        <template #header>
          <div class="gl-flex gl-justify-center gl-gap-3">
            <framework-badge
              v-if="groupBy === $options.GROUP_BY.FRAMEWORKS"
              class="gl-inline-block"
              popover-mode="hidden"
              :framework="item.groupValue"
            />
            <template v-else>
              <span class="gl-font-bold">{{ item.groupValue.name }}</span>
            </template>
            <span class="gl-text-status-danger">
              <gl-sprintf :message="$options.i18n.failedControls">
                <template #failedCount>{{
                  n__(
                    'ComplianceStandardsAdherence|%d control',
                    'ComplianceStandardsAdherence|%d controls',
                    item.failCount,
                  )
                }}</template>
              </gl-sprintf>
            </span>
          </div>
        </template>
        <table-part
          :items="item.children"
          :fields="fields"
          thead-class="gl-hidden"
          @row-selected="$emit('row-selected', $event)"
        />
      </grouped-part>
    </template>
  </div>
</template>
