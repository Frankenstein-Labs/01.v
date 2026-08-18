import Vue from 'vue';
import VueApollo from 'vue-apollo';

import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import BoardCard from '~/boards/components/board_card.vue';
import BoardList from '~/boards/components/board_list.vue';
import BoardNewIssue from '~/boards/components/board_new_issue.vue';
import BoardNewItem from '~/boards/components/board_new_item.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import listQuery from 'ee_else_ce/boards/graphql/board_lists_deferred.query.graphql';
import listIssuesQuery from '~/boards/graphql/lists_issues.query.graphql';
import listEpicsQuery from 'ee/boards/graphql/lists_epics_with_color.query.graphql';
import epicListDeferredQuery from 'ee/boards/graphql/epic_board_lists_deferred.query.graphql';
import {
  mockList,
  boardListQueryResponse,
  epicBoardListQueryResponse,
} from 'jest/boards/mock_data';
import { mockGroupIssuesResponse, mockGroupEpicsResponse, rawIssue } from './mock_data';

export default function createComponent({
  listIssueProps = {},
  componentProps = {},
  listProps = {},
  apolloQueryHandlers = [],
  provide = {},
  data = {},
  stubs = {
    BoardNewIssue,
    BoardNewItem,
    BoardCard,
  },
  issuesCount,
} = {}) {
  Vue.use(VueApollo);

  const fakeApollo = createMockApollo([
    [listQuery, jest.fn().mockResolvedValue(boardListQueryResponse({ issuesCount }))],
    ...apolloQueryHandlers,
  ]);

  const baseListQueryVariables = {
    fullPath: 'gitlab-org',
    boardId: 'gid://gitlab/Board/1',
    filters: {},
    isGroup: true,
    isProject: false,
    first: 10,
  };

  fakeApollo.clients.defaultClient.writeQuery({
    query: listQuery,
    variables: { id: 'gid://gitlab/List/1', filters: {} },
    data: boardListQueryResponse({ listId: 'gid://gitlab/List/1' }).data,
  });
  fakeApollo.clients.defaultClient.writeQuery({
    query: listQuery,
    variables: { id: 'gid://gitlab/List/2', filters: {} },
    data: boardListQueryResponse({ listId: 'gid://gitlab/List/2' }).data,
  });
  fakeApollo.clients.defaultClient.writeQuery({
    query: listIssuesQuery,
    variables: { ...baseListQueryVariables, id: 'gid://gitlab/List/1' },
    data: mockGroupIssuesResponse('gid://gitlab/List/1', [
      { ...rawIssue, id: 'gid://gitlab/Issue/437' },
    ]).data,
  });
  fakeApollo.clients.defaultClient.writeQuery({
    query: listIssuesQuery,
    variables: { ...baseListQueryVariables, id: 'gid://gitlab/List/2' },
    data: mockGroupIssuesResponse('gid://gitlab/List/2', [{ ...rawIssue, iid: '28' }]).data,
  });
  fakeApollo.clients.defaultClient.writeQuery({
    query: epicListDeferredQuery,
    variables: { id: 'gid://gitlab/Boards::EpicList/4', filters: {} },
    data: epicBoardListQueryResponse().data,
  });
  fakeApollo.clients.defaultClient.writeQuery({
    query: epicListDeferredQuery,
    variables: { id: 'gid://gitlab/Boards::EpicList/5', filters: {} },
    data: epicBoardListQueryResponse().data,
  });
  fakeApollo.clients.defaultClient.writeQuery({
    query: listEpicsQuery,
    variables: { ...baseListQueryVariables, id: 'gid://gitlab/Boards::EpicList/4' },
    data: mockGroupEpicsResponse.data,
  });
  fakeApollo.clients.defaultClient.writeQuery({
    query: listEpicsQuery,
    variables: { ...baseListQueryVariables, id: 'gid://gitlab/Boards::EpicList/5' },
    data: mockGroupEpicsResponse.data,
  });

  const list = {
    ...mockList,
    ...listProps,
  };
  const issue = {
    title: 'Testing',
    id: 1,
    iid: 1,
    confidential: false,
    referencePath: 'gitlab-org/test-subgroup/gitlab-test#1',
    labels: [],
    assignees: [],
    ...listIssueProps,
  };
  if (!Object.prototype.hasOwnProperty.call(listProps, 'issuesCount')) {
    list.issuesCount = 1;
  }

  const component = shallowMountExtended(BoardList, {
    apolloProvider: fakeApollo,
    propsData: {
      list,
      boardItems: [issue],
      canAdminList: true,
      boardId: 'gid://gitlab/Board/1',
      filterParams: {},
      columnIndex: 1,
      ...componentProps,
    },
    provide: {
      groupId: null,
      rootPath: '/',
      fullPath: 'gitlab-org',
      boardId: '1',
      weightFeatureAvailable: false,
      boardWeight: null,
      canAdminList: true,
      isIssueBoard: true,
      isEpicBoard: false,
      isGroupBoard: false,
      isProjectBoard: true,
      disabled: false,
      boardType: 'group',
      issuableType: 'issue',
      ...provide,
    },
    stubs,
    data() {
      return {
        ...data,
      };
    },
  });

  return component;
}
