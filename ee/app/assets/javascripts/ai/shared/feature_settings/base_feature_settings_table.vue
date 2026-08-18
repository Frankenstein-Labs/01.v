<script>
import { GlTableLite, GlSkeletonLoader } from '@gitlab/ui';
import { glSlotsMixin } from '~/lib/utils/vue3compat/gl_slots_mixin';

const LOADER_ITEMS_COUNT = 3;

export default {
  name: 'BaseFeatureSettingsTable',
  components: {
    GlTableLite,
    GlSkeletonLoader,
  },
  mixins: [glSlotsMixin],
  props: {
    fields: {
      type: Array,
      required: true,
    },
    items: {
      type: Array,
      required: true,
    },
    isLoading: {
      type: Boolean,
      required: true,
    },
  },
  computed: {
    loaderItems() {
      // create placeholder items to render during loading
      return new Array(LOADER_ITEMS_COUNT).fill(true);
    },
    tableFields() {
      return this.fields.map((field) => ({
        ...field,
        tdClass: 'gl-content-center !gl-border-b-0',
      }));
    },
  },
  methods: {
    showSlot(slot) {
      return slot.startsWith('head') || !this.isLoading;
    },
    showLoader(scope, slot) {
      // only display loaders non-header cells
      if (!slot.startsWith('cell')) return false;

      if (!scope.field.loaderWidths) return false;

      return this.isLoading;
    },
    getLoaderWidth(scope) {
      const { loaderWidths } = scope.field;

      return loaderWidths[scope.index % loaderWidths.length];
    },
  },
};
</script>
<template>
  <gl-table-lite
    class="gl-border gl-mb-0 gl-rounded-lg gl-border-section gl-bg-section"
    tbody-tr-class="gl-bg-subtle"
    :fields="tableFields"
    :items="isLoading ? loaderItems : items"
    responsive
    borderless
  >
    <template v-for="slot in Object.keys(glSlots())" #[slot]="scope">
      <gl-skeleton-loader v-if="showLoader(scope, slot)" :key="slot" :height="38" :width="600">
        <rect y="8" x="0" :width="getLoaderWidth(scope)" height="24" rx="10" />
      </gl-skeleton-loader>
      <slot v-if="showSlot(slot)" :name="slot" v-bind="scope"></slot>
    </template>
  </gl-table-lite>
</template>
