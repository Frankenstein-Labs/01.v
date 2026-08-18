<script>
import { GlLink, GlLoadingIcon, GlTable, GlFormCheckbox, GlToggle } from '@gitlab/ui';
import { isEqual } from 'lodash-es';
import VisibilityIconButton from '~/vue_shared/components/visibility_icon_button.vue';
import { ROUTE_PROJECTS } from 'ee/compliance_dashboard/constants';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { mapFiltersToGraphQLVariables } from 'ee/compliance_dashboard/utils';
import complianceFrameworksGroupProjects from '../../../../graphql/compliance_frameworks_group_projects.query.graphql';
import { i18n } from '../constants';
import Pagination from '../../../shared/pagination.vue';
import Filters from '../../../shared/filters.vue';
import EditSection from './edit_section.vue';

export default {
  name: 'ProjectsSection',
  components: {
    EditSection,
    GlLink,
    GlLoadingIcon,
    GlTable,
    VisibilityIconButton,
    GlFormCheckbox,
    GlToggle,
    Pagination,
    Filters,
  },
  props: {
    complianceFramework: {
      type: Object,
      required: true,
    },
    groupPath: {
      type: String,
      required: true,
      validator(value) {
        return /^[a-zA-Z0-9_.-]+(\/[a-zA-Z0-9_.-]+)*$/.test(value);
      },
    },
  },
  emits: ['update:projects'],
  data() {
    return {
      projectList: [],
      associatedProjects: this.complianceFramework.projects?.nodes || [],
      projectIdsToAdd: new Set(),
      projectIdsToRemove: new Set(),
      initialProjectIds: new Set(),
      errorMessage: null,
      originalProjectsLength: this.complianceFramework.projects?.count || 0,
      pageInfo: {},
      perPage: 20,
      filters: [],
      pagination: {},
      showOnlySelected: false,
    };
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.projectList.loading;
    },
    pageAllSelected() {
      return (
        this.projectList.length > 0 &&
        this.projectList.every((project) => this.projectSelected(project.id))
      );
    },
    pageAllSelectedIndeterminate() {
      const selectedOnCurrentPage = this.projectList.filter((project) =>
        this.projectSelected(project.id),
      ).length;
      return (
        this.projectList.length > 0 &&
        selectedOnCurrentPage > 0 &&
        selectedOnCurrentPage < this.projectList.length
      );
    },
    queryVariables() {
      const basicVariables = {
        groupPath: this.groupPath,
        first: this.perPage,
        frameworks: [],
        frameworksNot: [],
        ...this.pagination,
        ...mapFiltersToGraphQLVariables(this.filters),
      };

      if (this.showOnlySelected) {
        basicVariables.frameworks.push(this.complianceFramework.id);
      }

      return basicVariables;
    },
    selectedCount() {
      let count = this.initialProjectIds.size;

      for (const id of this.projectIdsToRemove) {
        if (this.initialProjectIds.has(id)) {
          count -= 1;
        }
      }

      for (const id of this.projectIdsToAdd) {
        if (!this.initialProjectIds.has(id) && !this.projectIdsToRemove.has(id)) {
          count += 1;
        }
      }

      return count;
    },
    showPagination() {
      const { hasPreviousPage, hasNextPage } = this.pageInfo || {};

      return Boolean(hasPreviousPage || hasNextPage);
    },
    selectAllOnPageDisabled() {
      return this.projectList.length === 0;
    },
    hasFilters() {
      return (this.filters || []).length !== 0;
    },
    noProjectsText() {
      if (this.showOnlySelected && this.projectList.length > 0) {
        return i18n.noProjectsSelected;
      }
      return this.hasFilters ? i18n.noProjectsFoundMatchingFilters : i18n.noProjectsFound;
    },
  },
  watch: {
    associatedProjects: {
      immediate: true,
      handler(projects) {
        if (projects.length) {
          const projectIds = projects.map((project) => project.id);
          this.initialProjectIds = new Set(projectIds);
          this.projectIdsToAdd = new Set();
          this.projectIdsToRemove = new Set();
        }
      },
    },
  },
  apollo: {
    projectList: {
      query: complianceFrameworksGroupProjects,
      variables() {
        return this.queryVariables;
      },
      update(data) {
        this.errorMessage = null;
        this.pageInfo = data?.group?.projects?.pageInfo;
        return data?.group?.projects?.nodes || [];
      },
      error(error) {
        this.errorMessage = i18n.fetchProjectsError;
        Sentry.captureException(error);
      },
    },
  },
  methods: {
    togglePageProjects(checked) {
      this.projectList.forEach((project) => {
        this.toggleProject(project.id, checked);
      });

      this.$emit('update:projects', {
        addProjects: [...this.projectIdsToAdd].map((id) => getIdFromGraphQLId(id)),
        removeProjects: [...this.projectIdsToRemove].map((id) => getIdFromGraphQLId(id)),
      });
    },
    toggleProject(projectId, checked) {
      if (checked) {
        this.projectIdsToRemove = new Set(
          [...this.projectIdsToRemove].filter((id) => id !== projectId),
        );
        this.projectIdsToAdd = new Set([...this.projectIdsToAdd, projectId]);
      } else {
        this.projectIdsToAdd = new Set([...this.projectIdsToAdd].filter((id) => id !== projectId));
        this.projectIdsToRemove = new Set([...this.projectIdsToRemove, projectId]);
      }

      this.$emit('update:projects', {
        addProjects: [...this.projectIdsToAdd].map((id) => getIdFromGraphQLId(id)),
        removeProjects: [...this.projectIdsToRemove].map((id) => getIdFromGraphQLId(id)),
      });
    },
    projectSelected(projectId) {
      return (
        (this.associatedProjects.some((project) => project.id === projectId) &&
          !this.projectIdsToRemove.has(projectId)) ||
        this.projectIdsToAdd.has(projectId)
      );
    },
    loadPage(cursor, direction = 'next') {
      const isPrevious = direction === 'prev';

      this.pagination = {
        first: isPrevious ? null : this.perPage,
        after: isPrevious ? null : cursor,
        last: isPrevious ? this.perPage : null,
        before: isPrevious ? cursor : null,
      };
    },
    loadPrevPage(cursor) {
      this.loadPage(cursor, 'prev');
    },
    loadNextPage(cursor) {
      this.loadPage(cursor, 'next');
    },
    onPageSizeChange(newSize) {
      this.perPage = newSize;
    },
    onFiltersChanged(filters) {
      if (isEqual(this.filters, filters)) {
        return;
      }
      this.pagination = {};
      this.filters = filters;
    },
    onShowOnlySelectedChanged() {
      this.pagination = {};
    },
  },
  tableFields: [
    {
      key: 'selected',
      label: '',
      thClass: '!gl-border-t-0 !gl-pr-0',
      tdClass: '!gl-bg-white !gl-border-b-white !gl-pr-0',
      thAttr: { width: '1%' },
      tdAttr: { width: '1%' },
    },
    {
      key: 'name',
      label: i18n.projectsTableFields.name,
      thClass: 'gl-w-1 !gl-border-t-0',
      tdClass: '!gl-bg-default !gl-border-b-white',
    },
    {
      key: 'subgroup',
      label: i18n.projectsTableFields.subgroup,
      thClass: 'gl-w-1 !gl-border-t-0',
      tdClass: '!gl-bg-default !gl-border-b-white',
    },
    {
      key: 'description',
      label: i18n.projectsTableFields.description,
      thClass: 'gl-w-1 !gl-border-t-0',
      tdClass: '!gl-bg-default !gl-border-b-white',
    },
  ],
  i18n,
  ROUTE_PROJECTS,
};
</script>

<template>
  <edit-section
    :title="$options.i18n.projects"
    :description="$options.i18n.projectsDescription"
    :items-count="originalProjectsLength"
  >
    <div v-if="errorMessage" class="gl-p-5 gl-text-center">
      {{ errorMessage }}
    </div>
    <div v-else>
      <filters
        :value="filters"
        :group-path="groupPath"
        :error="errorMessage"
        :show-update-popover="false"
        @keyup.enter="onFiltersChanged"
        @submit="onFiltersChanged"
      />
      <div class="gl-align-items-center gl-mb-0 gl-ml-6 gl-flex gl-flex-wrap">
        <div>
          <span class="gl-font-bold" data-testid="selected-count"> {{ selectedCount }}</span>
          {{ $options.i18n.selectedCount }}
        </div>
        <div class="gl-ml-auto gl-mr-6">
          <gl-toggle
            v-model="showOnlySelected"
            data-testid="show-only-selected-toggle"
            :label="$options.i18n.showOnlySelected"
            label-position="left"
            @change="onShowOnlySelectedChanged"
          />
        </div>
      </div>
      <gl-table
        ref="projectsTable"
        class="gl-mb-6"
        :busy="isLoading"
        :items="projectList"
        :fields="$options.tableFields"
        no-local-sorting
        show-empty
        responsive
        stacked="md"
        hover
        select-mode="single"
        selected-variant="primary"
      >
        <template #head(selected)>
          <gl-form-checkbox
            class="gl-m-0"
            data-testid="select-all-checkbox"
            :indeterminate="pageAllSelectedIndeterminate"
            :checked="pageAllSelected"
            :disabled="selectAllOnPageDisabled"
            @change="togglePageProjects"
          />
        </template>
        <template #cell(selected)="{ item }">
          <gl-form-checkbox
            class="gl-m-0"
            :checked="projectSelected(item.id)"
            @change="toggleProject(item.id, $event)"
          />
        </template>
        <template #cell(name)="{ item }">
          <gl-link data-testid="project-link" :href="item.webPath">{{ item.name }}</gl-link>
          <visibility-icon-button
            v-if="item.visibility"
            class="gl-ml-2"
            :visibility-level="item.visibility"
          />
        </template>
        <template #cell(subgroup)="{ item }">
          <!-- eslint-disable-next-line local-rules/vue-no-web-url -- Namespace GraphQL type has no webPath; webUrl is the only field available. -->
          <gl-link v-if="item.namespace" data-testid="subgroup-link" :href="item.namespace.webUrl">
            {{ item.namespace.fullName }}
          </gl-link>
        </template>
        <template #cell(description)="{ item }">
          {{ item.description }}
        </template>

        <template #table-busy>
          <gl-loading-icon size="lg" />
        </template>

        <template #empty>
          <div class="gl-my-5 gl-text-center" data-testid="no-projects-text">
            {{ noProjectsText }}
          </div>
        </template>
      </gl-table>

      <pagination
        v-if="showPagination"
        :is-loading="isLoading"
        :page-info="pageInfo"
        :per-page="perPage"
        @prev="loadPrevPage"
        @next="loadNextPage"
        @page-size-change="onPageSizeChange"
      />
    </div>
  </edit-section>
</template>
