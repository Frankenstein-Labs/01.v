<script>
import { s__ } from '~/locale';
import {
  OVERRIDE_MODE_OPTIONS,
  OVERRIDE_MODE_PATCH,
  LICENSE_OVERRIDE_VIEW_FIELDS,
} from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/constants';
import AccordionTableList from './accordion_table_list.vue';

export default {
  i18n: {
    header: s__('SecurityOrchestration|License override details'),
  },
  fields: LICENSE_OVERRIDE_VIEW_FIELDS,
  name: 'LicenseOverridesViewList',
  components: { AccordionTableList },
  props: {
    items: { type: Array, required: false, default: () => [] },
  },
  methods: {
    modeText(mode) {
      return OVERRIDE_MODE_OPTIONS[mode] || OVERRIDE_MODE_OPTIONS[OVERRIDE_MODE_PATCH];
    },
  },
};
</script>

<template>
  <accordion-table-list :title="$options.i18n.header" :fields="$options.fields" :items="items">
    <template #cell(purl)="{ item = {} }">
      <code>{{ item.purl }}</code>
    </template>
    <template #cell(license)="{ item = {} }">
      {{ item.license }}
    </template>
    <template #cell(mode)="{ item = {} }">
      {{ modeText(item.mode) }}
    </template>
  </accordion-table-list>
</template>
