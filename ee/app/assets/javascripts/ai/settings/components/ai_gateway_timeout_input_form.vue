<script>
import { GlFormInput, GlFormGroup, GlSprintf } from '@gitlab/ui';

export default {
  name: 'AiGatewayTimeoutInputForm',
  components: {
    GlSprintf,
    GlFormInput,
    GlFormGroup,
  },
  props: {
    value: {
      type: Number,
      required: true,
    },
  },
  emits: ['change'],
  computed: {
    aiGatewayTimeout: {
      get() {
        return this.value;
      },
      set(newValue) {
        this.$emit('change', parseInt(newValue, 10));
      },
    },
  },
};
</script>
<template>
  <div>
    <gl-form-group
      :label="s__('AiPowered|AI Gateway request timeout')"
      label-for="ai-gateway-timeout"
      class="gl-my-4"
    >
      <template #label-description>
        <gl-sprintf
          :message="
            s__(
              'AiPowered|Maximum time in seconds to wait for responses from the AI Gateway (up to 600 seconds).%{br}Increasing this value might result in degraded user experience.',
            )
          "
        >
          <template #br><br /></template>
        </gl-sprintf>
      </template>
      <div class="gl-flex gl-items-center gl-gap-3">
        <gl-form-input
          id="ai-gateway-timeout"
          v-model="aiGatewayTimeout"
          width="xs"
          type="number"
          min="60"
          max="600"
        />
        <span>
          {{ __('seconds') }}
        </span>
      </div>
    </gl-form-group>
  </div>
</template>
