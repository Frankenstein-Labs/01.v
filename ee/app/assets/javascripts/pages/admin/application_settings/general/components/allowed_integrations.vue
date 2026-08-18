<script>
import { GlFormCheckbox, GlFormRadioGroup } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  name: 'AllowedIntegrations',
  components: {
    GlFormCheckbox,
    GlFormRadioGroup,
  },
  props: {
    initialAllowAllIntegrations: {
      type: Boolean,
      required: false,
      default: true,
    },
    initialAllowedIntegrations: {
      type: Array,
      required: false,
      default: () => [],
    },
    integrations: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  data() {
    return {
      allowAllIntegrations: this.initialAllowAllIntegrations,
      allowedIntegrations: this.initialAllowedIntegrations || [],
    };
  },
  RADIO_OPTIONS: [
    { value: true, text: s__('AdminSettings|Allow all integrations') },
    { value: false, text: s__('AdminSettings|Allow only integrations on this allowlist') },
  ],
};
</script>

<template>
  <gl-form-radio-group v-model="allowAllIntegrations" :options="$options.RADIO_OPTIONS">
    <input
      v-model="allowAllIntegrations"
      type="hidden"
      name="application_setting[allow_all_integrations]"
    />

    <div v-if="!allowAllIntegrations" class="gl-mt-3 gl-pl-6">
      <input
        type="hidden"
        name="application_setting[allowed_integrations_raw]"
        :value="JSON.stringify(allowedIntegrations)"
      />
      <gl-form-checkbox
        v-for="integration in integrations"
        :key="integration.name"
        v-model="allowedIntegrations"
        :value="integration.name"
      >
        {{ integration.title }}
      </gl-form-checkbox>
    </div>
  </gl-form-radio-group>
</template>
