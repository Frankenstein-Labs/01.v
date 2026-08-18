<script>
import {
  GlDrawer,
  GlTruncateText,
  GlBadge,
  GlAlert,
  GlCollapsibleListbox,
  GlSkeletonLoader,
  GlKeysetPagination,
} from '@gitlab/ui';
import { s__ } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import { getContentWrapperHeight } from '~/lib/utils/dom_utils';
import { TYPENAME_SBOM_OCCURRENCE } from 'ee/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import getDependencyPaths from '../graphql/dependency_paths.query.graphql';
import { NAMESPACE_PROJECT } from '../constants';

export default {
  name: 'DependencyPathDrawer',
  components: {
    GlDrawer,
    GlTruncateText,
    GlBadge,
    GlAlert,
    GlCollapsibleListbox,
    GlSkeletonLoader,
    GlKeysetPagination,
  },
  inject: {
    namespaceType: {
      default: NAMESPACE_PROJECT,
    },
    projectFullPath: {
      default: '',
    },
  },
  props: {
    occurrenceId: {
      type: Number,
      required: false,
      default: null,
    },
    component: {
      type: Object,
      required: true,
    },
    dropdownItems: {
      type: Array,
      required: false,
      default: () => [],
    },
    showDrawer: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['close'],
  data() {
    return {
      dependencyPaths: [],
      selectedItem: null,
      pageInfo: {},
      cursor: {
        after: null,
        before: null,
      },
      error: null,
    };
  },
  apollo: {
    dependencyPaths: {
      query: getDependencyPaths,
      variables() {
        return {
          occurrence: convertToGraphQLId(TYPENAME_SBOM_OCCURRENCE, this.selectedOccurrenceId),
          fullPath: this.fullPath,
          ...this.cursor,
        };
      },
      skip() {
        return !this.showDrawer;
      },
      update({ project }) {
        const { nodes = [] } = project?.dependencyPaths || {};
        return nodes;
      },
      result({ data }) {
        if (!data?.project?.dependencyPaths) return;
        const { pageInfo = {} } = data.project.dependencyPaths;
        this.pageInfo = pageInfo;
      },
      error(error) {
        this.error = s__('Vulnerability|Error fetching dependency paths. Please try again.');
        Sentry.captureException(error);
      },
    },
  },
  computed: {
    isLoading() {
      return this.$apollo?.queries.dependencyPaths.loading;
    },
    selectedOccurrenceId() {
      return this.selectedItemValue || this.occurrenceId;
    },
    fullPath() {
      return this.namespaceType === NAMESPACE_PROJECT
        ? this.projectFullPath
        : this.selectedItem?.fullPath;
    },
    selectedItemValue() {
      return this.selectedItem?.value;
    },
    showDropdown() {
      return this.dropdownItems.length > 0;
    },
    showPagination() {
      return this.pageInfo?.hasPreviousPage || this.pageInfo?.hasNextPage;
    },
  },
  watch: {
    occurrenceId() {
      this.resetPagination();
    },
    dropdownItems: {
      handler() {
        this.selectedItem = this.dropdownItems[0] ?? null;
      },
      immediate: true,
    },
  },
  methods: {
    resetPagination() {
      this.pageInfo = {};
      this.cursor = {
        after: null,
        before: null,
      };
    },
    handleSelect(value) {
      this.resetPagination();
      this.selectedItem = this.dropdownItems.find((item) => item.value === value);
    },
    formatPath(paths) {
      return paths.map((path) => `${path.name} @${path.version}`).join(' / ');
    },
    nextPage(item) {
      this.cursor = {
        after: item,
        before: null,
      };
    },
    prevPage(item) {
      this.cursor = {
        after: null,
        before: item,
      };
    },
  },
  i18n: {
    drawerTitle: s__('Vulnerability|Dependency paths'),
    componentTitle: s__('Vulnerability|Component'),
    circularDependencyBadgeText: s__('Vulnerability|circular dependency'),
    maxDepthWarning: s__(
      'Vulnerability|Resolve the vulnerability in these dependencies to see additional paths. GitLab shows a maximum of 20 dependency paths per vulnerability.',
    ),
  },
  getContentWrapperHeight,
  DRAWER_Z_INDEX,
  truncateToggleButtonProps: {
    class: 'gl-text-subtle gl-mt-3',
  },
};
</script>

<template>
  <gl-drawer
    :header-height="$options.getContentWrapperHeight()"
    :open="showDrawer"
    :title="$options.i18n.drawerTitle"
    :z-index="$options.DRAWER_Z_INDEX"
    header-sticky
    class="dependency-path-drawer"
    @close="$emit('close')"
  >
    <template #title>
      <h4 data-testid="dependency-path-drawer-title" class="gl-my-0 gl-text-size-h2 gl-leading-24">
        {{ $options.i18n.drawerTitle }}
      </h4>
    </template>
    <template #header>
      <div class="gl-mt-3" data-testid="dependency-path-drawer-header">
        <strong>{{ $options.i18n.componentTitle }}:</strong>
        <span>{{ component.name }}</span>
        <span>{{ component.version }}</span>
      </div>
      <gl-collapsible-listbox
        v-if="showDropdown"
        :selected="selectedItemValue"
        :items="dropdownItems"
        block
        class="gl-mt-5"
        @select="handleSelect"
      >
        <template #list-item="{ item }">
          {{ item.text }}
        </template>
      </gl-collapsible-listbox>
    </template>
    <gl-skeleton-loader v-if="isLoading" />
    <div v-else>
      <gl-alert v-if="error" variant="danger" class="gl-mb-3" @dismiss="error = null">
        {{ error }}
      </gl-alert>
      <ul class="gl-list-none gl-p-2">
        <li
          v-for="(dependencyPath, index) in dependencyPaths"
          :key="index"
          class="gl-border-b gl-py-5 first:!gl-pt-0"
        >
          <gl-badge v-if="dependencyPath.isCyclic" variant="warning" class="!gl-mb-3">{{
            $options.i18n.circularDependencyBadgeText
          }}</gl-badge>
          <gl-truncate-text
            :toggle-button-props="$options.truncateToggleButtonProps"
            :mobile-lines="3"
          >
            <div class="gl-leading-20">
              {{ formatPath(dependencyPath.path) }}
            </div>
          </gl-truncate-text>
        </li>
      </ul>
      <div class="gl-mb-5 gl-flex gl-justify-center">
        <gl-keyset-pagination
          v-if="showPagination"
          v-bind="pageInfo"
          @prev="prevPage"
          @next="nextPage"
        />
      </div>
    </div>
  </gl-drawer>
</template>
