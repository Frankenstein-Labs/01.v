<script>
import { GlFormRadioGroup } from '@gitlab/ui';
import { s__ } from '~/locale';
import { AI_CATALOG_TYPE_AGENT, AI_CATALOG_TYPE_THIRD_PARTY_FLOW } from 'ee/ai/catalog/constants';

export default {
  name: 'FormAgentType',
  components: {
    GlFormRadioGroup,
  },
  props: {
    id: {
      type: String,
      required: false,
      default: null,
    },
    value: {
      type: String,
      required: true,
    },
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['input'],
  agentTypes: [
    {
      value: AI_CATALOG_TYPE_AGENT,
      text: s__('AICatalog|Custom'),
    },
    {
      value: AI_CATALOG_TYPE_THIRD_PARTY_FLOW,
      text: s__('AICatalog|External'),
    },
  ],
};
</script>

<template>
  <gl-form-radio-group
    :id="id"
    :checked="value"
    :options="$options.agentTypes"
    :disabled="disabled"
    @input="$emit('input', $event)"
  />
</template>
