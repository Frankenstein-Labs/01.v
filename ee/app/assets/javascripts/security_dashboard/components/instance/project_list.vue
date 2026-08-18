<script>
import { GlBadge, GlButton, GlLoadingIcon, GlTooltipDirective } from '@gitlab/ui';
import projectsQuery from 'ee/security_dashboard/graphql/queries/instance_projects.query.graphql';
import { PROJECT_LOADING_ERROR_MESSAGE } from 'ee/security_dashboard/helpers';
import { createAlert } from '~/alert';
import { s__ } from '~/locale';
import ProjectAvatar from '~/vue_shared/components/project_avatar.vue';

export default {
  i18n: {
    projectsAdded: s__('SecurityReports|Projects added'),
    removeLabel: s__('SecurityReports|Remove project from dashboard'),
    emptyMessage: s__(
      'SecurityReports|Select a project to add by using the project search field above.',
    ),
  },
  components: {
    GlBadge,
    GlButton,
    GlLoadingIcon,
    ProjectAvatar,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  emits: ['project-removed'],
  apollo: {
    projects: {
      query: projectsQuery,
      update(data) {
        const projects = data?.instance?.projects?.edges?.map((p) => p.node);

        if (projects === undefined) {
          this.showErrorFlash();
        }

        return projects || [];
      },
      error() {
        this.showErrorFlash();
      },
    },
  },
  data() {
    return {
      projects: [],
    };
  },
  computed: {
    isLoadingProjects() {
      return this.$apollo.queries.projects.loading;
    },
  },
  methods: {
    projectRemoved(project) {
      this.$emit('project-removed', project);
    },
    showErrorFlash() {
      createAlert({ message: PROJECT_LOADING_ERROR_MESSAGE });
    },
  },
};
</script>

<template>
  <section>
    <h5
      class="gl-mb-5 gl-border-b-1 gl-border-b-default gl-pb-3 gl-font-bold gl-text-subtle gl-border-b-solid"
    >
      {{ $options.i18n.projectsAdded }}
      <gl-badge class="gl-font-bold">{{ projects.length }}</gl-badge>
    </h5>
    <gl-loading-icon v-if="isLoadingProjects" size="lg" />
    <ul v-else-if="projects.length" class="gl-p-0">
      <li
        v-for="project in projects"
        :key="project.id"
        class="js-projects-list-project-item gl-flex gl-items-center gl-py-2"
      >
        <project-avatar
          class="gl-mr-3"
          :project-id="project.id"
          :project-name="project.name"
          :project-avatar-url="project.avatarUrl"
        />
        {{ project.nameWithNamespace }}
        <gl-button
          v-gl-tooltip
          icon="remove"
          class="js-projects-list-project-remove gl-ml-auto"
          :title="$options.i18n.removeLabel"
          :aria-label="$options.i18n.removeLabel"
          @click="projectRemoved(project)"
        />
      </li>
    </ul>
    <p v-else class="js-projects-list-empty-message gl-text-subtle" data-testid="empty-message">
      {{ $options.i18n.emptyMessage }}
    </p>
  </section>
</template>
