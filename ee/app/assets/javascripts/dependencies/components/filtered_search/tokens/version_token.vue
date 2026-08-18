<script>
import {
  GlFilteredSearchToken,
  GlFilteredSearchSuggestion,
  GlIcon,
  GlLoadingIcon,
  GlIntersperse,
  GlIntersectionObserver,
} from '@gitlab/ui';
import produce from 'immer';
// eslint-disable-next-line no-restricted-imports
import { mapGetters } from 'vuex';
import { createAlert } from '~/alert';
import { s__ } from '~/locale';
import { NAMESPACE_GROUP } from 'ee/dependencies/constants';
import getProjectComponentVersions from 'ee/dependencies/graphql/project_component_versions.query.graphql';
import getGroupComponentVersions from 'ee/dependencies/graphql/group_component_versions.query.graphql';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';

export default {
  components: {
    GlFilteredSearchToken,
    GlFilteredSearchSuggestion,
    GlIcon,
    GlLoadingIcon,
    GlIntersperse,
    GlIntersectionObserver,
  },
  mixins: [glListenersMixin],
  inject: ['fullPath', 'namespaceType'],
  props: {
    config: {
      type: Object,
      required: true,
    },
    value: {
      type: Object,
      required: true,
    },
    active: {
      type: Boolean,
      required: true,
    },
  },
  emits: ['destroy'],
  data() {
    return {
      versions: [],
      selectedVersions: [],
      pageInfo: {},
    };
  },
  apollo: {
    versions: {
      query() {
        return this.namespaceType === NAMESPACE_GROUP
          ? getGroupComponentVersions
          : getProjectComponentVersions;
      },
      variables() {
        return this.queryVariables;
      },
      update(data) {
        return data.namespace.componentVersions.nodes.map(({ version, id }) => ({
          version,
          id,
        }));
      },
      result({ data }) {
        this.pageInfo = data?.namespace.componentVersions.pageInfo || {};
      },
      skip() {
        return this.viewOnly;
      },
      error() {
        this.showError();
      },
    },
  },
  computed: {
    ...mapGetters(['componentNames']),
    tokenValue() {
      return {
        ...this.value,
        // when the token is active (dropdown is open), we set the value to null to prevent an UX issue
        // in which only the last selected item is being displayed.
        // more information: https://gitlab.com/gitlab-org/gitlab-services/design.gitlab.com/-/issues/2467
        data: this.active ? '' : this.selectedVersions,
      };
    },
    tokenConfig() {
      // When viewOnly is true, we want to show a placeholder in #suggestions.
      // This is not possible with the multiple operators config, so we pass only the first operator in that case.
      if (this.viewOnly) {
        return {
          ...this.config,
          operators: [this.config.operators[0]],
        };
      }
      return this.config;
    },
    queryVariables() {
      return {
        componentName: this.componentNames[0],
        fullPath: this.fullPath,
      };
    },
    noSelectedComponent() {
      return this.componentNames.length === 0;
    },
    multipleSelectedComponents() {
      return this.componentNames.length > 1;
    },
    viewOnly() {
      return this.noSelectedComponent || this.multipleSelectedComponents;
    },
    isLoading() {
      return this.$apollo.queries.versions.loading;
    },
    hasNextPage() {
      return this.pageInfo.hasNextPage;
    },
  },
  watch: {
    componentNames(newVal, oldVal) {
      // If the component token is opened after applying a version, the version token
      // must be destroyed because it depends on which component is selected.
      if (newVal.length !== oldVal.length) {
        this.$emit('destroy');
      }
    },
  },
  methods: {
    isVersionSelected(version) {
      return this.selectedVersions.includes(version);
    },
    toggleSelectedVersion(version) {
      if (this.isVersionSelected(version)) {
        this.selectedVersions = this.selectedVersions.filter((v) => v !== version);
      } else {
        this.selectedVersions.push(version);
      }
    },
    bottomReached() {
      if (this.isLoading) return;

      this.$apollo.queries.versions
        .fetchMore({
          variables: { after: this.pageInfo.endCursor },
          updateQuery(previousResult, { fetchMoreResult }) {
            return produce(fetchMoreResult, (draftData) => {
              draftData.namespace.componentVersions.nodes = [
                ...previousResult.namespace.componentVersions.nodes,
                ...draftData.namespace.componentVersions.nodes,
              ];
            });
          },
        })
        .catch(this.showError);
    },
    showError() {
      createAlert({
        message: s__(
          'Dependencies|There was an error fetching the versions for the selected component. Please try again later.',
        ),
      });
    },
  },
};
</script>

<template>
  <gl-filtered-search-token
    :config="tokenConfig"
    v-bind="{ ...$props, ...$attrs }"
    :multi-select-values="selectedVersions"
    :value="tokenValue"
    :view-only="viewOnly"
    v-on="glListeners()"
    @select="toggleSelectedVersion"
  >
    <template #view>
      <gl-intersperse data-testid="selected-versions">
        <span v-for="version in selectedVersions" :key="version">{{ version }}</span>
      </gl-intersperse>
    </template>
    <template #suggestions>
      <div v-if="noSelectedComponent" class="gl-p-2 gl-text-subtle">
        {{ s__('Dependencies|To filter by version, filter by one component first') }}
      </div>
      <div v-else-if="multipleSelectedComponents" class="gl-p-2 gl-text-subtle">
        {{ s__('Dependencies|To filter by version, select exactly one component first') }}
      </div>
      <template v-else>
        <gl-filtered-search-suggestion
          v-for="{ version, id } in versions"
          :key="id"
          :value="version"
        >
          <div class="gl-flex gl-items-center">
            <gl-icon
              name="check"
              class="gl-mr-3 gl-shrink-0"
              :class="{
                'gl-invisible': !isVersionSelected(version),
              }"
              variant="subtle"
            />
            {{ version }}
          </div>
        </gl-filtered-search-suggestion>
        <gl-loading-icon v-if="isLoading" size="sm" />
        <gl-intersection-observer v-if="hasNextPage" @appear="bottomReached" />
      </template>
    </template>
  </gl-filtered-search-token>
</template>
