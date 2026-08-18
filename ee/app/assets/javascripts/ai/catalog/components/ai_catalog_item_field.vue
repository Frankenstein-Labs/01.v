<script>
import { glSlotsMixin } from '~/lib/utils/vue3compat/gl_slots_mixin';

export default {
  name: 'AiCatalogItemField',
  mixins: [glSlotsMixin],
  props: {
    title: {
      type: String,
      required: false,
      default: null,
    },
    value: {
      type: String,
      required: false,
      default: null,
    },
  },
};
</script>

<template>
  <div>
    <dt class="gl-text-strong">{{ title }}</dt>
    <dd class="gl-mb-0 gl-break-anywhere">
      <template v-if="glSlots().default">
        <slot></slot>
      </template>
      <template v-else-if="value">
        {{ value }}
      </template>
    </dd>
  </div>
</template>
