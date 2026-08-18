<script>
import { GlCollapsibleListbox, GlLink, GlSprintf } from '@gitlab/ui';
import { createAlert } from '~/alert';
import { __, s__ } from '~/locale';
import { MINIMUM_SEARCH_LENGTH } from '~/graphql_shared/constants';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { DEBOUNCE_DELAY } from '~/vue_shared/components/filtered_search_bar/constants';
import { helpPagePath } from '~/helpers/help_page_helper';
import { visitUrl, setUrlParams } from '~/lib/utils/url_utility';
import searchNamespacesWhereUserCanCreateProjectsQuery from '~/projects/new/queries/search_namespaces_where_user_can_create_projects.query.graphql';

export default {
  name: 'GroupTemplatesGroupSelector',
  components: {
    GlCollapsibleListbox,
    GlLink,
    GlSprintf,
  },
  inject: ['newProjectPath'],
  apollo: {
    currentUser: {
      query: searchNamespacesWhereUserCanCreateProjectsQuery,
      variables() {
        return { search: this.search };
      },
      skip() {
        return (
          this.shouldSkipQuery ||
          (this.search.length > 0 && this.search.length < MINIMUM_SEARCH_LENGTH)
        );
      },
      debounce: DEBOUNCE_DELAY,
      error() {
        createAlert({ message: this.$options.i18n.errorMessage });
      },
    },
  },
  data() {
    return {
      currentUser: {},
      search: '',
      shouldSkipQuery: true,
      selected: '',
    };
  },
  computed: {
    groups() {
      return this.currentUser.groups?.nodes || [];
    },
    items() {
      return this.groups.map((group) => ({
        value: group.id,
        text: group.fullPath,
      }));
    },
    loading() {
      return this.$apollo.queries.currentUser.loading;
    },
    toggleText() {
      if (!this.selected) {
        return this.$options.i18n.placeholder;
      }
      const group = this.groups.find((g) => g.id === this.selected);
      return group?.fullPath || this.$options.i18n.placeholder;
    },
  },
  methods: {
    handleShown() {
      if (this.shouldSkipQuery) {
        this.shouldSkipQuery = false;
      }
    },
    handleSelect(groupId) {
      this.selected = groupId;
      const group = this.groups.find((g) => g.id === groupId);
      if (group) {
        const url = setUrlParams(
          { namespace_id: getIdFromGraphQLId(group.id), tab: 'group' },
          { url: `${window.location.origin}${this.newProjectPath}` },
        );
        visitUrl(`${url}#create_from_template`);
      }
    },
    handleSearch(query) {
      this.search = query;
    },
  },
  i18n: {
    title: s__('ProjectsNew|Select a group to view its project templates'),
    description: s__(
      'ProjectsNew|To view group-level project templates, select a group that has %{linkStart}custom project templates configured%{linkEnd}.',
    ),
    placeholder: s__('ProjectsNew|Select a group'),
    noResults: __('No matches found'),
    errorMessage: s__('ProjectsNew|An error occurred while loading groups.'),
  },
  docsPath: helpPagePath('user/group/custom_project_templates.md'),
};
</script>

<template>
  <div
    class="gl-flex gl-flex-col gl-items-center gl-p-5"
    data-testid="group-templates-group-selector"
  >
    <p class="gl-mb-2 gl-font-bold">{{ $options.i18n.title }}</p>
    <p class="gl-mb-5 gl-text-secondary">
      <gl-sprintf :message="$options.i18n.description">
        <template #link="{ content }">
          <gl-link :href="$options.docsPath" target="_blank">{{ content }}</gl-link>
        </template>
      </gl-sprintf>
    </p>
    <gl-collapsible-listbox
      searchable
      :searching="loading"
      :items="items"
      :selected="selected"
      :toggle-text="toggleText"
      :no-results-text="$options.i18n.noResults"
      :aria-label="$options.i18n.placeholder"
      positioning-strategy="fixed"
      data-testid="group-templates-group-select"
      @shown="handleShown"
      @select="handleSelect"
      @search="handleSearch"
    />
  </div>
</template>
