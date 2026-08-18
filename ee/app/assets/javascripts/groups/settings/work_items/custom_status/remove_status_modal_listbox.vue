<script>
import { GlButton, GlCollapsibleListbox, GlIcon } from '@gitlab/ui';
import { getAdaptiveStatusColor } from '~/lib/utils/color_utils';

export default {
  name: 'RemoveStatusModalListbox',
  components: {
    GlButton,
    GlCollapsibleListbox,
    GlIcon,
  },
  props: {
    items: {
      type: Array,
      required: true,
    },
    selected: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    toggleId: {
      type: String,
      required: true,
    },
    value: {
      type: String,
      required: false,
      default: undefined,
    },
  },
  emits: ['input'],
  methods: {
    getColorStyle({ color }) {
      return { color: getAdaptiveStatusColor(color) };
    },
  },
};
</script>

<template>
  <gl-collapsible-listbox
    class="gl-w-30"
    block
    :items="items"
    :selected="value"
    :toggle-id="toggleId"
    @select="$emit('input', $event)"
  >
    <template #toggle>
      <gl-button class="gl-w-full" button-text-classes="gl-flex gl-w-full gl-items-center">
        <gl-icon :name="selected.iconName" :size="12" :style="getColorStyle(selected)" />
        {{ selected.name }}
        <gl-icon class="gl-ml-auto" name="chevron-down" />
      </gl-button>
    </template>
    <template #list-item="{ item }">
      <gl-icon class="gl-mr-1" :name="item.iconName" :size="12" :style="getColorStyle(item)" />
      {{ item.name }}
    </template>
  </gl-collapsible-listbox>
</template>
