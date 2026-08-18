<script>
import { GlIcon } from '@gitlab/ui';
import { __ } from '~/locale';

export default {
  name: 'DuoConfigurationSettingsRow',
  i18n: {
    disabledText: __('Not enabled'),
    enabledText: __('Enabled'),
  },
  components: {
    GlIcon,
  },
  props: {
    duoConfigurationSettingsRowTypeTitle: {
      type: String,
      required: true,
    },
    configValue: {
      type: [String, Boolean],
      required: true,
    },
  },
  computed: {
    configIsEnabled() {
      return this.configValue === true;
    },
    configIsDisabled() {
      return this.configValue === false;
    },
    configIsCustom() {
      return typeof this.configValue === 'string';
    },
  },
};
</script>
<template>
  <div class="gl-border-b gl-w-full gl-text-subtle last:gl-border-b-0">
    <div class="gl-my-3 gl-flex gl-flex-row gl-justify-between">
      <span data-testid="duo-configuration-row-title">
        {{ duoConfigurationSettingsRowTypeTitle }}
      </span>
      <span data-testid="duo-configuration-row-value">
        <span v-if="configIsEnabled">
          <gl-icon name="check" :size="16" variant="success" />
          <span>{{ $options.i18n.enabledText }}</span>
        </span>
        <span v-if="configIsDisabled">
          {{ $options.i18n.disabledText }}
        </span>
        <span v-if="configIsCustom">
          {{ configValue }}
        </span>
      </span>
    </div>
  </div>
</template>
