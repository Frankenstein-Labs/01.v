<script>
import { GlAccordion, GlAccordionItem, GlTableLite } from '@gitlab/ui';

const TH_CSS_CLASSES = '!gl-pl-0 !gl-text-sm !gl-border-t-0';
const TD_CSS_CLASSES = '!gl-pl-0 !gl-border-none !gl-pb-3 !gl-text-sm';

export default {
  name: 'AccordionTableList',
  components: { GlAccordion, GlAccordionItem, GlTableLite },
  props: {
    title: { type: String, required: true },
    fields: { type: Array, required: true },
    items: { type: Array, required: false, default: () => [] },
  },
  computed: {
    decoratedFields() {
      return this.fields.map((f) => ({
        thClass: TH_CSS_CLASSES,
        tdClass: TD_CSS_CLASSES,
        ...f,
      }));
    },
  },
};
</script>

<template>
  <gl-accordion :header-level="3">
    <gl-accordion-item :title="title">
      <gl-table-lite
        :fields="decoratedFields"
        :items="items"
        table-class="gl-border-b"
        stacked="md"
      >
        <!-- eslint-disable-next-line @gitlab/vue-require-i18n-strings -->
        <template v-for="field in fields" #[`cell(${field.key})`]="slotProps">
          <slot :name="`cell(${field.key})`" v-bind="slotProps"></slot>
        </template>
      </gl-table-lite>
    </gl-accordion-item>
  </gl-accordion>
</template>
