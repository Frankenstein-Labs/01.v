<script>
import { GlFormGroup, GlFormRadioGroup, GlFormRadio, GlIcon } from '@gitlab/ui';
import { ENFORCEMENT_OPTIONS } from '../lib';

export default {
  name: 'EnforcementType',
  components: {
    GlFormGroup,
    GlFormRadioGroup,
    GlFormRadio,
    GlIcon,
  },
  props: {
    enforcement: {
      type: String,
      required: true,
    },
  },
  emits: ['change'],
  methods: {
    handleEnforcementChange(value) {
      this.$emit('change', value);
    },
  },
  ENFORCEMENT_OPTIONS,
};
</script>

<template>
  <gl-form-group :label="s__('SecurityOrchestration|Enforcement mode')" class="gl-mt-5">
    <gl-form-radio-group :checked="enforcement" @change="handleEnforcementChange">
      <gl-form-radio
        v-for="option in $options.ENFORCEMENT_OPTIONS"
        :key="option.value"
        :value="option.value"
        :data-testid="`enforcement-radio-${option.value}`"
      >
        <span class="gl-inline-flex gl-items-center gl-gap-2">
          <gl-icon :name="option.icon" :class="option.iconClass" :size="12" />
          <span class="gl-font-bold">{{ option.text }}</span>
        </span>
        <template #help>{{ option.description }}</template>
      </gl-form-radio>
    </gl-form-radio-group>
  </gl-form-group>
</template>
