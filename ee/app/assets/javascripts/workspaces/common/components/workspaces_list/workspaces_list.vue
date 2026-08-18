<script>
import { GlAlert, GlLink, GlSkeletonLoader } from '@gitlab/ui';
import { s__, __ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import WorkspaceEmptyState from './empty_state.vue';
import WorkspacesTable from './workspaces_table.vue';
import WorkspacesListPagination from './workspaces_list_pagination.vue';

export const i18n = {
  learnMoreHelpLink: __('Learn more'),
  heading: s__('Workspaces|Workspaces'),
};

const workspacesHelpPath = helpPagePath('user/workspace/_index.md');

export default {
  name: 'WorkspacesList',
  components: {
    GlAlert,
    GlLink,
    GlSkeletonLoader,
    WorkspaceEmptyState,
    WorkspacesListPagination,
    WorkspacesTable,
  },
  props: {
    workspaces: {
      type: Array,
      required: true,
    },
    error: {
      type: String,
      required: false,
      default: '',
    },
    pageInfo: {
      type: Object,
      required: true,
    },
    isLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
    pageSize: {
      type: Number,
      required: true,
    },
    newWorkspacePath: {
      type: String,
      required: false,
      default: '',
    },
  },
  emits: ['error', 'page'],
  computed: {
    isEmpty() {
      return !this.workspaces.length && !this.isLoading;
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
      this.$emit('page', paginationVariables);
    },
  },
  i18n,
  workspacesHelpPath,
};
</script>
<template>
  <div>
    <gl-alert v-if="error" variant="danger" @dismiss="clearError">
      {{ error }}
    </gl-alert>
    <div class="gl-flex gl-items-center gl-justify-between">
      <div v-if="!isEmpty" class="gl-flex gl-items-center">
        <h2>{{ $options.i18n.heading }}</h2>
      </div>
      <div class="gl-flex gl-flex-col gl-items-center @md/panel:gl-flex-row">
        <gl-link
          v-if="!isEmpty"
          class="workspace-list-link gl-mr-5 gl-hidden @sm/panel:gl-block"
          :href="$options.workspacesHelpPath"
          >{{ $options.i18n.learnMoreHelpLink }}</gl-link
        >
        <slot name="header"></slot>
      </div>
    </div>
    <workspace-empty-state v-if="isEmpty" :new-workspace-path="newWorkspacePath" />
    <template v-else>
      <div v-if="isLoading" class="gl-flex gl-p-5">
        <gl-skeleton-loader :lines="4" :equal-width-lines="true" :width="600" />
      </div>
      <div v-else>
        <workspaces-table
          :workspaces="workspaces"
          data-testid="workspace-list-item"
          @update-failed="onUpdateFailed"
          @update-succeed="clearError"
        />
        <workspaces-list-pagination
          :page-info="pageInfo"
          :page-size="pageSize"
          @input="onPaginationInput"
        />
      </div>
    </template>
  </div>
</template>
