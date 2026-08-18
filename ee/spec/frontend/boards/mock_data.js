import { GlFilteredSearchToken } from '@gitlab/ui';
import {
  OPTIONS_NONE_ANY_ME,
  OPERATORS_IS_NOT,
  OPERATORS_IS,
  TOKEN_TITLE_ASSIGNEE,
  TOKEN_TITLE_AUTHOR,
  TOKEN_TITLE_CONFIDENTIAL,
  TOKEN_TITLE_LABEL,
  TOKEN_TITLE_MILESTONE,
  TOKEN_TITLE_MY_REACTION,
  TOKEN_TITLE_RELEASE,
  TOKEN_TITLE_TYPE,
  TOKEN_TYPE_ASSIGNEE,
  TOKEN_TYPE_AUTHOR,
  TOKEN_TYPE_CONFIDENTIAL,
  TOKEN_TYPE_EPIC,
  TOKEN_TYPE_HEALTH,
  TOKEN_TYPE_ITERATION,
  TOKEN_TYPE_LABEL,
  TOKEN_TYPE_MILESTONE,
  TOKEN_TYPE_MY_REACTION,
  TOKEN_TYPE_RELEASE,
  TOKEN_TYPE_TYPE,
  TOKEN_TYPE_WEIGHT,
  TOKEN_TYPE_STATUS,
} from '~/vue_shared/components/filtered_search_bar/constants';
import UserToken from '~/vue_shared/components/filtered_search_bar/tokens/user_token.vue';
import EmojiToken from '~/vue_shared/components/filtered_search_bar/tokens/emoji_token.vue';
import LabelToken from '~/vue_shared/components/filtered_search_bar/tokens/label_token.vue';
import MilestoneToken from '~/vue_shared/components/filtered_search_bar/tokens/milestone_token.vue';
import WorkItemTypeToken from '~/vue_shared/components/filtered_search_bar/tokens/work_item_type_token.vue';
import {
  TOKEN_TITLE_EPIC,
  TOKEN_TITLE_HEALTH,
  TOKEN_TITLE_ITERATION,
  TOKEN_TITLE_WEIGHT,
  TOKEN_TITLE_STATUS,
} from 'ee/vue_shared/components/filtered_search_bar/constants';
import CustomFieldToken from 'ee/vue_shared/components/filtered_search_bar/tokens/custom_field_token.vue';
import EpicToken from 'ee/vue_shared/components/filtered_search_bar/tokens/epic_token.vue';
import IterationToken from 'ee/vue_shared/components/filtered_search_bar/tokens/iteration_token.vue';
import ReleaseToken from '~/vue_shared/components/filtered_search_bar/tokens/release_token.vue';
import WeightToken from 'ee/vue_shared/components/filtered_search_bar/tokens/weight_token.vue';
import HealthToken from 'ee/vue_shared/components/filtered_search_bar/tokens/health_token.vue';
import WorkItemStatusToken from 'ee/vue_shared/components/filtered_search_bar/tokens/work_item_status_token.vue';
import { mockLabelList } from 'jest/boards/mock_data';

export const mockEpicBoard = {
  id: 'gid://gitlab/Board::EpicBoard/1',
  name: 'Development',
  hideBacklogList: false,
  hideClosedList: false,
  webPath: '/groups/gitlab-org/-/epic_boards/1',
  labels: {
    nodes: [{ id: 'gid://gitlab/Label/32', title: 'Deliverable' }],
    __typename: 'LabelConnection',
  },
  __typename: 'EpicBoard',
};

export const mockEpicBoardResponse = {
  data: {
    namespace: {
      id: 'gid://gitlab/Group/114',
      board: mockEpicBoard,
      __typename: 'Group',
    },
  },
};

export const mockEpicBoardsResponse = {
  data: {
    group: {
      id: 'gid://gitlab/Group/114',
      boards: {
        nodes: [
          {
            id: 'gid://gitlab/Boards::EpicBoard/1',
            name: 'Development',
          },
          {
            id: 'gid://gitlab/Boards::EpicBoard/2',
            name: 'Marketing',
          },
        ],
      },
      __typename: 'Group',
    },
  },
};

export const mockLabel = {
  id: 'gid://gitlab/GroupLabel/121',
  title: 'To Do',
  color: '#F0AD4E',
  textColor: '#FFFFFF',
  description: null,
};

export const mockLists = [
  {
    id: 'gid://gitlab/List/1',
    title: 'Backlog',
    position: null,
    listType: 'backlog',
    collapsed: false,
    label: null,
    maxIssueCount: 0,
    assignee: null,
    milestone: null,
    preset: true,
  },
  {
    id: 'gid://gitlab/List/2',
    title: 'To Do',
    position: 0,
    listType: 'label',
    collapsed: false,
    label: mockLabel,
    maxIssueCount: 0,
    assignee: null,
    milestone: null,
    preset: false,
  },
  {
    id: 'gid://gitlab/List/3',
    title: 'Assignee list',
    position: 0,
    listType: 'assignee',
    collapsed: false,
    label: null,
    maxIssueCount: 0,
    assignee: {
      id: 'gid://gitlab/',
    },
    milestone: null,
    preset: false,
  },
  {
    id: 'gid://gitlab/List/4',
    title: 'Milestone list',
    position: 0,
    listType: 'milestone',
    collapsed: false,
    label: null,
    maxIssueCount: 0,
    assignee: null,
    milestone: {
      id: 'gid://gitlab/Milestone/1',
      title: 'A milestone',
    },
    preset: false,
  },
];

const defaultDescendantCounts = {
  openedIssues: 0,
  closedIssues: 0,
};

export const mockAssignees = [
  {
    id: 'gid://gitlab/User/2',
    username: 'angelina.herman',
    name: 'Bernardina Bosco',
    avatar: 'https://www.gravatar.com/avatar/eb7b664b13a30ad9f9ba4b61d7075470?s=80&d=identicon',
    webUrl: 'http://127.0.0.1:3000/angelina.herman',
  },
  {
    id: 'gid://gitlab/User/118',
    username: 'jacklyn.moore',
    name: 'Brock Jaskolski',
    avatar: 'https://www.gravatar.com/avatar/af29c072d9fcf315772cfd802c7a7d35?s=80&d=identicon',
    webUrl: 'http://127.0.0.1:3000/jacklyn.moore',
  },
];

export const mockIterationCadence = {
  id: 'gid://gitlab/Iterations::Cadence/1',
  title: 'GitLab.org Iterations',
  durationInWeeks: 1,
  __typename: 'IterationCadence',
};

export const mockIterations = [
  {
    id: 'gid://gitlab/Iteration/1',
    title: null,
    iterationCadence: mockIterationCadence,
    startDate: '2021-10-05',
    dueDate: '2021-10-10',
    __typename: 'Iteration',
  },
  {
    id: 'gid://gitlab/Iteration/2',
    title: 'Some iteration',
    iterationCadence: {
      id: 'gid://gitlab/Iterations::Cadence/2',
      title: 'GitLab.org Iterations: Volume II',
      durationInWeeks: 2,
      __typename: 'IterationCadence',
    },
    startDate: '2021-10-12',
    dueDate: '2021-10-17',
    __typename: 'Iteration',
  },
];

export const mockIterationsResponse = {
  data: {
    group: {
      id: 'gid://gitlab/Group/1',
      iterations: {
        nodes: mockIterations,
      },
      __typename: 'Group',
    },
  },
};

export const labels = [
  {
    id: 'gid://gitlab/GroupLabel/5',
    title: 'Cosync',
    color: '#34ebec',
    description: null,
  },
  {
    id: 'gid://gitlab/GroupLabel/6',
    title: 'Brock',
    color: '#e082b6',
    description: null,
  },
];

export const color = {
  color: '#ff0000',
  title: 'Red',
};

export const rawIssue = {
  title: 'Issue 1',
  titleHtml: 'Issue 1',
  id: 'gid://gitlab/Issue/436',
  iid: '27',
  author: { id: '1', username: 'root', __typename: 'UserCore' },
  closedAt: null,
  dueDate: null,
  timeEstimate: 0,
  totalTimeSpent: 0,
  humanTimeEstimate: null,
  humanTotalTimeSpent: null,
  emailsDisabled: false,
  hidden: false,
  webPath: '/gitlab-org/gitlab-shell/-/issues/32',
  webUrl: 'http://127.0.0.1:3000/gitlab-org/gitlab-shell/-/issues/32',
  relativePosition: 0,
  type: 'ISSUE',
  workItemType: {
    id: 'gid://gitlab/WorkItems::Type/1',
    name: 'Issue',
    iconName: 'work-item-issue',
    __typename: 'WorkItemType',
  },
  severity: 'UNKNOWN',
  milestone: null,
  weight: null,
  confidential: false,
  referencePath: 'gitlab-org/test-subgroup/gitlab-test#27',
  path: '/gitlab-org/test-subgroup/gitlab-test/-/issues/27',
  blocked: false,
  blockedByCount: 0,
  blockingCount: 0,
  healthStatus: null,
  iteration: null,
  status: null,
  labels: {
    nodes: [
      {
        id: 1,
        title: 'test',
        color: 'red',
        description: 'testing',
      },
    ],
  },
  assignees: {
    nodes: mockAssignees,
  },
  epic: {
    id: 'gid://gitlab/Epic/41',
  },
  linkedWorkItems: {
    __typename: 'LinkedWorkItemTypeConnection',
    nodes: [
      {
        linkId: 'gid://gitlab/WorkItems::RelatedWorkItemLink/103',
        linkType: 'blocks',
        workItemState: 'OPEN',
        __typename: 'LinkedWorkItemType',
      },
    ],
  },
  __typename: 'Issue',
};

export const mockIssueGroupPath = 'gitlab-org';
export const mockIssueProjectPath = `${mockIssueGroupPath}/gitlab-test`;

export const mockIssue = {
  id: 'gid://gitlab/Issue/436',
  iid: '27',
  author: { id: '1', username: 'root' },
  title: 'Issue 1',
  titleHtml: 'Issue 1',
  referencePath: `${mockIssueProjectPath}#27`,
  dueDate: null,
  timeEstimate: 0,
  weight: null,
  confidential: false,
  path: `/${mockIssueProjectPath}/-/issues/27`,
  assignees: mockAssignees,
  labels,
  epic: {
    id: 'gid://gitlab/Epic/41',
    iid: 2,
    group: { fullPath: mockIssueGroupPath },
  },
  linkedWorkItems: {
    __typename: 'LinkedWorkItemTypeConnection',
    nodes: [
      {
        linkId: 'gid://gitlab/WorkItems::RelatedWorkItemLink/103',
        linkType: 'blocks',
        workItemState: 'OPEN',
        __typename: 'LinkedWorkItemType',
      },
    ],
  },
};

export const mockIssue2 = {
  id: 'gid://gitlab/Issue/437',
  iid: '28',
  author: { id: '1', username: 'root' },
  title: 'Issue 2',
  titleHtml: 'Issue 2',
  referencePath: 'gitlab-org/test-subgroup/gitlab-test#28',
  dueDate: null,
  timeEstimate: 0,
  weight: null,
  confidential: false,
  path: '/gitlab-org/test-subgroup/gitlab-test/-/issues/28',
  assignees: mockAssignees,
  labels,
  epic: {
    id: 'gid://gitlab/Epic/40',
    iid: 1,
    group: { fullPath: 'gitlab-org' },
  },
  linkedWorkItems: {
    __typename: 'LinkedWorkItemTypeConnection',
    nodes: [
      {
        linkId: 'gid://gitlab/WorkItems::RelatedWorkItemLink/103',
        linkType: 'blocks',
        workItemState: 'OPEN',
        __typename: 'LinkedWorkItemType',
      },
    ],
  },
};

export const mockIssue3 = {
  id: 'gid://gitlab/Issue/438',
  iid: 29,
  title: 'Issue 3',
  titleHtml: 'Issue 3',
  referencePath: '#29',
  dueDate: null,
  timeEstimate: 0,
  weight: null,
  confidential: false,
  path: '/gitlab-org/gitlab-test/-/issues/28',
  assignees: mockAssignees,
  labels,
  epic: null,
  linkedWorkItems: {
    __typename: 'LinkedWorkItemTypeConnection',
    nodes: [
      {
        linkId: 'gid://gitlab/WorkItems::RelatedWorkItemLink/103',
        linkType: 'blocks',
        workItemState: 'OPEN',
        __typename: 'LinkedWorkItemType',
      },
    ],
  },
};

export const mockIssue4 = {
  id: 'gid://gitlab/Issue/439',
  iid: 30,
  title: 'Issue 4',
  titleHtml: 'Issue 4',
  referencePath: '#30',
  dueDate: null,
  timeEstimate: 0,
  weight: null,
  confidential: false,
  path: '/gitlab-org/gitlab-test/-/issues/28',
  assignees: mockAssignees,
  labels,
  epic: null,
  linkedWorkItems: {
    __typename: 'LinkedWorkItemTypeConnection',
    nodes: [
      {
        linkId: 'gid://gitlab/WorkItems::RelatedWorkItemLink/103',
        linkType: 'blocks',
        workItemState: 'OPEN',
        __typename: 'LinkedWorkItemType',
      },
    ],
  },
};

export const mockIssues = [mockIssue, mockIssue2];

export const mockGroupIssuesResponse = (listId = 'gid://gitlab/List/1', issues = [rawIssue]) => ({
  data: {
    group: {
      id: 'gid://gitlab/Group/1',
      board: {
        __typename: 'Board',
        id: 'gid://gitlab/Board/1',
        lists: {
          nodes: [
            {
              id: listId,
              listType: 'backlog',
              issues: {
                nodes: issues,
                pageInfo: {
                  endCursor: null,
                  hasNextPage: false,
                },
              },
              __typename: 'BoardList',
            },
          ],
        },
      },
      __typename: 'Group',
    },
  },
});

export const mockProjectIssuesResponse = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      board: {
        id: 'gid://gitlab/Board/1',
        lists: {
          nodes: [
            {
              id: 'gid://gitlab/List/1',
              listType: 'backlog',
              issues: {
                nodes: [rawIssue],
                pageInfo: {
                  endCursor: null,
                  hasNextPage: false,
                },
              },
            },
          ],
        },
      },
      __typename: 'Project',
    },
  },
};

export const rawEpic = {
  id: 'gid://gitlab/Epic/41',
  iid: '1',
  title: 'Epic title',
  titleHtml: 'Epic title',
  state: 'opened',
  webPath: '/groups/gitlab-org/-/epics/1',
  webUrl: '/groups/gitlab-org/-/epics/1',
  group: { id: 'gid://gitlab/Group/1', fullPath: 'gitlab-org' },
  reference: '&41',
  referencePath: 'gitlab-org/gitlab-subgroup&41',
  relativePosition: '1',
  confidential: false,
  subscribed: false,
  blocked: false,
  blockedByCount: 0,
  hasIssues: true,
  createdAt: '2023-01-20T02:21:29Z',
  closedAt: '2023-01-20T02:21:29Z',
  color: '#ff0000',
  descendantCounts: {
    openedIssues: 3,
    closedIssues: 2,
    closedEpics: 0,
    openedEpics: 0,
  },
  descendantWeightSum: {
    openedIssues: 0,
    closedIssues: 0,
  },
  issues: [rawIssue],
  labels: [],
  linkedWorkItems: {
    __typename: 'LinkedWorkItemTypeConnection',
    nodes: [
      {
        linkId: 'gid://gitlab/WorkItems::RelatedWorkItemLink/103',
        linkType: 'blocks',
        workItemState: 'OPEN',
        __typename: 'LinkedWorkItemType',
      },
    ],
  },
  __typename: 'Epic',
};

export const mockEpic = {
  id: 'gid://gitlab/Epic/41',
  iid: '1',
  author: { id: '1', username: 'root' },
  title: 'Epic title',
  titleHtml: 'Epic title',
  state: 'opened',
  webUrl: '/groups/gitlab-org/-/epics/1',
  group: { fullPath: 'gitlab-org' },
  referencePath: 'gitlab-org/gitlab-subgroup&41',
  relativePosition: '1',
  confidential: false,
  subscribed: false,
  blocked: false,
  blockedByCount: 0,
  createdAt: '2020-08-06T16:53:50Z',
  hasIssues: true,
  descendantCounts: {
    openedIssues: 3,
    closedIssues: 2,
    closedEpics: 0,
    openedEpics: 0,
  },
  descendantWeightSum: {
    openedIssues: 0,
    closedIssues: 0,
  },
  issues: [mockIssue],
  labels: [],
  linkedWorkItems: {
    __typename: 'LinkedWorkItemTypeConnection',
    nodes: [
      {
        linkId: 'gid://gitlab/WorkItems::RelatedWorkItemLink/103',
        linkType: 'blocks',
        workItemState: 'OPEN',
        __typename: 'LinkedWorkItemType',
      },
    ],
  },
};

export const mockEpics = [
  {
    id: 'gid://gitlab/Epic/41',
    iid: '2',
    description: null,
    title: 'Another marketing',
    titleHtml: 'Another marketing',
    group_id: 56,
    group_name: 'Marketing',
    group_full_name: 'Gitlab Org / Marketing',
    start_date: '2017-12-26',
    end_date: '2018-03-10',
    referencePath: 'gitlab-org/marketing&2',
    web_url: '/groups/gitlab-org/marketing/-/epics/2',
    descendantCounts: defaultDescendantCounts,
    hasParent: true,
    parent: {
      id: '40',
    },
    labels: [],
    userPreferences: {
      collapsed: false,
    },
    linkedWorkItems: {
      __typename: 'LinkedWorkItemTypeConnection',
      nodes: [
        {
          linkId: 'gid://gitlab/WorkItems::RelatedWorkItemLink/103',
          linkType: 'blocks',
          workItemState: 'OPEN',
          __typename: 'LinkedWorkItemType',
        },
      ],
    },
  },
  {
    id: 'gid://gitlab/Epic/40',
    iid: '1',
    description: null,
    title: 'Marketing epic',
    titleHtml: 'Marketing epic',
    group_id: 56,
    group_name: 'Marketing',
    group_full_name: 'Gitlab Org / Marketing',
    start_date: '2017-12-25',
    end_date: '2018-03-09',
    web_url: '/groups/gitlab-org/marketing/-/epics/1',
    referencePath: 'gitlab-org/marketing&1',
    descendantCounts: defaultDescendantCounts,
    hasParent: false,
    labels: [],
    userPreferences: {
      collapsed: false,
    },
    linkedWorkItems: {
      __typename: 'LinkedWorkItemTypeConnection',
      nodes: [
        {
          linkId: 'gid://gitlab/WorkItems::RelatedWorkItemLink/103',
          linkType: 'blocks',
          workItemState: 'OPEN',
          __typename: 'LinkedWorkItemType',
        },
      ],
    },
  },
  {
    id: 'gid://gitlab/Epic/39',
    iid: '12',
    description: null,
    title: 'Epic with end in first timeframe month',
    titleHtml: 'Epic with end in first timeframe month',
    group_id: 2,
    group_name: 'Gitlab Org',
    group_full_name: 'Gitlab Org',
    start_date: '2017-04-02',
    end_date: '2017-11-30',
    web_url: '/groups/gitlab-org/-/epics/12',
    referencePath: 'gitlab-org&12',
    descendantCounts: defaultDescendantCounts,
    hasParent: false,
    labels: [],
    userPreferences: {
      collapsed: false,
    },
    linkedWorkItems: {
      __typename: 'LinkedWorkItemTypeConnection',
      nodes: [
        {
          linkId: 'gid://gitlab/WorkItems::RelatedWorkItemLink/103',
          linkType: 'blocks',
          workItemState: 'OPEN',
          __typename: 'LinkedWorkItemType',
        },
      ],
    },
  },
  {
    id: 'gid://gitlab/Epic/38',
    iid: '11',
    description: null,
    title: 'Epic with end date out of range',
    titleHtml: 'Epic with end date out of range',
    group_id: 2,
    group_name: 'Gitlab Org',
    group_full_name: 'Gitlab Org',
    start_date: '2018-01-15',
    end_date: '2020-01-03',
    web_url: '/groups/gitlab-org/-/epics/11',
    referencePath: 'gitlab-org&11',
    descendantCounts: defaultDescendantCounts,
    hasParent: false,
    labels: [],
    userPreferences: {
      collapsed: false,
    },
    linkedWorkItems: {
      __typename: 'LinkedWorkItemTypeConnection',
      nodes: [
        {
          linkId: 'gid://gitlab/WorkItems::RelatedWorkItemLink/103',
          linkType: 'blocks',
          workItemState: 'OPEN',
          __typename: 'LinkedWorkItemType',
        },
      ],
    },
  },
  {
    id: 'gid://gitlab/Epic/37',
    iid: '10',
    description: null,
    title: 'Epic with timeline in same month',
    titleHtml: 'Epic with timeline in same month',
    group_id: 2,
    group_name: 'Gitlab Org',
    group_full_name: 'Gitlab Org',
    start_date: '2018-01-01',
    end_date: '2018-01-31',
    web_url: '/groups/gitlab-org/-/epics/10',
    referencePath: 'gitlab-org&10',
    descendantCounts: defaultDescendantCounts,
    hasParent: false,
    labels: [],
    userPreferences: {
      collapsed: false,
    },
    linkedWorkItems: {
      __typename: 'LinkedWorkItemTypeConnection',
      nodes: [
        {
          linkId: 'gid://gitlab/WorkItems::RelatedWorkItemLink/103',
          linkType: 'blocks',
          workItemState: 'OPEN',
          __typename: 'LinkedWorkItemType',
        },
      ],
    },
  },
];

export const mockGroupEpicsResponse = {
  data: {
    group: {
      id: 'gid://gitlab/Group/1',
      board: {
        id: 'gid://gitlab/Boards::EpicBoard/1',
        lists: {
          nodes: [
            {
              id: 'gid://gitlab/Boards::EpicList/4',
              listType: 'backlog',
              epics: {
                nodes: [rawEpic],
                pageInfo: {
                  endCursor: null,
                  hasNextPage: false,
                },
              },
              __typename: 'EpicList',
            },
          ],
        },
        __typename: 'EpicBoard',
      },
      __typename: 'Group',
    },
  },
};

export const issues = {
  [mockIssue.id]: mockIssue,
  [mockIssue2.id]: mockIssue2,
  [mockIssue3.id]: mockIssue3,
  [mockIssue4.id]: mockIssue4,
};

export const mockGroup0 = {
  __typename: 'Group',
  id: 'gid://gitlab/Group/22',
  name: 'Gitlab Org',
  fullName: 'Gitlab Org',
  fullPath: 'gitlab-org',
};

export const mockGroup1 = {
  __typename: 'Group',
  id: 'gid://gitlab/Group/108',
  name: 'Design',
  fullName: 'Gitlab Org / Design',
  fullPath: 'gitlab-org/design',
};

export const mockGroup2 = {
  __typename: 'Group',
  id: 'gid://gitlab/Group/109',
  name: 'Database',
  fullName: 'Gitlab Org / Database',
  fullPath: 'gitlab-org/database',
};

export const mockGroupsResponse = (subGroups = [mockGroup1, mockGroup2]) => ({
  data: {
    group: {
      ...mockGroup0,
      descendantGroups: {
        nodes: subGroups,
        pageInfo: {
          hasNextPage: true,
          hasPreviousPage: false,
          startCursor: 'abc',
          endCursor: 'bcd',
          __typename: 'PageInfo',
        },
        __typename: 'GroupConnection',
      },
      __typename: 'Group',
    },
  },
});

export const mockTokens = ({
  fetchLabels,
  fetchIterations,
  hasCustomFieldsFeature,
  showCustomStatusToken,
}) => [
  {
    icon: 'user',
    title: TOKEN_TITLE_ASSIGNEE,
    type: TOKEN_TYPE_ASSIGNEE,
    operators: OPERATORS_IS_NOT,
    token: UserToken,
    dataType: 'user',
    unique: true,
    fullPath: 'gitlab-org',
    isProject: false,
    preloadedUsers: [],
    defaultUsers: OPTIONS_NONE_ANY_ME,
  },
  {
    icon: 'pencil',
    title: TOKEN_TITLE_AUTHOR,
    type: TOKEN_TYPE_AUTHOR,
    operators: OPERATORS_IS_NOT,
    symbol: '@',
    token: UserToken,
    dataType: 'user',
    unique: true,
    fullPath: 'gitlab-org',
    isProject: false,
    preloadedUsers: [],
  },
  {
    icon: 'labels',
    title: TOKEN_TITLE_LABEL,
    type: TOKEN_TYPE_LABEL,
    operators: OPERATORS_IS_NOT,
    token: LabelToken,
    unique: false,
    symbol: '~',
    fetchLabels,
    recentSuggestionsStorageKey: 'gitlab-org-board-recent-tokens-label',
  },
  {
    type: TOKEN_TYPE_MY_REACTION,
    icon: 'thumb-up',
    title: TOKEN_TITLE_MY_REACTION,
    unique: true,
    token: EmojiToken,
    fetchEmojis: expect.any(Function),
  },
  {
    type: TOKEN_TYPE_CONFIDENTIAL,
    icon: 'eye-slash',
    title: TOKEN_TITLE_CONFIDENTIAL,
    unique: true,
    token: GlFilteredSearchToken,
    operators: OPERATORS_IS,
    options: [
      { icon: 'eye-slash', value: 'yes', title: 'Yes' },
      { icon: 'eye', value: 'no', title: 'No' },
    ],
  },
  {
    icon: 'milestone',
    title: TOKEN_TITLE_MILESTONE,
    symbol: '%',
    type: TOKEN_TYPE_MILESTONE,
    token: MilestoneToken,
    shouldSkipSort: true,
    unique: true,
    fullPath: 'gitlab-org',
    isProject: false,
  },
  {
    type: TOKEN_TYPE_TYPE,
    title: TOKEN_TITLE_TYPE,
    icon: 'work-item-issue',
    unique: true,
    token: WorkItemTypeToken,
    fullPath: 'gitlab-org',
    isFilterableBoardView: true,
  },
  {
    type: TOKEN_TYPE_RELEASE,
    title: TOKEN_TITLE_RELEASE,
    icon: 'rocket',
    token: ReleaseToken,
    fetchReleases: expect.any(Function),
  },
  {
    type: TOKEN_TYPE_EPIC,
    icon: 'epic',
    title: TOKEN_TITLE_EPIC,
    unique: true,
    symbol: '&',
    token: EpicToken,
    idProperty: 'id',
    useIdValue: true,
    fullPath: 'gitlab-org',
  },
  {
    type: TOKEN_TYPE_ITERATION,
    icon: 'iteration',
    title: TOKEN_TITLE_ITERATION,
    unique: true,
    fetchIterations,
    token: IterationToken,
    fullPath: 'gitlab-org',
    isProject: false,
  },
  {
    type: TOKEN_TYPE_WEIGHT,
    icon: 'weight',
    title: TOKEN_TITLE_WEIGHT,
    token: WeightToken,
    unique: true,
  },
  {
    type: TOKEN_TYPE_HEALTH,
    icon: 'status-health',
    title: TOKEN_TITLE_HEALTH,
    token: HealthToken,
    unique: false,
  },
  ...(hasCustomFieldsFeature
    ? [
        {
          type: 'custom-field[12345]',
          title: 'Issue only field',
          icon: 'multiple-choice',
          field: {
            fieldType: 'MULTI_SELECT',
            id: 'gid://gitlab/CustomField/12345',
            name: 'Issue only field',
            workItemTypes: [
              {
                id: 'gid://gitlab/WorkItemTypes/1',
                name: 'Issue',
              },
            ],
          },
          fullPath: 'gitlab-org',
          token: CustomFieldToken,
          operators: OPERATORS_IS,
          unique: true,
        },
      ]
    : []),
  ...(showCustomStatusToken
    ? [
        {
          type: TOKEN_TYPE_STATUS,
          title: TOKEN_TITLE_STATUS,
          icon: 'status',
          token: WorkItemStatusToken,
          fullPath: 'gitlab-org',
          unique: true,
          operators: OPERATORS_IS,
        },
      ]
    : []),
];

export const mockEpicSwimlanesResponse = ({ hasNextPage = false, epics = mockEpics } = {}) => ({
  data: {
    group: {
      id: 'gid://gitlab/Group/114',
      board: {
        id: 'gid://gitlab/Board/1',
        epics: {
          nodes: epics,
          pageInfo: {
            endCursor: null,
            hasNextPage,
          },
        },
      },
      __typename: 'Group',
    },
  },
});

export const mockUpdateListWipLimitResponse = {
  data: {
    boardListUpdateLimitMetrics: {
      list: mockLabelList,
      errors: [],
      __typename: 'BoardListUpdateLimitMetricsPayload',
    },
  },
};

const mockEpicLabelList = {
  id: 'gid://gitlab/Boards::EpicList/2',
  title: 'To Do',
  position: 0,
  listType: 'label',
  collapsed: false,
  label: {
    id: 'gid://gitlab/GroupLabel/121',
    title: 'To Do',
    color: '#F0AD4E',
    textColor: '#FFFFFF',
    description: null,
    descriptionHtml: null,
    __typename: 'Label',
  },
  metadata: {
    epicsCount: 10,
    totalWeight: 33,
  },
  __typename: 'EpicList',
};

export const epicBoardListsQueryResponse = {
  data: {
    group: {
      id: 'gid://gitlab/Group/1',
      board: {
        id: 'gid://gitlab/Boards::EpicBoard/1',
        hideBacklogList: false,
        lists: {
          nodes: [mockEpicLabelList],
        },
      },
      __typename: 'Group',
    },
  },
};

export const assigneesQueryResponse = {
  data: {
    project: {
      id: 'gid://gitlab/Project/33',
      autocompleteUsers: mockAssignees,
    },
  },
};

export const milestonesQueryResponse = {
  data: {
    namespace: {
      id: 'gid://gitlab/Project/33',
      milestones: {
        nodes: [
          { id: 'gid://gitlab/Milestone/1', title: 'A milestone' },
          { id: 'gid://gitlab/Milestone/2', title: 'B milestone' },
        ],
      },
      __typename: 'Project',
    },
  },
};

export const iterationsQueryResponse = {
  data: {
    project: {
      id: 'gid://gitlab/Group/33',
      iterations: {
        nodes: mockIterations,
      },
      __typename: 'Project',
    },
  },
};

export const moveIssueMutationResponse = {
  data: {
    issuableMoveList: {
      issuable: rawIssue,
      errors: [],
      __typename: 'IssueMoveListPayload',
    },
  },
};

export const moveEpicMutationResponse = {
  data: {
    issuableMoveList: {
      issuable: rawEpic,
      errors: [],
      __typename: 'EpicMoveListPayload',
    },
  },
};

export const createIssueMutationResponse = {
  data: {
    createIssuable: {
      issuable: { ...rawIssue, id: 'gid://gitlab/Issue/35' },
      errors: [],
      __typename: 'CreateIssuePayload',
    },
  },
};

export const createEpicMutationResponse = {
  data: {
    createIssuable: {
      issuable: { ...rawEpic, id: 'gid://gitlab/Epic/35' },
      errors: [],
      __typename: 'CreateEpicPayload',
    },
  },
};

export const mockGroupBoardCurrentIterationResponse = {
  data: {
    namespace: {
      id: 'gid://gitlab/Group/1',
      board: {
        id: 'gid://gitlab/Board/1',
        name: 'Current iteration board',
        hideBacklogList: false,
        hideClosedList: false,
        labels: [],
        milestone: null,
        assignee: null,
        weight: null,
        iterationCadence: null,
        iteration: {
          id: 'gid://gitlab/Iteration/-4',
          title: 'Current',
          __typename: 'Iteration',
        },
        __typename: 'Board',
      },
      __typename: 'Group',
    },
  },
};

export const mockGroupBoardNoIterationResponse = {
  data: {
    namespace: {
      id: 'gid://gitlab/Group/1',
      board: {
        id: 'gid://gitlab/Board/1',
        name: 'No iteration board',
        hideBacklogList: false,
        hideClosedList: false,
        labels: [],
        milestone: null,
        assignee: null,
        weight: null,
        iterationCadence: null,
        iteration: {
          id: 'gid://gitlab/Iteration/0',
          title: 'None',
          __typename: 'Iteration',
        },
        __typename: 'Board',
      },
      __typename: 'Group',
    },
  },
};

export const currentIterationQueryResponse = {
  data: {
    group: {
      id: 'gid://gitlab/Group/1',
      iterations: {
        nodes: [
          {
            id: 'gid://gitlab/Iteration/1',
            iterationCadence: {
              id: 'gid://gitlab/Iterations::Cadence/1',
            },
            __typename: 'Iteration',
          },
        ],
      },
      __typename: 'Group',
    },
  },
};

export const currentIterationQueryResponseWithoutCadence = {
  data: {
    group: {
      id: 'gid://gitlab/Group/1',
      iterations: {
        nodes: [
          {
            id: 'gid://gitlab/Iteration/1',
            iterationCadence: null,
            __typename: 'Iteration',
          },
        ],
      },
      __typename: 'Group',
    },
  },
};

export const currentIterationQueryEmptyResponse = {
  data: {
    group: {
      id: 'gid://gitlab/Group/1',
      iterations: {
        nodes: [],
      },
      __typename: 'Group',
    },
  },
};
