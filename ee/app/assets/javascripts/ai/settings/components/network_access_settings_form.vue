<script>
import { GlFormCheckbox, GlFormGroup, GlTooltipDirective } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  name: 'NetworkAccessSettingsForm',
  components: {
    GlFormCheckbox,
    GlFormGroup,
  },
  directives: {
    tooltip: GlTooltipDirective,
  },
  props: {
    includeRecommendedAllowedDomains: {
      type: Boolean,
      required: true,
    },
    allowAllUnixSockets: {
      type: Boolean,
      required: true,
    },
    allowProjectExtension: {
      type: Boolean,
      required: true,
    },
    disabledCheckbox: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: [
    'include-recommended-allowed-domains-changed',
    'allow-all-unix-sockets-changed',
    'allow-project-extension-changed',
  ],
  data() {
    return {
      includeRecommendedAllowedDomainsInput: this.includeRecommendedAllowedDomains,
      allowAllUnixSocketsInput: this.allowAllUnixSockets,
      allowProjectExtensionInput: this.allowProjectExtension,
    };
  },
  computed: {
    checkboxSettings() {
      return [
        {
          key: 'includeRecommendedAllowedDomains',
          value: this.includeRecommendedAllowedDomainsInput,
          event: 'include-recommended-allowed-domains-changed',
          testid: 'include-recommended-allowed-domains-checkbox',
          label: s__('AiPowered|Include recommended domains in the allowlist'),
          help: s__(
            'AiPowered|A curated list of recommended domains is automatically included in the allowlist.',
          ),
        },
        {
          key: 'allowAllUnixSockets',
          value: this.allowAllUnixSocketsInput,
          event: 'allow-all-unix-sockets-changed',
          testid: 'allow-all-unix-sockets-checkbox',
          label: s__('AiPowered|Allow all Unix sockets'),
          help: s__(
            'AiPowered|All Unix sockets are allowed for GitLab Duo Agent Platform operations.',
          ),
        },
        {
          key: 'allowProjectExtension',
          value: this.allowProjectExtensionInput,
          event: 'allow-project-extension-changed',
          testid: 'allow-project-extension-checkbox',
          label: s__('AiPowered|Allow projects to extend network sandbox settings'),
          help: s__(
            'AiPowered|Users with the Maintainer or Owner role for a project can include recommended domains, add more domains, and allow all Unix sockets.',
          ),
        },
      ];
    },
    disabledCheckboxTooltip() {
      return this.disabledCheckbox
        ? s__('AiPowered|This setting only applies when GitLab Duo is available.')
        : '';
    },
  },
  methods: {
    onCheckboxChanged(setting, value) {
      this[`${setting.key}Input`] = value;
      this.$emit(setting.event, value);
    },
  },
};
</script>
<template>
  <gl-form-group :label="s__('AiPowered|Network access controls')" class="gl-my-4">
    <template #label-description>
      {{
        s__(
          'AiPowered|Control which external network resources the GitLab Duo Agent Platform can access.',
        )
      }}
    </template>

    <gl-form-checkbox
      v-for="setting in checkboxSettings"
      :key="setting.key"
      :checked="setting.value"
      :data-testid="setting.testid"
      :disabled="disabledCheckbox"
      @change="onCheckboxChanged(setting, $event)"
    >
      <span v-tooltip="disabledCheckboxTooltip">{{ setting.label }}</span>
      <template #help>{{ setting.help }}</template>
    </gl-form-checkbox>
  </gl-form-group>
</template>
