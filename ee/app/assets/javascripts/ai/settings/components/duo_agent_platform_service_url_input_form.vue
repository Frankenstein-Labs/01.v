<script>
import { GlFormGroup, GlFormInput, GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  name: 'DuoAgentPlatformServiceUrlInputField',
  components: {
    GlFormGroup,
    GlFormInput,
    GlSprintf,
  },
  i18n: {
    label: s__('AiPowered|Local URL for the GitLab Duo Agent Platform service'),
    description: s__(
      'AiPowered|Enter the URL for your Duo Agent Platform service. This endpoint is used for GitLab Duo Agent Platform requests. %{br} The URL must not include the "http://" or "https://" protocol. For example "example.com:50052".',
    ),
  },
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
  <gl-form-group
    :label="$options.i18n.label"
    label-for="duo-agent-platform-service-url"
    class="gl-mt-5"
  >
    <template #label-description>
      <gl-sprintf :message="$options.i18n.description">
        <template #br><br /></template>
      </gl-sprintf>
    </template>
    <gl-form-input id="duo-agent-platform-service-url" :value="value" @update="onUrlValueChange" />
  </gl-form-group>
</template>
