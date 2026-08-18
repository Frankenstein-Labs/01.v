<script>
import { GlIcon, GlTooltipDirective } from '@gitlab/ui';
import { __ } from '~/locale';

export default {
  i18n: {
    statusEnabled: __('The policy is enabled'),
    statusDisabled: __('The policy is disabled'),
    disabledText: __('Not enabled'),
    enabledText: __('Enabled'),
  },
  name: 'StatusIcon',
  components: {
    GlIcon,
  },
  directives: {
    GlTooltipDirective,
  },
  props: {
    enabled: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    statusText() {
      return this.enabled ? this.$options.i18n.enabledText : this.$options.i18n.disabledText;
    },
    tooltipContent() {
      return this.enabled ? this.$options.i18n.statusEnabled : this.$options.i18n.statusDisabled;
    },
    variant() {
      return this.enabled ? 'success' : 'disabled';
    },
    name() {
      return this.enabled ? 'check-circle-filled' : 'check-circle-dashed';
    },
    cssClass() {
      return this.enabled ? 'gl-text-success' : 'gl-text-disabled';
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-flex-nowrap gl-items-center gl-gap-2">
    <gl-icon
      v-gl-tooltip-directive.left="tooltipContent"
      :aria-label="tooltipContent"
      :name="name"
      :variant="variant"
    />
    <span class="gl-white-space-nowrap gl-m-0 gl-ml-1" :class="cssClass">
      {{ statusText }}
    </span>
  </div>
</template>
