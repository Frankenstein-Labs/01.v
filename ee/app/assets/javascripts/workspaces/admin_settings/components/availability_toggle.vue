<script>
import { GlToggle } from '@gitlab/ui';
import produce from 'immer';
import { s__ } from '~/locale';
import { logError } from '~/lib/logger';

import createClusterAgentMappingMutation from '../graphql/mutations/create_org_cluster_agent_mapping.mutation.graphql';
import deleteClusterAgentMappingMutation from '../graphql/mutations/delete_org_cluster_agent_mapping.mutation.graphql';
import mappedOrganizationClusterAgentsQuery from '../graphql/queries/organization_mapped_agents.query.graphql';

export default {
  name: 'ClusterAgentAvailabilityToggle',
  components: {
    GlToggle,
  },
  inject: {
    organizationId: {
      type: String,
      default: '',
    },
  },
  props: {
    agentId: {
      type: String,
      required: true,
    },
    isMapped: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      loading: false,
      errorMessage: '',
    };
  },
  computed: {
    availabilityText() {
      return this.isMapped ? s__('Workspaces|Available') : s__('Workspaces|Blocked');
    },
  },
  methods: {
    updateMappedAgentsStore(store, agentId, isAgentMapped) {
      store.updateQuery(
        {
          query: mappedOrganizationClusterAgentsQuery,
          variables: { organizationId: this.organizationId },
        },
        (sourceData) =>
          produce(sourceData, (draftData) => {
            const { mappedAgents } = draftData.organization;

            if (!isAgentMapped) {
              mappedAgents.nodes.push({ id: agentId });
            } else {
              const updatedMappedAgents = mappedAgents.nodes.filter(
                (agent) => agent.id !== agentId,
              );
              mappedAgents.nodes = updatedMappedAgents;
            }
          }),
      );
    },
    async toggleAvailability() {
      const { organizationId, agentId, updateMappedAgentsStore, isMapped } = this;
      const isDeleting = isMapped;

      const mutation = isDeleting
        ? deleteClusterAgentMappingMutation
        : createClusterAgentMappingMutation;
      try {
        // reset states
        this.loading = true;
        this.errorMessage = '';

        await this.$apollo.mutate({
          mutation,
          variables: {
            input: {
              clusterAgentId: agentId,
              organizationId,
            },
          },
          update(store, result) {
            const { data } = result;
            const errors = isDeleting
              ? data.organizationDeleteClusterAgentMapping.errors
              : data.organizationCreateClusterAgentMapping.errors;

            if (errors?.length) {
              throw new Error(errors);
            }

            updateMappedAgentsStore(store, agentId, isMapped);
          },
        });
      } catch (e) {
        logError(`Error updating Workspaces agent availability`, e.message);
        this.errorMessage = s__('Workspaces|Unable to complete request. Please try again.');
      } finally {
        this.loading = false;
      }
    },
  },
};
</script>
<template>
  <div class="gl-flex gl-flex-col gl-gap-3">
    <div class="gl-flex gl-items-center gl-gap-3">
      <gl-toggle
        :value="isMapped"
        :disabled="loading"
        :label="availabilityText"
        label-position="hidden"
        class="!gl-flex-row"
        @change="toggleAvailability"
      />
      <p data-test-id="availability-text" class="gl-mb-0">{{ availabilityText }}</p>
    </div>
    <p
      v-if="errorMessage"
      data-test-id="error-message"
      class="gl-max-w-2/3 gl-mb-0 gl-text-base gl-text-danger"
    >
      {{ errorMessage }}
    </p>
  </div>
</template>
