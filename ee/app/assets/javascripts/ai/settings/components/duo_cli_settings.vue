<script>
import { GlFormCheckbox, GlFormGroup } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  name: 'DuoCliSettings',
  components: {
    GlFormCheckbox,
    GlFormGroup,
  },
  i18n: {
    sectionTitle: s__('AiPowered|GitLab Duo CLI'),
    subtitle: s__(
      'AiPowered|Allow developers in this instance to use GitLab Duo CLI. Duo CLI is billed as consumption against this instance.',
    ),
    checkboxLabel: s__('AiPowered|Turn on GitLab Duo CLI access'),
    checkboxHelpText: s__(
      'AiPowered|This setting applies to the entire instance. Turning this off blocks Duo CLI usage across all groups and projects.',
    ),
    coreDisabledMessage: s__(
      'AiPowered|These settings are disabled because GitLab Duo Core is turned off.',
    ),
  },
  props: {
    duoCliEnabled: {
      type: Boolean,
      required: true,
    },
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    showCoreDisabledMessage: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['change'],
  data() {
    return {
      checked: this.duoCliEnabled,
    };
  },
  methods: {
    onChange(value) {
      this.checked = value;
      this.$emit('change', value);
    },
  },
};
</script>
<template>
  <div>
    <div
      v-if="showCoreDisabledMessage"
      class="gl-mb-4 gl-rounded-base gl-bg-feedback-info gl-px-4 gl-py-3 gl-text-sm"
    >
      {{ $options.i18n.coreDisabledMessage }}
    </div>
    <gl-form-group :label="$options.i18n.sectionTitle" :label-description="$options.i18n.subtitle">
      <gl-form-checkbox v-model="checked" :disabled="disabled" @change="onChange">
        {{ $options.i18n.checkboxLabel }}
        <template #help>
          {{ $options.i18n.checkboxHelpText }}
        </template>
      </gl-form-checkbox>
    </gl-form-group>
  </div>
</template>
