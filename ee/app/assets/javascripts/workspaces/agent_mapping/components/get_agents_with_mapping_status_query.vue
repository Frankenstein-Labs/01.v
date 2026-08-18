<script>
import { logError } from '~/lib/logger';
import { getSlotFunction, normalizeRender } from '~/lib/utils/vue3compat/normalize_render';
import getAgentsWithAuthorizationStatusQuery from '../graphql/queries/get_agents_with_mapping_status.query.graphql';
import { AGENT_MAPPING_STATUS_MAPPED, AGENT_MAPPING_STATUS_UNMAPPED } from '../constants';

export default normalizeRender({
  props: {
    namespace: {
      type: String,
      required: false,
      default: '',
    },
  },
  emits: ['result', 'error'],
  apollo: {
    getGroupClusterAgents: {
      query: getAgentsWithAuthorizationStatusQuery,
      variables() {
        return {
          namespace: this.namespace,
        };
      },
      skip() {
        return !this.namespace;
      },
      update() {
        return [];
      },
      error(error) {
        logError(error);
      },
      result(result) {
        if (result.error) {
          this.$emit('error', { error: result.error });
          return;
        }

        if (!result?.data?.namespace) {
          this.$emit('error');
          return;
        }

        const { mappedAgents, unmappedAgents, id: namespaceId } = result.data.namespace;

        const agents = [];

        agents.push(
          ...(mappedAgents.nodes.map((agent) => ({
            ...agent,
            mappingStatus: AGENT_MAPPING_STATUS_MAPPED,
          })) || []),
        );

        agents.push(
          ...(unmappedAgents.nodes.map((agent) => ({
            ...agent,
            mappingStatus: AGENT_MAPPING_STATUS_UNMAPPED,
          })) || []),
        );

        this.$emit('result', { namespaceId, agents });
      },
    },
  },
  render() {
    return getSlotFunction(this)?.({ loading: this.$apollo.loading });
  },
});
</script>
