<script>
import { logError } from '~/lib/logger';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPE_ORGANIZATION } from '~/graphql_shared/constants';
import { getSlotFunction, normalizeRender } from '~/lib/utils/vue3compat/normalize_render';
import getProjectDetailsQuery from '../graphql/queries/get_project_details.query.graphql';
import getWorkspacesNamespaceClusterAgents from '../graphql/queries/get_workspaces_namespace_cluster_agents.query.graphql';
import getWorkspacesOrganizationClusterAgents from '../graphql/queries/get_workspaces_organization_cluster_agents.query.graphql';

export default normalizeRender({
  inject: ['organizationId'],
  props: {
    projectFullPath: {
      type: String,
      required: false,
      default: '',
    },
  },
  emits: ['result', 'error'],
  apollo: {
    projectDetails: {
      query: getProjectDetailsQuery,
      variables() {
        return {
          projectFullPath: this.projectFullPath,
        };
      },
      skip() {
        return !this.projectFullPath;
      },
      update() {
        return [];
      },
      error(error) {
        logError(error);
      },
      async result(result) {
        if (result.error || !result.data.project) {
          this.$emit('error');
          return;
        }

        const { nameWithNamespace, repository, group, id } = result.data.project;

        const rootRef = repository ? repository.rootRef : null;

        if (!group) {
          // Guard clause: do not attempt to find agents if project does not have a group
          this.$emit('result', {
            id,
            fullPath: this.projectFullPath,
            nameWithNamespace,
            clusterAgents: [],
            rootRef,
          });
          return;
        }

        const { clusterAgents, errors } = await this.fetchClusterAgents(
          this.organizationId,
          group.fullPath,
        );

        if (Array.isArray(errors) && errors.length) {
          errors.forEach((error) => logError(error));
          this.$emit('error');
          return;
        }

        this.$emit('result', {
          id,
          fullPath: this.projectFullPath,
          nameWithNamespace,
          clusterAgents,
          rootRef,
        });
      },
    },
  },
  methods: {
    async fetchClusterAgents(organizationId, namespace) {
      try {
        // Execute both queries in parallel
        const [namespaceResult, organizationResult] = await Promise.all([
          this.$apollo.query({
            query: getWorkspacesNamespaceClusterAgents,
            variables: {
              namespace,
            },
          }),

          this.$apollo.query({
            query: getWorkspacesOrganizationClusterAgents,
            variables: {
              organizationID: convertToGraphQLId(TYPE_ORGANIZATION, organizationId),
            },
          }),
        ]);

        // Check for errors in either result
        if (namespaceResult.error || organizationResult.error) {
          return {
            errors: [namespaceResult.error, organizationResult.error].filter(Boolean),
          };
        }

        const organizationAgents = this.mapAgents(organizationResult.data.organizationAgents);
        const namespaceAgents = this.mapAgents(namespaceResult.data.namespaceAgents);

        // Some agents mapped at the org level might also be mapped on the namespace level
        // we should remove duplicates
        const seenIds = new Set();
        const allClusterAgents = [...organizationAgents, ...namespaceAgents].filter(
          (agent) => !seenIds.has(agent.value) && seenIds.add(agent.value),
        );

        return {
          clusterAgents: allClusterAgents,
        };
      } catch (error) {
        return { errors: [error] };
      }
    },
    mapAgents(agents) {
      const nodes = agents?.workspacesClusterAgents?.nodes || [];
      return nodes.map(({ id, name, project }) => ({
        value: id,
        text: project ? `${project.nameWithNamespace} / ${name}` : name,
        // Organization agents may have private projects that we do not have access to
      }));
    },
  },
  render() {
    return getSlotFunction(this)?.();
  },
});
</script>
