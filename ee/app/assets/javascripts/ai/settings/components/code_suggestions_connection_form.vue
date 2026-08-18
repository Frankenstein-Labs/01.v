<script>
import { GlSprintf, GlFormRadioGroup, GlFormRadio } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  name: 'CodeSuggestionsConnectionForm',
  i18n: {
    sectionTitle: s__('AiPowered|Connection method'),
    subtitleText: s__('AiPowered|Specify how code completion requests are sent to the AI gateway.'),
    directConnectionText: s__('AiPowered|Direct connections'),
    directConnectionHelpText: s__(
      'AiPowered|Use this setting to minimize latency. An IDE must connect to https://gitlab.com:443.',
    ),
    indirectConnectionText: s__('AiPowered|Indirect connections through GitLab Self-Managed'),
    indirectConnectionHelpText: s__(
      'AiPowered|Use this setting to disable direct connections for all users. This setting might result in higher latency.',
    ),
  },
  components: {
    GlSprintf,
    GlFormRadioGroup,
    GlFormRadio,
  },
  inject: ['disabledDirectConnectionMethod'],
  emits: ['change'],
  data() {
    return {
      disabledConnectionMethod: this.disabledDirectConnectionMethod,
    };
  },
  methods: {
    radioChanged(value) {
      this.$emit('change', value);
    },
  },
};
</script>
<template>
  <div>
    <h5>{{ $options.i18n.sectionTitle }}</h5>
    <gl-form-radio-group v-model="disabledConnectionMethod" @change="radioChanged">
      <gl-form-radio :value="false">
        {{ $options.i18n.directConnectionText }}
        <template #help>
          <gl-sprintf :message="$options.i18n.directConnectionHelpText" />
        </template>
      </gl-form-radio>
      <gl-form-radio :value="true">
        {{ $options.i18n.indirectConnectionText }}
        <template #help>
          <gl-sprintf :message="$options.i18n.indirectConnectionHelpText" />
        </template>
      </gl-form-radio>
    </gl-form-radio-group>
  </div>
</template>
