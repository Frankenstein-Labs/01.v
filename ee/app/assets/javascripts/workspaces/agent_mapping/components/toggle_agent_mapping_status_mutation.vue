<script>
import produce from 'immer';
import { createAlert, VARIANT_WARNING } from '~/alert';
import { logError } from '~/lib/logger';
import { getSlotFunction, normalizeRender } from '~/lib/utils/vue3compat/normalize_render';
import { s__, __ } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import createClusterAgentMappingMutation from '../graphql/mutations/create_cluster_agent_mapping.mutation.graphql';
import deleteClusterAgentMappingMutation from '../graphql/mutations/delete_cluster_agent_mapping.mutation.graphql';
import getAgentsWithAuthorizationStatusQuery from '../graphql/queries/get_agents_with_mapping_status.query.graphql';
import {
  AGENT_MAPPING_STATUS_MAPPED,
  AGENT_MAPPING_STATUS_UNMAPPED,
  ALERT_CONTAINER_CLASSNAME,
} from '../constants';

const MAPPING_STATUS_MUTATION = {
  [AGENT_MAPPING_STATUS_MAPPED]: deleteClusterAgentMappingMutation,
  [AGENT_MAPPING_STATUS_UNMAPPED]: createClusterAgentMappingMutation,
};
const TOGGLE_WARNING_MESSAGE = {
  [AGENT_MAPPING_STATUS_UNMAPPED]: s__('Workspaces|This agent is already allowed.'),
  [AGENT_MAPPING_STATUS_MAPPED]: s__('Workspaces|This agent is already blocked.'),
};
const REFRESH_PAGE_MESSAGE = __('Refresh the page and try again.');

const extractErrorFromMutationResult = (result, mutation) => {
  switch (mutation) {
    case deleteClusterAgentMappingMutation:
      return result.data.namespaceDeleteRemoteDevelopmentClusterAgentMapping.errors;
    case createClusterAgentMappingMutation:
      return result.data.namespaceCreateRemoteDevelopmentClusterAgentMapping.errors;
    default:
      return [];
  }
};

export default normalizeRender({
  inject: {
    namespace: {
      default: '',
    },
  },
  props: {
    namespaceId: {
      type: String,
      required: true,
    },
    agent: {
      type: Object,
      required: true,
    },
  },
  emits: ['error'],
  data() {
    return {
      loading: false,
    };
  },
  methods: {
    async execute() {
      const { agent, namespace } = this;
      const mutation = MAPPING_STATUS_MUTATION[agent.mappingStatus];
      const warningMessage = TOGGLE_WARNING_MESSAGE[agent.mappingStatus];

      try {
        this.loading = true;

        await this.$apollo.mutate({
          mutation,
          variables: {
            input: {
              clusterAgentId: this.agent.id,
              namespaceId: this.namespaceId,
            },
          },
          update(store, result) {
            const errors = extractErrorFromMutationResult(result, mutation) || [];

            if (errors.length) {
              createAlert({
                title: s__('Workspaces|Unable to complete this action'),
                message: `${warningMessage} ${REFRESH_PAGE_MESSAGE}`,
                containerSelector: `.${ALERT_CONTAINER_CLASSNAME}`,
                variant: VARIANT_WARNING,
              });
              return;
            }

            store.updateQuery(
              {
                query: getAgentsWithAuthorizationStatusQuery,
                variables: { namespace },
              },
              (sourceData) =>
                produce(sourceData, (draftData) => {
                  const { mappedAgents, unmappedAgents } = draftData.namespace;

                  let addTo;
                  let removeFrom;

                  if (agent.mappingStatus === AGENT_MAPPING_STATUS_MAPPED) {
                    addTo = unmappedAgents;
                    removeFrom = mappedAgents;
                  } else {
                    addTo = mappedAgents;
                    removeFrom = unmappedAgents;
                  }

                  const targetAgentIndex = removeFrom.nodes.findIndex(
                    (node) => node.id === agent.id,
                  );

                  addTo.nodes.push(removeFrom.nodes[targetAgentIndex]);
                  removeFrom.nodes.splice(targetAgentIndex, 1);
                }),
            );
          },
        });
      } catch (e) {
        Sentry.captureException(e);
        logError(e);
        this.$emit('error', e);
      } finally {
        this.loading = false;
      }
    },
  },
  render() {
    return getSlotFunction(this)?.({ loading: this.loading, execute: this.execute });
  },
});
</script>
