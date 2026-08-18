<script>
import { GlCard, GlButton } from '@gitlab/ui';
import { s__ } from '~/locale';
import { AVAILABILITY_OPTIONS } from '../constants';
import DuoConfigurationSettingsRow from './duo_configuration_settings_row.vue';

export default {
  name: 'DuoAmazonQInfoCard',
  components: {
    GlCard,
    GlButton,
    DuoConfigurationSettingsRow,
  },
  inject: {
    duoAvailability: {
      type: String,
      required: true,
    },
    amazonQConfigurationPath: {
      type: String,
      required: false,
      default: '',
    },
    amazonQReady: {
      type: Boolean,
      required: false,
      default: false,
    },
    amazonQAutoReviewEnabled: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    getAvailabilityStatus() {
      switch (this.duoAvailability) {
        case AVAILABILITY_OPTIONS.DEFAULT_ON:
          return s__('AiPowered|On by default');
        case AVAILABILITY_OPTIONS.DEFAULT_OFF:
          return s__('AiPowered|Off by default');
        case AVAILABILITY_OPTIONS.NEVER_ON:
          return s__('AiPowered|Always off');
        default:
          return null;
      }
    },
  },
};
</script>
<template>
  <gl-card
    header-class="gl-bg-transparent gl-border-none gl-pb-0"
    footer-class="gl-bg-transparent gl-border-none gl-flex-end"
    class="gl-justify-between"
  >
    <template #default>
      <section class="gl-flex gl-flex-col">
        <h2 class="gl-m-0 gl-text-lg">
          {{ s__('AiPowered|GitLab Duo with Amazon Q') }}
        </h2>
        <p class="gl-mb-3 gl-text-size-h-display gl-font-bold">
          <span>{{ getAvailabilityStatus }}</span>
        </p>
      </section>
      <duo-configuration-settings-row
        :duo-configuration-settings-row-type-title="s__('AiPowered|Amazon Q Setup')"
        :config-value="amazonQReady"
      />
      <duo-configuration-settings-row
        :duo-configuration-settings-row-type-title="s__('AiPowered|Automatic Code Reviews')"
        :config-value="amazonQAutoReviewEnabled"
      />
    </template>
    <template #footer>
      <gl-button category="primary" variant="default" :href="amazonQConfigurationPath">{{
        s__('AiPowered|View configuration')
      }}</gl-button>
    </template>
  </gl-card>
</template>
