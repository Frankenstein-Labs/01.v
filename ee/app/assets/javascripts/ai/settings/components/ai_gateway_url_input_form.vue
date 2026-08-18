<script>
import { GlFormGroup, GlFormInput, GlLink, GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';

export default {
  name: 'AiGatewayUrlInputField',
  components: {
    GlFormGroup,
    GlFormInput,
    GlLink,
    GlSprintf,
  },
  i18n: {
    label: s__('AiPowered|Local AI Gateway URL'),
    description: s__(
      'AiPowered|Enter the URL for your local AI Gateway. This endpoint is used for GitLab Duo Self-Hosted requests.%{br}The URL must be a complete URL, including either the "http://" or "https://" protocol. For example "http://EXAMPLE-URL".%{br}For more information, see how to %{linkStart}install the GitLab AI Gateway.%{linkEnd}',
    ),
  },
  aiGatewaySetupUrl: helpPagePath('install/install_ai_gateway'),
  props: {
    value: {
      type: String,
      required: false,
      default: '',
    },
  },
  emits: ['change'],
  methods: {
    onUrlValueChange(newValue) {
      this.$emit('change', newValue);
    },
  },
};
</script>
<template>
  <gl-form-group class="gl-pt-3" :label="$options.i18n.label" label-for="ai-gateway-url">
    <template #label-description>
      <gl-sprintf :message="$options.i18n.description">
        <template #br><br /></template>
        <template #link="{ content }">
          <gl-link
            data-testid="ai-gateway-setup-link"
            :href="$options.aiGatewaySetupUrl"
            target="_blank"
            >{{ content }}</gl-link
          >
        </template>
      </gl-sprintf>
    </template>
    <gl-form-input id="ai-gateway-url" :value="value" @update="onUrlValueChange" />
  </gl-form-group>
</template>
