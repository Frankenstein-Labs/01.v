<script>
import { GlIcon } from '@gitlab/ui';
import { formatNumber } from '~/locale';

export default {
  name: 'AgenticAdoptionFunnelStage',
  components: {
    GlIcon,
  },
  props: {
    count: {
      type: Number,
      required: true,
    },
    title: {
      type: String,
      required: true,
    },
    /**
     * Optional AI-feature description. When provided it is rendered below the
     * title with the Duo (tanuki-ai) icon.
     */
    description: {
      type: String,
      required: false,
      default: '',
    },
  },
  computed: {
    formattedCount() {
      return formatNumber(this.count);
    },
  },
};
</script>

<template>
  <dl class="gl-mb-0 gl-flex gl-flex-col" data-testid="funnel-stage">
    <dt class="gl-order-2 gl-text-sm gl-font-normal gl-text-purple-900 @md/panel:gl-text-base">
      {{ title }}
    </dt>
    <dd
      class="gl-heading-3-fixed gl-order-1 gl-m-0 gl-font-bold gl-text-purple-900"
      data-testid="funnel-stage-count"
    >
      {{ formattedCount }}
    </dd>
    <dd
      v-if="description"
      class="gl-order-3 gl-m-0 gl-flex gl-items-center gl-gap-2 gl-text-xs gl-text-purple-600"
      data-testid="funnel-stage-description"
    >
      <gl-icon name="tanuki-ai" :size="12" />
      {{ description }}
    </dd>
  </dl>
</template>
