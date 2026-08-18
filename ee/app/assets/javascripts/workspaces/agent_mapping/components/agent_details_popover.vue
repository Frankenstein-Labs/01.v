<script>
import { GlButton, GlBadge, GlPopover } from '@gitlab/ui';
import { uniqueId } from 'lodash-es';
import { __ } from '~/locale';
import AgentDataLabel from './agent_data_label.vue';

export default {
  name: 'AgentDetailsPopover',
  components: {
    GlButton,
    GlBadge,
    GlPopover,
    AgentDataLabel,
  },
  props: {
    agent: {
      type: Object,
      required: true,
    },
  },
  computed: {
    isConnected() {
      return this.agent.connections.nodes.length > 0;
    },
    badgeVariant() {
      return this.isConnected ? 'success' : 'neutral';
    },
    badgeLabel() {
      return this.isConnected ? __('Connected') : __('Not Connected');
    },
    buttonId() {
      return uniqueId('Agent-Details-Popover-');
    },
  },
};
</script>
<template>
  <span>
    <gl-button
      :id="buttonId"
      icon="information-o"
      variant="default"
      category="tertiary"
      size="small"
      :aria-label="__('Agent Information')"
    />
    <gl-popover
      triggers="hover focus"
      :title="agent.name"
      show-close-button
      placement="top"
      :target="buttonId"
      data-testid="agent-name"
    >
      <div class="popover-content">
        <agent-data-label :label="__('Created in')">{{ agent.project.name }}</agent-data-label>

        <agent-data-label :label="__('Status')">
          <gl-badge :variant="badgeVariant">
            {{ badgeLabel }}
          </gl-badge>
        </agent-data-label>
      </div>
    </gl-popover>
  </span>
</template>
