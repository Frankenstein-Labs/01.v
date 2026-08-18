<script>
import { GlSprintf, GlCard } from '@gitlab/ui';
import TimeAgo from '~/vue_shared/components/time_ago_tooltip.vue';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';
import { __ } from '~/locale';
import { numberToHumanSize } from '~/lib/utils/number_utils';

export default {
  name: 'ModelInfo',
  components: {
    GlSprintf,
    GlCard,
    TimeAgo,
    ClipboardButton,
  },
  props: {
    model: {
      type: Object,
      required: true,
    },
  },
  computed: {
    modelId() {
      return String(this.model.recordIdentifier);
    },
    fileSize() {
      return this.model.fileSize != null ? numberToHumanSize(this.model.fileSize) : __('Unknown');
    },
  },
};
</script>

<template>
  <gl-card>
    <template #header>
      <h5 class="gl-my-0">{{ s__('Geo|Model information') }}</h5>
    </template>

    <div class="gl-flex gl-flex-col gl-gap-4">
      <p data-testid="model-id" class="gl-mb-0">
        <gl-sprintf :message="s__('Geo|Model ID: %{value}')">
          <template #value>
            <span class="gl-font-bold">{{ modelId }}</span>
          </template>
        </gl-sprintf>
        <clipboard-button :title="__('Copy')" :text="modelId" size="small" category="tertiary" />
      </p>

      <p data-testid="size" class="gl-mb-0">
        <gl-sprintf :message="s__('Geo|Storage: %{size}')">
          <template #size>
            <span class="gl-font-bold">{{ fileSize }}</span>
          </template>
        </gl-sprintf>
      </p>

      <p data-testid="created-at" class="gl-mb-0">
        <gl-sprintf :message="s__('Geo|Created: %{timeAgo}')">
          <template #timeAgo>
            <time-ago v-if="model.createdAt" :time="model.createdAt" class="gl-font-bold" />
            <span v-else class="gl-font-bold">{{ __('Unknown') }}</span>
          </template>
        </gl-sprintf>
      </p>
    </div>
  </gl-card>
</template>
