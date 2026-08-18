import Vue from 'vue';
import VueApollo from 'vue-apollo';
import VueRouter from 'vue-router';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';

import { fullEpicBoardId } from 'ee_component/boards/boards_util';

import BoardApp from '~/boards/components/board_app.vue';

import {
  navigationType,
  isLoggedIn,
  parseBoolean,
  convertObjectPropsToCamelCase,
} from '~/lib/utils/common_utils';
import { defaultClient } from '~/graphql_shared/issuable_client';
import { TYPE_EPIC, NAMESPACE_GROUP, NAMESPACE_PROJECT } from '~/issues/constants';
import { queryToObject } from '~/lib/utils/url_utility';

Vue.use(VueApollo);
Vue.use(VueRouter);

defaultClient.cache.policies.addTypePolicies({
  EpicList: {
    fields: {
      epics: {
        keyArgs: ['filters'],
      },
    },
  },
  EpicConnection: {
    merge(existing = { nodes: [] }, incoming, { args }) {
      if (!args?.after) {
        return incoming;
      }
      return {
        ...incoming,
        nodes: [...existing.nodes, ...incoming.nodes],
      };
    },
  },
  BoardEpicConnection: {
    merge(existing = { nodes: [] }, incoming, { args }) {
      if (!args.after) {
        return incoming;
      }
      return {
        ...incoming,
        nodes: [...existing.nodes, ...incoming.nodes],
      };
    },
  },
});

const apolloProvider = new VueApollo({
  defaultClient,
});

function mountBoardApp(el) {
  const {
    boardId,
    fullPath,
    rootPath,
    wiReportAbusePath,
    wiGroupPath,
    wiCanAdminLabel,
    wiIssuesListPath,
  } = el.dataset;

  const rawFilterParams = queryToObject(window.location.search, { gatherArrays: true });

  const initialFilterParams = {
    ...convertObjectPropsToCamelCase(rawFilterParams),
  };

  const boardType = el.dataset.parent;

  initVueApp({
    el,
    name: 'BoardRoot',
    apolloProvider,
    router: new VueRouter(),
    provide: {
      initialBoardId: fullEpicBoardId(boardId),
      disabled: parseBoolean(el.dataset.disabled),
      rootPath,
      fullPath,
      initialFilterParams,
      boardBaseUrl: el.dataset.boardBaseUrl,
      boardType,
      isGroupBoard: boardType === NAMESPACE_GROUP,
      isProjectBoard: boardType === NAMESPACE_PROJECT,
      currentUserId: gon.current_user_id || null,
      labelsManagePath: el.dataset.labelsManagePath,
      timeTrackingLimitToHours: parseBoolean(el.dataset.timeTrackingLimitToHours),
      issuableType: TYPE_EPIC,
      hasMissingBoards: parseBoolean(el.dataset.hasMissingBoards),
      weights: JSON.parse(el.dataset.weights),
      isIssueBoard: false,
      isEpicBoard: true,
      // Permissions
      canUpdate: parseBoolean(el.dataset.canUpdate),
      canAdminList: parseBoolean(el.dataset.canAdminList),
      canAdminBoard: parseBoolean(el.dataset.canAdminBoard),
      canCreateEpic: parseBoolean(el.dataset.canCreateEpic),
      allowLabelCreate: parseBoolean(el.dataset.canUpdate),
      allowScopedLabels: parseBoolean(el.dataset.scopedLabels),
      isSignedIn: isLoggedIn(),
      // Features
      epicFeatureAvailable: parseBoolean(el.dataset.epicFeatureAvailable),
      iterationFeatureAvailable: parseBoolean(el.dataset.iterationFeatureAvailable),
      weightFeatureAvailable: parseBoolean(el.dataset.weightFeatureAvailable),
      healthStatusFeatureAvailable: parseBoolean(el.dataset.healthStatusFeatureAvailable),
      scopedLabelsAvailable: parseBoolean(el.dataset.scopedLabels),
      allowSubEpics: parseBoolean(el.dataset.subEpicsFeatureAvailable),
      milestoneListsAvailable: false,
      assigneeListsAvailable: false,
      iterationListsAvailable: false,
      swimlanesFeatureAvailable: false,
      multipleIssueBoardsAvailable: true,
      scopedIssueBoardFeatureEnabled: true,
      reportAbusePath: wiReportAbusePath,
      groupPath: wiGroupPath,
      hasSubepicsFeature: parseBoolean(el.dataset.subEpicsFeatureAvailable),
      isGroup: true,
      canAdminLabel: parseBoolean(wiCanAdminLabel),
      issuesListPath: wiIssuesListPath,
      hasLinkedItemsEpicsFeature: parseBoolean(el.dataset.hasLinkedItemsEpicsFeature),
    },
    component: BoardApp,
  });
}

export default () => {
  const $boardApp = document.getElementById('js-issuable-board-app');

  // check for browser back and trigger a hard reload to circumvent browser caching.
  window.addEventListener('pageshow', (event) => {
    const isNavTypeBackForward =
      window.performance && window.performance.navigation.type === navigationType.TYPE_BACK_FORWARD;

    if (event.persisted || isNavTypeBackForward) {
      window.location.reload();
    }
  });

  mountBoardApp($boardApp);
};
