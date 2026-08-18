<script>
import { GlSprintf } from '@gitlab/ui';
import { decimalBytes } from '~/lib/utils/unit_format';
import { s__ } from '~/locale';

export default {
  name: 'CorpusUpload',
  components: {
    GlSprintf,
  },
  i18n: {
    totalSize: s__('CorpusManagement|Total Size: %{totalSize}'),
  },
  props: {
    totalSize: {
      type: Number,
      required: false,
      default: null,
    },
  },
  computed: {
    formattedFileSize() {
      return decimalBytes(this.totalSize, 0, { unitSeparator: ' ' });
    },
  },
};
</script>
<template>
  <div class="gl-flex gl-h-11 gl-items-center gl-justify-between gl-bg-subtle">
    <div v-if="totalSize" class="gl-ml-5">
      <gl-sprintf :message="$options.i18n.totalSize">
        <template #totalSize>
          <span data-testid="total-size" class="gl-font-bold">{{ formattedFileSize }}</span>
        </template>
      </gl-sprintf>
    </div>
    <slot name="action"></slot>
  </div>
</template>
