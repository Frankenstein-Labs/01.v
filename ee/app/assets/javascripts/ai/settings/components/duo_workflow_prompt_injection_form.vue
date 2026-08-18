<script>
import { GlFormGroup, GlFormRadio, GlFormRadioGroup } from '@gitlab/ui';
import { PROTECTION_LEVEL_OPTIONS } from '../constants';

const PROTECTION_LEVEL_VALUES = PROTECTION_LEVEL_OPTIONS.map((option) => option.value);

export default {
  name: 'DuoWorkflowPromptInjectionForm',
  components: {
    GlFormGroup,
    GlFormRadio,
    GlFormRadioGroup,
  },
  props: {
    promptInjectionProtectionLevel: {
      type: String,
      required: true,
      validator: (value) => PROTECTION_LEVEL_VALUES.includes(value),
    },
    showProtection: {
      type: Boolean,
      required: true,
    },
  },
  emits: ['protection-level-change'],
  data() {
    return {
      selectedProtectionLevel: this.promptInjectionProtectionLevel,
    };
  },
  watch: {
    promptInjectionProtectionLevel(newValue) {
      this.selectedProtectionLevel = newValue;
    },
  },
  methods: {
    onProtectionLevelChange(value) {
      this.$emit('protection-level-change', value);
    },
  },
  protectionLevelOptions: PROTECTION_LEVEL_OPTIONS,
};
</script>
<template>
  <div class="gl-flex gl-flex-col gl-gap-4">
    <gl-form-group
      v-if="showProtection"
      :label="s__('DuoWorkflowSettings|Prompt injection protection')"
      :label-description="
        s__(
          'DuoWorkflowSettings|Control how GitLab Duo handles potential prompt injection attempts.',
        )
      "
    >
      <gl-form-radio-group
        v-model="selectedProtectionLevel"
        name="namespace[ai_settings_attributes][prompt_injection_protection_level]"
        data-testid="prompt-injection-protection-level-radio-group"
        @change="onProtectionLevelChange"
      >
        <gl-form-radio
          v-for="option in $options.protectionLevelOptions"
          :key="option.value"
          :value="option.value"
          :data-testid="`prompt-injection-protection-${option.value}-radio`"
        >
          <div>
            {{ option.text }}
            <p class="gl-mb-0 gl-text-subtle">{{ option.description }}</p>
          </div>
        </gl-form-radio>
      </gl-form-radio-group>
    </gl-form-group>
  </div>
</template>
