<script>
import { GlButton, GlLink, GlTruncate, GlCollapsibleListbox, GlAvatar } from '@gitlab/ui';
import { debounce } from 'lodash-es';
import { n__, sprintf } from '~/locale';
import { projectDependenciesPath } from 'ee/lib/utils/path_helpers/project';
import { filterBySearchTerm } from '~/analytics/shared/utils';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { AVATAR_SHAPE_OPTION_RECT } from '~/vue_shared/constants';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { extractGroupNamespace } from 'ee/dependencies/store/utils';
import getProjects from '../graphql/projects.query.graphql';
import { SEARCH_MIN_THRESHOLD } from './constants';

const mapItemToListboxFormat = (item) => ({ ...item, value: item.id, text: item.name });

export default {
  name: 'DependencyProjectCount',
  components: {
    GlButton,
    GlLink,
    GlTruncate,
    GlCollapsibleListbox,
    GlAvatar,
  },
  inject: ['endpoint'],
  props: {
    projectCount: {
      type: Number,
      required: true,
    },
    componentId: {
      type: Number,
      required: true,
    },
  },
  data() {
    return {
      loading: false,
      projects: [],
      searchTerm: '',
    };
  },
  computed: {
    headerText() {
      return sprintf(
        n__(
          'Dependencies|%{projectCount} project',
          'Dependencies|%{projectCount} projects',
          this.projectCount,
        ),
        { projectCount: this.projectCount },
      );
    },
    availableProjects() {
      return filterBySearchTerm(this.projects, this.searchTerm);
    },
    searchEnabled() {
      return this.loading || this.projectCount > SEARCH_MIN_THRESHOLD;
    },
  },
  methods: {
    search: debounce(function debouncedSearch(searchTerm) {
      this.searchTerm = searchTerm;
      this.fetchData();
    }, DEFAULT_DEBOUNCE_AND_THROTTLE_MS),
    onHide() {
      this.searchTerm = '';
    },
    onShown() {
      this.fetchData();
    },
    async fetchData() {
      this.loading = true;

      const response = await this.$apollo.query({
        query: getProjects,
        variables: {
          groupFullPath: this.groupNamespace(),
          search: this.searchTerm,
          first: 50,
          includeSubgroups: true,
          sbomComponentId: this.componentId,
        },
      });

      const { nodes } = response.data.group.projects;

      this.loading = false;
      this.projects = nodes.map(mapItemToListboxFormat);
    },
    getEntityId(project) {
      return getIdFromGraphQLId(project.id);
    },
    getUrl(project) {
      return projectDependenciesPath(project.fullPath);
    },
    groupNamespace() {
      return extractGroupNamespace(this.endpoint);
    },
  },
  AVATAR_SHAPE_OPTION_RECT,
};
</script>

<template>
  <gl-collapsible-listbox
    :header-text="headerText"
    :items="availableProjects"
    :searching="loading"
    :searchable="searchEnabled"
    @hidden="onHide"
    @search="search"
    @shown="onShown"
  >
    <template #toggle>
      <gl-button variant="link" category="tertiary" icon="project" data-testid="toggle-text">
        <span class="@md/panel:gl-hidden">{{ projectCount }}</span>
        <span class="gl-hidden @md/panel:gl-inline-flex">{{ headerText }}</span>
      </gl-button>
    </template>
    <template #list-item="{ item }">
      <gl-link :href="getUrl(item)" class="gl-flex gl-gap-3 hover:gl-no-underline">
        <gl-avatar
          class="gl-align-middle"
          :alt="item.name"
          :size="16"
          :entity-id="getEntityId(item)"
          :entity-name="item.name"
          :src="item.avatarUrl"
          :shape="$options.AVATAR_SHAPE_OPTION_RECT"
        />
        <gl-truncate position="end" :text="item.name" with-tooltip class="gl-min-w-0" />
      </gl-link>
    </template>
  </gl-collapsible-listbox>
</template>
