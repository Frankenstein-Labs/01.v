<script>
import { GlTab, GlSkeletonLoader } from '@gitlab/ui';
import { s__, __ } from '~/locale';
import { WORKSPACES_LIST_PAGE_SIZE, I18N_LOADING_WORKSPACES_FAILED } from '../constants';
import WorkspacesTable from './workspaces_list/workspaces_table.vue';
import WorkspaceEmptyState from './workspaces_list/empty_state.vue';
import WorkspacesListPagination from './workspaces_list/workspaces_list_pagination.vue';

export const i18n = {
  loadingWorkspacesFailed: I18N_LOADING_WORKSPACES_FAILED,
};

function getTabTitle(tabName) {
  switch (tabName) {
    case 'active':
      return s__('Workspaces|Active');
    case 'terminated':
      return s__('Workspaces|Terminated');
    default:
      throw Error(__('Status not supported'));
  }
}

function getEmptyStateText(tabName) {
  switch (tabName) {
    case 'active':
      return s__('Workspaces|No active workspaces');
    case 'terminated':
      return s__('Workspaces|No terminated workspaces');
    default:
      throw Error(__('Status not supported'));
  }
}

export default {
  components: {
    GlTab,
    GlSkeletonLoader,
    WorkspacesTable,
    WorkspaceEmptyState,
    WorkspacesListPagination,
  },
  props: {
    tabName: {
      type: String,
      required: true,
    },
    workspaces: {
      type: Array,
      required: true,
    },
    pageInfo: {
      type: Object,
      required: true,
    },
    loading: {
      type: Boolean,
      required: true,
    },
  },
  emits: ['error', 'on-pagination-input'],
  computed: {
    isEmpty() {
      return !this.workspaces.length && !this.loading;
    },
  },
  methods: {
    clearError() {
      this.$emit('error', '');
    },
    onUpdateFailed({ error }) {
      // TODO: review type of error, may need to be a different type or cast to string
      this.$emit('error', error);
    },
    onPaginationInput(paginationVariables) {
      this.$emit('on-pagination-input', { tab: this.tabName, paginationVariables });
    },
  },
  i18n,
  WORKSPACES_LIST_PAGE_SIZE,
  getTabTitle,
  getEmptyStateText,
};
</script>
<template>
  <gl-tab
    :data-testid="`workspace-tab-${tabName}`"
    :title="$options.getTabTitle(tabName)"
    :query-param-value="tabName"
  >
    <div v-if="loading" class="gl-justify-content-left gl-flex gl-p-5">
      <gl-skeleton-loader :lines="4" :equal-width-lines="true" :width="600" />
    </div>
    <template v-else>
      <workspace-empty-state
        v-if="isEmpty"
        :title="$options.getEmptyStateText(tabName)"
        description=""
      />
      <div v-else>
        <workspaces-table
          data-testid="workspace-list-item"
          :workspaces="workspaces"
          @update-failed="onUpdateFailed"
          @update-succeed="clearError"
        />
        <workspaces-list-pagination
          :page-info="pageInfo"
          :page-size="$options.WORKSPACES_LIST_PAGE_SIZE"
          @input="onPaginationInput"
        />
      </div>
    </template>
  </gl-tab>
</template>
