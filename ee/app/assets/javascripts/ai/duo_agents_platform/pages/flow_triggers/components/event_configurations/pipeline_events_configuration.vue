<script>
import { GlCollapsibleListbox, GlFormGroup } from '@gitlab/ui';
import { omit } from 'lodash-es';
import { s__ } from '~/locale';
import {
  FILTER_FIELD_PIPELINE_STATUS,
  FILTER_OPERATOR_IN,
  FLOW_TRIGGER_TYPE_PIPELINE_HOOKS,
  PIPELINE_HOOK_STATUSES,
} from 'ee/ai/duo_agents_platform/constants';
import { parsePipelineStatusFilter } from 'ee/ai/duo_agents_platform/utils';

export default {
  name: 'PipelineEventsConfiguration',
  components: {
    GlCollapsibleListbox,
    GlFormGroup,
  },
  props: {
    value: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    invalidFeedback: {
      type: String,
      required: false,
      default: null,
    },
  },
  emits: ['input'],
  computed: {
    selectedStatuses() {
      return parsePipelineStatusFilter(this.value);
    },
    toggleText() {
      if (!this.selectedStatuses.length) {
        return s__('DuoAgentsPlatform|Select pipeline events');
      }
      return PIPELINE_HOOK_STATUSES.filter((status) => this.selectedStatuses.includes(status.value))
        .map((status) => status.text)
        .join(', ');
    },
  },
  methods: {
    setSelectedStatuses(newSelected) {
      const nextValue = omit(this.value, FLOW_TRIGGER_TYPE_PIPELINE_HOOKS.value);
      if (newSelected.length > 0) {
        nextValue[FLOW_TRIGGER_TYPE_PIPELINE_HOOKS.value] = {
          rules: [
            {
              field: FILTER_FIELD_PIPELINE_STATUS,
              operator: FILTER_OPERATOR_IN,
              value: newSelected,
            },
          ],
        };
      }
      this.$emit('input', nextValue);
    },
  },
  PIPELINE_HOOK_STATUSES,
};
</script>

<template>
  <gl-form-group
    :label="s__('DuoAgentsPlatform|Run when')"
    :state="!invalidFeedback"
    :invalid-feedback="invalidFeedback"
    class="!gl-mb-0"
  >
    <gl-collapsible-listbox
      :items="$options.PIPELINE_HOOK_STATUSES"
      :selected="selectedStatuses"
      :toggle-text="toggleText"
      :state="!invalidFeedback"
      multiple
      block
      @select="setSelectedStatuses"
    />
  </gl-form-group>
</template>
