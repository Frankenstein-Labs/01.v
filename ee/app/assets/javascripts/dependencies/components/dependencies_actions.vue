<script>
import { defineAsyncComponent } from 'vue';
import { GlSorting } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapState } from 'vuex';
import { __ } from '~/locale';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { NAMESPACE_PROJECT, NAMESPACE_GROUP } from '../constants';
import { SORT_FIELDS, SORT_ASCENDING } from '../store/constants';

export default {
  i18n: {
    sortDirectionLabel: __('Sort direction'),
  },
  name: 'DependenciesActions',
  components: {
    GlSorting,
    GroupDependenciesFilteredSearch: defineAsyncComponent(
      () =>
        import('ee/dependencies/components/filtered_search/group_dependencies_filtered_search.vue'),
    ),
    ProjectDependenciesFilteredSearch: defineAsyncComponent(
      () =>
        import('ee/dependencies/components/filtered_search/project_dependencies_filtered_search.vue'),
    ),
  },
  mixins: [glFeatureFlagsMixin()],
  inject: ['namespaceType'],
  computed: {
    isSortAscending() {
      return this.sortOrder === SORT_ASCENDING;
    },
    ...mapState(['sortField', 'sortOrder']),
    sortFieldName() {
      return SORT_FIELDS[this.sortField];
    },
    sortOptions() {
      return Object.keys(SORT_FIELDS).map((key) => ({
        text: SORT_FIELDS[key],
        value: key,
      }));
    },
    isSupportedNamespace() {
      if (this.namespaceType === NAMESPACE_GROUP || this.namespaceType === NAMESPACE_PROJECT) {
        return true;
      }

      return false;
    },
    dependenciesFilteredSearchComponent() {
      return this.namespaceType === NAMESPACE_PROJECT
        ? 'ProjectDependenciesFilteredSearch'
        : 'GroupDependenciesFilteredSearch';
    },
  },
  methods: {
    ...mapActions(['fetchDependencies', 'fetchDependenciesViaGraphQL']),
    ...mapActions({
      setSortField(dispatch, field) {
        dispatch(`setSortField`, field);
        this.fetchDependenciesWithFeatureFlag();
      },
      toggleSortOrder(dispatch) {
        dispatch(`toggleSortOrder`);
        this.fetchDependenciesWithFeatureFlag();
      },
    }),
    fetchDependenciesWithFeatureFlag() {
      if (this.namespaceType === NAMESPACE_PROJECT) {
        this.fetchDependenciesViaGraphQL();
      } else {
        this.fetchDependencies();
      }
    },
  },
};
</script>

<template>
  <div
    class="gl-flex gl-items-start gl-border-t-1 gl-border-default gl-bg-subtle gl-p-5 gl-border-t-solid"
  >
    <component
      :is="dependenciesFilteredSearchComponent"
      v-if="isSupportedNamespace"
      class="gl-mr-3 gl-min-w-0 gl-grow"
    />
    <gl-sorting
      :text="sortFieldName"
      :is-ascending="isSortAscending"
      :sort-direction-tool-tip="$options.i18n.sortDirectionLabel"
      :sort-options="sortOptions"
      :sort-by="sortField"
      class="gl-ml-auto"
      @sortDirectionChange="toggleSortOrder"
      @sortByChange="setSortField"
    />
  </div>
</template>
