<script>
import { defineComponent } from 'vue';
import { GlIcon } from '@gitlab/ui';

export default defineComponent({
  name: 'ConnectCollapsibleSection',
  compatConfig: { MODE: 3 },
  components: { GlIcon },
  props: {
    icon: { type: String, required: true },
    title: { type: String, required: true },
    open: { type: Boolean, required: false, default: false },
    testid: { type: String, required: false, default: null },
  },
  emits: ['update:open'],
});
</script>

<template>
  <div class="gl-rounded-lg gl-bg-default">
    <button
      type="button"
      class="gl-flex gl-w-full gl-cursor-pointer gl-items-center gl-gap-3 gl-rounded-lg gl-border-0 gl-bg-transparent gl-p-4 gl-text-left gl-text-base gl-font-bold"
      :aria-expanded="String(open)"
      :data-testid="testid ? `${testid}-toggle` : undefined"
      @click="$emit('update:open', !open)"
    >
      <gl-icon :name="icon" :size="16" />
      {{ title }}
      <gl-icon :name="open ? 'chevron-down' : 'chevron-right'" :size="12" />
    </button>
    <div v-if="open" class="gl-px-4 gl-pb-4" :data-testid="testid ? `${testid}-body` : undefined">
      <slot></slot>
    </div>
  </div>
</template>
