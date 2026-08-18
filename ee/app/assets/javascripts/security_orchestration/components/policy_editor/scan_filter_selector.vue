<script>
import { GlDisclosureDropdown, GlTooltipDirective } from '@gitlab/ui';
import { s__ } from '~/locale';
import SectionLayout from './section_layout.vue';

export default {
  name: 'ScanFilterSelector',
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  components: {
    SectionLayout,
    GlDisclosureDropdown,
  },
  props: {
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    filters: {
      type: Array,
      required: false,
      default: () => [],
    },
    selected: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    shouldDisableFilter: {
      type: Function,
      required: false,
      default: () => false,
    },
    buttonText: {
      type: String,
      required: false,
      default: s__('ScanResultPolicy|Add new criteria'),
    },
    header: {
      type: String,
      required: false,
      default: s__('ScanResultPolicy|Choose criteria type'),
    },
    tooltipTitle: {
      type: String,
      required: false,
      default: '',
    },
    customFilterTooltip: {
      type: Function,
      required: false,
      default: () => null,
    },
  },
  emits: ['select'],
  computed: {
    filtersWithExtraAttributes() {
      return this.filters.map((filter) => {
        return {
          ...filter,
          extraAttrs: { disabled: this.filterDisabled(filter.value) },
        };
      });
    },
  },
  methods: {
    filterDisabled(value) {
      return this.shouldDisableFilter(value) || Boolean(this.selected[value]);
    },
    selectFilter({ value }) {
      this.$emit('select', value);
    },
    filterTooltip(filter) {
      return this.customFilterTooltip(filter) || filter.tooltip;
    },
  },
};
</script>

<template>
  <section-layout :show-remove-button="false">
    <template #content>
      <gl-disclosure-dropdown
        v-gl-tooltip.right.viewport
        :disabled="disabled"
        fluid-width
        :items="filtersWithExtraAttributes"
        :toggle-text="buttonText"
        :title="tooltipTitle"
        variant="link"
        @action="selectFilter"
      >
        <template #header>
          <strong class="gl-border-b gl-py-3 gl-pl-3">{{ header }}</strong>
        </template>

        <template #list-item="{ item }">
          <div
            v-gl-tooltip.right.viewport="{
              disabled: !filterDisabled(item.value),
              title: filterTooltip(item),
            }"
            class="gl-flex"
            data-testid="list-item-content"
            :class="{ '!gl-pointer-events-auto': filterDisabled(item.value) }"
          >
            <span
              :id="item.value"
              class="gl-pr-3"
              :class="{ 'gl-text-subtle': filterDisabled(item.value) }"
            >
              {{ item.text }}
            </span>
          </div>
        </template>
      </gl-disclosure-dropdown>
    </template>
  </section-layout>
</template>
