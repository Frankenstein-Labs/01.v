<script>
import { GlFormCheckbox } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  name: 'DuoAuditEventStreamingForm',
  i18n: {
    sectionTitle: s__('AiPowered|Enable AI audit event streaming'),
    checkboxLabel: s__(
      'AiPowered|Stream AI audit events to configured external audit event streaming destinations. AI audit events are still saved to the database when this setting is off.',
    ),
  },
  components: {
    GlFormCheckbox,
  },
  inject: ['aiAuditEventsStreamingEnabled'],
  props: {
    disabledCheckbox: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['change'],
  data() {
    return {
      streamingEnabled: this.aiAuditEventsStreamingEnabled,
    };
  },
  methods: {
    checkboxChanged() {
      this.$emit('change', this.streamingEnabled);
    },
  },
};
</script>

<template>
  <div>
    <h5>{{ $options.i18n.sectionTitle }}</h5>
    <gl-form-checkbox
      v-model="streamingEnabled"
      data-testid="ai-audit-event-streaming-checkbox"
      :disabled="disabledCheckbox"
      @change="checkboxChanged"
    >
      <span>{{ $options.i18n.checkboxLabel }}</span>
    </gl-form-checkbox>
  </div>
</template>
