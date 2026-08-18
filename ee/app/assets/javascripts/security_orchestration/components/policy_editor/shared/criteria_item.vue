<script>
import { GlTooltipDirective } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  i18n: {
    disabledTitle: s__('SecurityOrchestration|You can select this option only once.'),
  },
  name: 'CriteriaItem',
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    item: {
      type: Object,
      required: true,
    },
  },
};
</script>

<template>
  <span
    v-gl-tooltip.right.viewport="{ disabled: !item.disabled, title: $options.i18n.disabledTitle }"
    class="gl-flex"
    data-testid="list-item-content"
    :class="{ '!gl-pointer-events-auto': item.disabled }"
  >
    <span data-testid="list-item-text" class="gl-pr-3" :class="{ 'gl-text-subtle': item.disabled }">
      {{ item.text }}
    </span>
  </span>
</template>
