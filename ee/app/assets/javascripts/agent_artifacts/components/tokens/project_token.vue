<script>
import { createAlert } from '~/alert';
import { s__ } from '~/locale';
import ProjectTokenFoss from '~/vue_shared/components/filtered_search_bar/tokens/project_token.vue';
import getAgentArtifactsProjects from '../../graphql/queries/get_agent_artifacts_projects.query.graphql';

// This is a false violation of @gitlab/no-runtime-template-compiler, since it
// extends a valid Vue single file component.
// eslint-disable-next-line @gitlab/no-runtime-template-compiler
export default {
  name: 'ProjectTokenEE',
  extends: ProjectTokenFoss,
  inject: {
    groupFullPath: { default: null },
  },
  methods: {
    // eslint-disable-next-line vue/no-unused-properties -- This component inherits from `ProjectTokenFoss` which calls `fetchProjectsBySearchTerm()` internally
    async fetchProjectsBySearchTerm(search = '') {
      this.loading = true;

      try {
        const { data = {} } = await this.$apollo.query({
          query: getAgentArtifactsProjects,
          variables: { fullPath: this.groupFullPath, search },
        });

        this.projects = data.group?.projects?.nodes || [];
      } catch {
        createAlert({
          message: s__('AgentArtifacts|Failed to load projects.'),
        });
        this.projects = [];
      } finally {
        this.loading = false;
      }
    },
  },
};
</script>
