<script>
import { GlButton, GlTabs } from '@gitlab/ui';
import { logError } from '~/lib/logger';
import { s__ } from '~/locale';
import { InternalEvents } from '~/tracking';
import {
  ROUTES,
  I18N_LOADING_WORKSPACES_FAILED,
  WORKSPACES_LIST_POLL_INTERVAL,
  WORKSPACES_LIST_PAGE_SIZE,
  CLICK_NEW_WORKSPACE_BUTTON_EVENT_NAME,
} from '../constants';
import {
  fetchProjectsDetails,
  populateWorkspacesWithProjectDetails,
} from '../../common/services/utils';
import userWorkspacesTabListQuery from '../../common/graphql/queries/user_workspaces_tab_list.query.graphql';
import BaseWorkspacesList from '../../common/components/workspaces_list/base_workspaces_list.vue';
import WorkspaceTab from '../../common/components/workspace_tab.vue';
import MonitorTerminatingWorkspace from '../../common/components/monitor_terminating_workspace.vue';
import { WORKSPACE_STATES } from '../../common/constants';

export const i18n = {
  newWorkspaceButton: s__('Workspaces|New workspace'),
  loadingWorkspacesFailed: I18N_LOADING_WORKSPACES_FAILED,
};

const trackingMixin = InternalEvents.mixin();

const DEFAULT_WORKSPACES_DATA = {
  workspaces: [],
  pageInfo: {
    hasNextPage: false,
    hasPreviousPage: false,
    startCursor: null,
    endCursor: null,
  },
};

const PAGINATION_TO_VARIABLES_KEY_MAP = {
  first: {
    active: 'first',
    terminated: 'first',
  },
  after: {
    active: 'activeAfter',
    terminated: 'terminatedAfter',
  },
  before: {
    active: 'activeBefore',
    terminated: 'terminatedBefore',
  },
};

function getPaginationVariableKey(tab, key) {
  if (!(key in PAGINATION_TO_VARIABLES_KEY_MAP)) return null;
  return PAGINATION_TO_VARIABLES_KEY_MAP[key][tab];
}

export default {
  name: 'WorkspacesList',
  components: {
    GlButton,
    GlTabs,
    BaseWorkspacesList,
    WorkspaceTab,
    MonitorTerminatingWorkspace,
  },
  mixins: [trackingMixin],
  apollo: {
    userWorkspacesTabList: {
      query: userWorkspacesTabListQuery,
      pollInterval: WORKSPACES_LIST_POLL_INTERVAL,
      fetchPolicy: 'network-only',
      variables() {
        return {
          ...this.paginationVariables,
        };
      },
      update() {
        return [];
      },
      error(err) {
        logError(err);
      },
      async result({ data, error }) {
        if (error || !data.currentUser) {
          this.error = i18n.loadingWorkspacesFailed;
          return;
        }

        const { activeWorkspaces, terminatedWorkspaces } = data.currentUser;
        const workspaces = [...activeWorkspaces.nodes, ...terminatedWorkspaces.nodes];
        const result = await fetchProjectsDetails(this.$apollo, workspaces);

        if (result.error) {
          this.error = i18n.loadingWorkspacesFailed;
          this.active = DEFAULT_WORKSPACES_DATA;
          this.terminated = DEFAULT_WORKSPACES_DATA;
          logError(result.error);
          return;
        }
        this.active = {
          workspaces: populateWorkspacesWithProjectDetails(activeWorkspaces.nodes, result.projects),
          pageInfo: activeWorkspaces.pageInfo,
        };
        this.terminated = {
          workspaces: populateWorkspacesWithProjectDetails(
            terminatedWorkspaces.nodes,
            result.projects,
          ),
          pageInfo: terminatedWorkspaces.pageInfo,
        };

        this.loading = false;
      },
    },
  },
  data() {
    return {
      active: { ...DEFAULT_WORKSPACES_DATA },
      terminated: { ...DEFAULT_WORKSPACES_DATA },
      terminatingWorkspaces: [],
      loading: true,
      // eslint-disable-next-line vue/no-unused-properties -- userWorkspacesTabList is required for Apollo query management
      userWorkspacesTabList: [],
      paginationVariables: {
        first: WORKSPACES_LIST_PAGE_SIZE,
        activeAfter: null,
        activeBefore: null,
        terminatedAfter: null,
        terminatedBefore: null,
      },
      error: '',
    };
  },
  computed: {
    workspaces() {
      return [...this.active.workspaces, ...this.terminated.workspaces];
    },
    isEmpty() {
      return !this.workspaces.length;
    },
    eventTrackingLabel() {
      return document.body.dataset.page;
    },
  },
  watch: {
    active(active) {
      if (!active.workspaces.length && active.pageInfo.hasPreviousPage) {
        // navigate to previous page if at the last page and no workspaces are left
        this.paginationVariables = {
          ...this.paginationVariables,
          activeBefore: active.pageInfo.startCursor,
          activeAfter: null,
        };
      }

      this.terminatingWorkspaces.push(
        ...active.workspaces
          .filter((workspace) => workspace.desiredState === WORKSPACE_STATES.terminated)
          .filter(
            (workspace) =>
              !this.terminatingWorkspaces.some((terminating) => terminating.id === workspace.id),
          )
          .map(({ id }) => ({
            id,
          })),
      );
    },
  },
  methods: {
    onError(error) {
      this.error = error;
    },
    onPaginationInput({ tab, paginationVariables }) {
      const updatedVariables = Object.keys(paginationVariables).reduce(
        (variables, key) => {
          const newKey = getPaginationVariableKey(tab, key);
          return {
            ...variables,
            [newKey]: paginationVariables[key],
          };
        },
        {
          [PAGINATION_TO_VARIABLES_KEY_MAP.after[tab]]: null,
          [PAGINATION_TO_VARIABLES_KEY_MAP.before[tab]]: null,
        },
      );

      this.loading = true;
      this.paginationVariables = { ...this.paginationVariables, ...updatedVariables };
    },
  },
  i18n,
  ROUTES,
  CLICK_NEW_WORKSPACE_BUTTON_EVENT_NAME,
};
</script>
<template>
  <base-workspaces-list
    :error="error"
    :loading="loading"
    :empty="isEmpty"
    :new-workspace-path="$options.ROUTES.new"
    @error="onError"
  >
    <template #header>
      <gl-button
        variant="confirm"
        :to="$options.ROUTES.new"
        data-testid="list-new-workspace-button"
        :data-event-tracking="$options.CLICK_NEW_WORKSPACE_BUTTON_EVENT_NAME"
        :data-event-label="eventTrackingLabel"
      >
        {{ $options.i18n.newWorkspaceButton }}
      </gl-button>
    </template>
    <template #workspaces-list>
      <div>
        <gl-tabs content-class="gl-pt-0" sync-active-tab-with-query-params>
          <workspace-tab
            tab-name="active"
            :loading="loading"
            :workspaces="active.workspaces"
            :page-info="active.pageInfo"
            @error="onError"
            @on-pagination-input="onPaginationInput"
          />
          <workspace-tab
            tab-name="terminated"
            :loading="loading"
            :workspaces="terminated.workspaces"
            :page-info="terminated.pageInfo"
            @error="onError"
            @on-pagination-input="onPaginationInput"
          />
        </gl-tabs>
        <monitor-terminating-workspace
          v-for="(workspace, idx) in terminatingWorkspaces"
          :key="idx"
          :workspace-id="workspace.id"
        />
      </div>
    </template>
  </base-workspaces-list>
</template>
