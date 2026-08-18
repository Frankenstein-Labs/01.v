<script>
import { GlIcon } from '@gitlab/ui';
import { TOOL_STATUS_CONFIG, TOOL_NOT_ENABLED } from 'ee/security_inventory/constants';
import timeagoMixin from '~/vue_shared/mixins/timeago';
import { securityScannerOfGroupValidator } from 'ee/security_inventory/utils';

export default {
  name: 'GroupToolCoverageDetails',
  components: {
    GlIcon,
  },
  mixins: [timeagoMixin],
  props: {
    securityScanner: {
      type: Object,
      required: true,
      validator: (value) => securityScannerOfGroupValidator(value),
    },
  },
  methods: {
    getStatusConfig(status) {
      return TOOL_STATUS_CONFIG[status] ?? TOOL_STATUS_CONFIG[TOOL_NOT_ENABLED];
    },
    getFieldKey(status) {
      return (TOOL_STATUS_CONFIG[status] || TOOL_STATUS_CONFIG[TOOL_NOT_ENABLED]).fieldKey;
    },
  },
  TOOL_STATUS_CONFIG,
};
</script>

<template>
  <div>
    <div class="gl-m-2">
      <div v-for="key in Object.keys($options.TOOL_STATUS_CONFIG)" :key="key" class="gl-my-2">
        <gl-icon
          :name="getStatusConfig(key).name"
          :variant="getStatusConfig(key).variant"
          :size="12"
          :data-testid="`icon-${getFieldKey(key)}`"
          :aria-label="getStatusConfig(key).text"
        />
        <span class="gl-font-bold" :data-testid="`scanner-title-${getFieldKey(key)}`"
          >{{ getStatusConfig(key).text }}:</span
        >
        <span :data-testid="`scanner-status-${getFieldKey(key)}`">
          {{ securityScanner[getFieldKey(key)] }}
        </span>
      </div>
    </div>

    <div
      v-if="securityScanner && securityScanner.updatedAt"
      class="gl-mb-2 gl-mt-3"
      data-testid="date-updated"
    >
      {{ __('Data updated') }}
      <time :datetime="securityScanner.updatedAt">{{
        timeFormatted(securityScanner.updatedAt)
      }}</time>
    </div>
  </div>
</template>
