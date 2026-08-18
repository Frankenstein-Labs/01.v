<script>
import { GlFormGroup, GlFormCheckbox, GlTooltipDirective } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  name: 'DuoAgentPlatformSettingsForm',
  components: {
    GlFormGroup,
    GlFormCheckbox,
  },
  directives: {
    tooltip: GlTooltipDirective,
  },
  inject: ['showDuoAgentPlatformEnablementSetting'],
  i18n: {
    disabledTooltip: s__('AiPowered|This setting only applies when GitLab Duo is available.'),
    childSettingsDisabledDueToDAP: s__(
      'AiPowered|These settings are disabled because GitLab Duo Agent Platform is turned off.',
    ),
  },
  props: {
    enabled: {
      type: Boolean,
      required: true,
    },
    disabledCheckbox: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['selected'],
  computed: {
    childSettingsDisabled() {
      return !this.enabled || this.disabledCheckbox;
    },
    showChildSettingsDisabledBanner() {
      if (!this.showDuoAgentPlatformEnablementSetting) return false;

      return this.childSettingsDisabled && !this.disabledCheckbox;
    },
    childSettingsDisabledMessage() {
      return !this.enabled ? this.$options.i18n.childSettingsDisabledDueToDAP : '';
    },
  },
  methods: {
    onDuoAgentPlatformEnabledChanged(value) {
      this.$emit('selected', value);
    },
  },
};
</script>
<template>
  <div class="gl-my-4">
    <gl-form-group
      v-if="showDuoAgentPlatformEnablementSetting"
      :label="s__('AiPowered|GitLab Duo Agent Platform')"
    >
      <gl-form-checkbox
        :checked="enabled"
        :disabled="disabledCheckbox"
        @input="onDuoAgentPlatformEnabledChanged"
      >
        <span v-tooltip="disabledCheckbox ? $options.i18n.disabledTooltip : ''">{{
          s__('AiPowered|Turn on GitLab Duo Agentic Chat, agents, and flows')
        }}</span>
      </gl-form-checkbox>
    </gl-form-group>
    <div
      v-if="showChildSettingsDisabledBanner"
      class="gl-mb-4 gl-rounded-base gl-bg-feedback-info gl-px-4 gl-py-3 gl-text-sm"
      data-testid="dap-child-settings-disabled-message"
    >
      {{ childSettingsDisabledMessage }}
    </div>
  </div>
</template>
