<script>
import { s__ } from '~/locale';
import AccordionTableList from './accordion_table_list.vue';

export default {
  i18n: {
    allowListHeader: s__('SecurityOrchestration|Allowlist details'),
    denyListHeader: s__('SecurityOrchestration|Denylist details'),
    denyTableHeader: s__('SecurityOrchestration|Denied licenses'),
    allowTableHeader: s__('SecurityOrchestration|Allowed licenses'),
    exceptionsHeader: s__('ScanResultPolicy|Exceptions that require approval'),
    exceptionsDenyHeader: s__('ScanResultPolicy|Exceptions that do not require approval'),
    noExceptionsText: s__('SecurityOrchestration|No exceptions'),
  },
  name: 'DenyAllowViewList',
  components: { AccordionTableList },
  props: {
    isDenied: { type: Boolean, required: false, default: false },
    items: { type: Array, required: false, default: () => [] },
  },
  computed: {
    title() {
      return this.isDenied ? this.$options.i18n.denyListHeader : this.$options.i18n.allowListHeader;
    },
    fields() {
      return [
        {
          key: 'licenses',
          label: this.isDenied
            ? this.$options.i18n.denyTableHeader
            : this.$options.i18n.allowTableHeader,
          thAttr: { 'data-testid': 'list-type-th' },
        },
        {
          key: 'exceptions',
          label: this.isDenied
            ? this.$options.i18n.exceptionsDenyHeader
            : this.$options.i18n.exceptionsHeader,
          thAttr: { 'data-testid': 'exception-th' },
        },
      ];
    },
  },
  methods: {
    mapExceptionPackagesToString(exceptions = []) {
      if (exceptions.length === 0) return this.$options.i18n.noExceptionsText;
      return exceptions.join(' ') || '';
    },
  },
};
</script>

<template>
  <accordion-table-list :title="title" :fields="fields" :items="items">
    <template #cell(licenses)="{ item = {} }">
      {{ item?.license?.text || '' }}
    </template>
    <template #cell(exceptions)="{ item = {} }">
      {{ mapExceptionPackagesToString(item.exceptions) }}
    </template>
  </accordion-table-list>
</template>
