<script>
import { GlButton, GlModal } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import { AGENT_MAPPING_STATUS_MAPPED, AGENT_MAPPING_STATUS_UNMAPPED } from '../constants';

const BUTTON_LABELS = {
  [AGENT_MAPPING_STATUS_MAPPED]: __('Block'),
  [AGENT_MAPPING_STATUS_UNMAPPED]: __('Allow'),
};

const CONFIRMATION_MODALS = {
  [AGENT_MAPPING_STATUS_MAPPED]: {
    title: s__('Workspaces|Block this agent for all group members?'),
    body: [
      s__(
        "Workspaces|Group members can't create a workspace with a blocked agent. Existing workspaces using this agent will continue to run and will not be affected by this.",
      ),
      s__(
        "Workspaces|Blocking an agent doesn't delete it. Agents can only be deleted in the project where they were created.",
      ),
    ],
    actionPrimary: {
      text: s__('Workspaces|Block agent'),
      attributes: {
        variant: 'danger',
      },
    },
    actionCancel: {
      text: __('Cancel'),
    },
  },
  [AGENT_MAPPING_STATUS_UNMAPPED]: {
    title: s__('Workspaces|Allow this agent for all group members?'),
    body: [s__('Workspaces|Group members can use allowed agents to create workspaces.')],
    actionPrimary: {
      text: s__('Workspaces|Allow agent'),
      attributes: {
        variant: 'confirm',
      },
    },
    actionCancel: {
      text: __('Cancel'),
    },
  },
};

export default {
  name: 'AgentMappingStatusToggle',
  components: {
    GlButton,
    GlModal,
  },
  props: {
    agent: {
      type: Object,
      required: true,
    },
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['toggle'],
  data() {
    return {
      blockModalVisible: false,
    };
  },
  computed: {
    buttonLabel() {
      return BUTTON_LABELS[this.agent.mappingStatus];
    },
    confirmationModal() {
      return CONFIRMATION_MODALS[this.agent.mappingStatus];
    },
  },
  methods: {
    toggleMappingStatus() {
      this.blockModalVisible = true;
    },
  },
};
</script>
<template>
  <span>
    <gl-button
      data-testid="agent-mapping-status-toggle"
      :loading="loading"
      @click="toggleMappingStatus"
      >{{ buttonLabel }}</gl-button
    >
    <gl-modal
      v-model="blockModalVisible"
      modal-id="blockAgentModal"
      :title="confirmationModal.title"
      :action-primary="confirmationModal.actionPrimary"
      :action-cancel="confirmationModal.actionCancel"
      @primary="$emit('toggle')"
    >
      <p v-for="(paragraph, index) in confirmationModal.body" :key="index">
        {{ paragraph }}
      </p>
    </gl-modal>
  </span>
</template>
