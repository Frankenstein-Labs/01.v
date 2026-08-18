<script>
import { GlLoadingIcon, GlBadge, GlTable } from '@gitlab/ui';
import { __ } from '~/locale';
import SafeHtml from '~/vue_shared/directives/safe_html';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import { AGENT_MAPPING_STATUS_MAPPED, AGENT_MAPPING_STATUS_UNMAPPED } from '../constants';
import AgentDetailsPopover from './agent_details_popover.vue';
import AgentMappingStatusToggle from './agent_mapping_status_toggle.vue';
import ToggleAgentMappingStatusMutation from './toggle_agent_mapping_status_mutation.vue';

const AGENT_MAPPING_STATUS_BADGES = {
  [AGENT_MAPPING_STATUS_MAPPED]: {
    text: __('Allowed'),
    variant: 'success',
  },
  [AGENT_MAPPING_STATUS_UNMAPPED]: {
    text: __('Blocked'),
    variant: 'danger',
  },
};

const NAME_FIELD = {
  key: 'name',
  label: __('Name'),
  sortable: true,
  thClass: 'gl-w-3/4',
};

const MAPPING_STATUS_LABEL_FIELD = {
  key: 'mappingStatusLabel',
  label: __('Availability'),
  sortable: true,
  thClass: 'gl-w-3/20',
};

const MAPPING_ACTIONS_FIELD = {
  key: 'actions',
  label: __('Action'),
  sortable: false,
  thClass: 'gl-w-3/10',
};

export default {
  name: 'AgentsTable',
  components: {
    GlBadge,
    GlLoadingIcon,
    GlTable,
    CrudComponent,
    AgentDetailsPopover,
    AgentMappingStatusToggle,
    ToggleAgentMappingStatusMutation,
  },
  directives: {
    SafeHtml,
  },
  inject: {
    canAdminClusterAgentMapping: {
      default: false,
    },
  },
  props: {
    agents: {
      type: Array,
      required: true,
    },
    namespaceId: {
      type: String,
      required: true,
    },
    emptyStateMessage: {
      type: String,
      required: true,
    },
    isLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
    displayMappingStatus: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    agentsWithStatusLabels() {
      return this.agents.map((agent) => ({
        ...agent,
        statusBadge: {
          ...AGENT_MAPPING_STATUS_BADGES[agent.mappingStatus],
        },
      }));
    },
    fields() {
      const fields = [NAME_FIELD];

      if (this.displayMappingStatus) {
        fields.push(MAPPING_STATUS_LABEL_FIELD);
      }

      if (this.canAdminClusterAgentMapping) {
        fields.push(MAPPING_ACTIONS_FIELD);
      }

      return fields;
    },
  },
};
</script>
<template>
  <crud-component :title="s__('Workspaces|Agents')" icon="kubernetes" :count="agents.length">
    <gl-loading-icon v-if="isLoading" size="md" />
    <gl-table v-else :fields="fields" :items="agentsWithStatusLabels" show-empty stacked="sm">
      <template #empty>
        <div v-safe-html="emptyStateMessage" class="!gl-text-center"></div>
      </template>
      <template #cell(name)="{ item }">
        <span id="agent-name" data-testid="agent-name">{{ item.name }}</span>
        <agent-details-popover :agent="item" />
      </template>
      <template v-if="displayMappingStatus" #cell(mappingStatusLabel)="{ item }">
        <gl-badge :variant="item.statusBadge.variant" data-testid="agent-mapping-status-label">{{
          item.statusBadge.text
        }}</gl-badge>
      </template>
      <template v-if="canAdminClusterAgentMapping" #cell(actions)="{ item }">
        <toggle-agent-mapping-status-mutation :namespace-id="namespaceId" :agent="item">
          <template #default="{ execute, loading }">
            <agent-mapping-status-toggle :agent="item" :loading="loading" @toggle="execute" />
          </template>
        </toggle-agent-mapping-status-mutation>
      </template>
    </gl-table>
  </crud-component>
</template>
