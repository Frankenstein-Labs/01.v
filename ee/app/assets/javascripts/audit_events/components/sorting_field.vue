<script>
import { GlCollapsibleListbox, GlTooltipDirective, GlButton, GlIcon } from '@gitlab/ui';
import { s__, sprintf } from '~/locale';

export default {
  name: 'SortingField',
  components: {
    GlCollapsibleListbox,
    GlIcon,
    GlButton,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    sortBy: {
      type: String,
      required: false,
      default: null,
    },
  },
  emits: ['selected'],
  computed: {
    sortingItems() {
      return [
        {
          value: 'created_desc',
          text: s__('SortOptions|Last created'),
        },
        {
          value: 'created_asc',
          text: s__('SortOptions|Oldest created'),
        },
      ];
    },
    selectedItem() {
      return (
        this.sortingItems.find((option) => option.value === this.sortBy) || this.sortingItems[0]
      );
    },
  },
  methods: {
    onItemSelect(option) {
      this.$emit('selected', option);
    },
  },
  i18n: {
    sorting_title: s__('SortOptions|Sort by'),
    ariaLabel: (selected) => sprintf(s__('SortOptions|Sort by %{selected}'), { selected }),
  },
};
</script>

<template>
  <gl-collapsible-listbox
    toggle-class="gl-flex-grow"
    is-check-centered
    :items="sortingItems"
    :header-text="$options.i18n.sorting_title"
    :selected="selectedItem.value"
    @select="onItemSelect"
  >
    <template #toggle="{ accessibilityAttributes: { id, ...accessibilityAttributes } }">
      <gl-button
        v-gl-tooltip="$options.i18n.sorting_title"
        v-bind="accessibilityAttributes"
        data-testid="selected-date-range"
        :aria-label="$options.i18n.ariaLabel(selectedItem.text)"
        :title="$options.i18n.sorting_title"
        class="gl-w-full"
        button-text-classes="gl-mr-[-4px] !gl-flex !gl-justify-between gl-w-full"
        ><span :id="id" class="gl-flex-grow-1 gl-text-left">{{ selectedItem.text }}</span>
        <gl-icon
          aria-hidden="true"
          name="chevron-down"
          :size="16"
          variant="current"
          class="gl-flex-shrink-0"
      /></gl-button>
    </template>
  </gl-collapsible-listbox>
</template>
