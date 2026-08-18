<script>
import { GlToken } from '@gitlab/ui';
import { __ } from '~/locale';
import {
  FLOW_TRIGGER_TYPES,
  FLOW_TRIGGER_TYPE_MERGE_REQUEST,
  FLOW_TRIGGER_TYPE_PIPELINE_HOOKS,
  FLOW_TRIGGER_TYPE_WORK_ITEM,
} from 'ee/ai/duo_agents_platform/constants';
import {
  mergeRequestActionLabels,
  normalizeMergeRequestEventTypes,
  pipelineStatusLabels,
  workItemActionLabels,
} from 'ee/ai/duo_agents_platform/utils';

// Builds the action/status labels appended to an event type's token, keyed by event type id.
const TOKEN_LABEL_BUILDERS = {
  [FLOW_TRIGGER_TYPE_PIPELINE_HOOKS.valueInt]: pipelineStatusLabels,
  [FLOW_TRIGGER_TYPE_MERGE_REQUEST.valueInt]: mergeRequestActionLabels,
  [FLOW_TRIGGER_TYPE_WORK_ITEM.valueInt]: workItemActionLabels,
};

export default {
  name: 'FlowTriggerEventTokens',
  components: {
    GlToken,
  },
  props: {
    flowTrigger: {
      type: Object,
      required: true,
    },
  },
  computed: {
    // Triggers are stored denormalized (merge_request_ready/code_conflict as their own event
    // types alongside merge_request). Fold them back into the single merge_request event type
    // so the tokens mirror the picker: one "Merge request" token listing its actions.
    tokens() {
      const { eventTypes, filter } = normalizeMergeRequestEventTypes({
        eventTypes: this.flowTrigger.eventTypes,
        filter: this.flowTrigger.filter,
      });

      if (!Array.isArray(eventTypes)) return [];

      return eventTypes.map((eventType) => ({
        eventType,
        text: this.tokenText(eventType, filter),
      }));
    },
  },
  methods: {
    tokenText(eventType, filter) {
      const baseName =
        FLOW_TRIGGER_TYPES.find((type) => type.valueInt === eventType)?.text || __('Unknown');

      const labels = TOKEN_LABEL_BUILDERS[eventType]?.(filter) ?? [];
      return labels.length ? `${baseName} (${labels.join(', ')})` : baseName;
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-flex-wrap gl-gap-2 gl-whitespace-nowrap">
    <gl-token v-for="token in tokens" :key="token.eventType" view-only>
      {{ token.text }}
    </gl-token>
  </div>
</template>
