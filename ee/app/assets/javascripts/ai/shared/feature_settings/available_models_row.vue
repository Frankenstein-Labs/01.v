<script>
import { GlButton, GlTooltipDirective } from '@gitlab/ui';
import { s__, sprintf } from '~/locale';

export default {
  name: 'AvailableModelsRow',
  components: {
    GlButton,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    isLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
    allowList: {
      type: Object,
      required: false,
      default: null,
    },
  },
  emits: ['click'],
  computed: {
    indicatorText() {
      if (!this.allowList) {
        return '';
      }

      if (!this.allowList.enabled) {
        return s__('AdminAIPoweredFeatures|All models allowed');
      }

      const models = this.allowList.models?.nodes ?? [];
      const allowedCount = models.filter((model) => model.allowed).length;
      const totalCount = models.length;

      if (allowedCount === totalCount) {
        return s__('AdminAIPoweredFeatures|All models allowed');
      }

      return sprintf(
        s__('AdminAIPoweredFeatures|%{allowedCount} of %{totalCount} models allowed'),
        { allowedCount, totalCount },
      );
    },
  },
};
</script>
<template>
  <div class="gl-flex gl-items-center gl-gap-4">
    <span v-if="indicatorText" class="gl-text-subtle" data-testid="allow-list-indicator">
      {{ indicatorText }}
    </span>
    <span
      v-gl-tooltip="{
        title: s__(
          'AdminAIPoweredFeatures|Available models can only be configured when using a GitLab managed model.',
        ),
        disabled: !disabled,
        placement: 'right',
      }"
      data-testid="disabled-tooltip"
    >
      <gl-button
        data-testid="configure-button"
        :disabled="disabled"
        :loading="isLoading"
        @click="$emit('click')"
      >
        {{ __('Configure') }}
      </gl-button>
    </span>
  </div>
</template>
