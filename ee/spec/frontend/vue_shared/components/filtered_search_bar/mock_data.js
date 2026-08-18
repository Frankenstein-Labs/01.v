import {
  OPERATORS_IS,
  TOKEN_TYPE_EPIC,
  TOKEN_TYPE_HEALTH,
  TOKEN_TYPE_ITERATION,
  TOKEN_TYPE_WEIGHT,
  TOKEN_TYPE_STATUS,
} from '~/vue_shared/components/filtered_search_bar/constants';
import {
  TOKEN_TITLE_EPIC,
  TOKEN_TITLE_HEALTH,
  TOKEN_TITLE_ITERATION,
  TOKEN_TITLE_WEIGHT,
  TOKEN_TITLE_STATUS,
} from 'ee/vue_shared/components/filtered_search_bar/constants';
import EpicToken from 'ee/vue_shared/components/filtered_search_bar/tokens/epic_token.vue';
import HealthToken from 'ee/vue_shared/components/filtered_search_bar/tokens/health_token.vue';
import IterationToken from 'ee/vue_shared/components/filtered_search_bar/tokens/iteration_token.vue';
import WeightToken from 'ee/vue_shared/components/filtered_search_bar/tokens/weight_token.vue';
import WorkItemStatusToken from 'ee/vue_shared/components/filtered_search_bar/tokens/work_item_status_token.vue';

export const mockEpics = [
  { iid: 1, id: 1, title: 'Foo', group_full_path: 'gitlab-org' },
  { iid: 2, id: 2, title: 'Bar', group_full_path: 'gitlab-org/design' },
];

export const mockIterationToken = {
  type: TOKEN_TYPE_ITERATION,
  icon: 'iteration',
  title: TOKEN_TITLE_ITERATION,
  unique: true,
  token: IterationToken,
  fetchIterations: () => Promise.resolve(),
  fullPath: 'gitlab-org',
  isProject: false,
};

export const mockIterations = [
  {
    id: 1,
    title: 'Iteration 1',
    startDate: '2021-11-05',
    dueDate: '2021-11-10',
    iterationCadence: {
      title: 'Cadence 1',
    },
  },
];
export const mockIterationCadence = {
  __typename: 'IterationCadence',
  active: true,
  id: `gid://gitlab/Iterations::Cadence/72`,
  title: 'Cadence 1',
  automatic: false,
  rollOver: false,
  durationInWeeks: 2,
  description: null,
  startDate: '2024-06-28',
  iterationsInAdvance: 0,
};

export const groupCadencesResponse = {
  data: {
    group: {
      id: 'gid://gitlab/Group/1',
      iterationCadences: {
        nodes: [mockIterationCadence],
        __typename: 'IterationCadenceConnection',
      },
      __typename: 'Group',
    },
  },
};

export const mockEpicToken = {
  type: TOKEN_TYPE_EPIC,
  icon: 'clock',
  title: TOKEN_TITLE_EPIC,
  unique: true,
  symbol: '&',
  token: EpicToken,
  operators: OPERATORS_IS,
  idProperty: 'iid',
  fullPath: 'gitlab-org',
};

const mockEpicNode1 = {
  id: 'gid://gitlab/Epic/40',
  iid: '2',
  group: {
    id: 'gid://gitlab/Group/9970',
    fullPath: 'gitlab-org',
    __typename: 'Group',
  },
  title: 'Marketing epic',
  state: 'opened',
  reference: '\u00269961',
  referencePath: 'gitlab-org\u00269961',
  webPath: '/groups/gitlab-org/-/epics/9961',
  webUrl: 'https://gitlab.com/groups/gitlab-org/-/epics/9961',
  createdAt: '2023-02-24T19:27:21Z',
  closedAt: null,
  __typename: 'Epic',
};

const mockEpicNode2 = {
  id: 'gid://gitlab/Epic/753769',
  iid: '9926',
  group: {
    id: 'gid://gitlab/Group/9970',
    fullPath: 'gitlab-org',
    __typename: 'Group',
  },
  title: 'Undesired behavior with combining filter criteria on Issues List',
  state: 'opened',
  reference: '\u00269926',
  referencePath: 'gitlab-org\u00269926',
  webPath: '/groups/gitlab-org/-/epics/9926',
  webUrl: 'https://gitlab.com/groups/gitlab-org/-/epics/9926',
  createdAt: '2023-02-21T16:42:41Z',
  closedAt: null,
  __typename: 'Epic',
};

export const mockGroupEpicsQueryResponse = {
  data: {
    group: {
      id: 'gid://gitlab/Group/1',
      name: 'Gitlab Org',
      epics: {
        nodes: [
          {
            ...mockEpicNode1,
          },
          {
            ...mockEpicNode2,
          },
        ],
        __typename: 'EpicConnection',
      },
      __typename: 'Group',
    },
  },
};

export const mockWeightToken = {
  type: TOKEN_TYPE_WEIGHT,
  icon: 'weight',
  title: TOKEN_TITLE_WEIGHT,
  unique: true,
  token: WeightToken,
};

export const mockHealthToken = {
  type: TOKEN_TYPE_HEALTH,
  icon: 'status-health',
  title: TOKEN_TITLE_HEALTH,
  unique: true,
  operators: OPERATORS_IS,
  token: HealthToken,
};

export const mockStatusToken = {
  type: TOKEN_TYPE_STATUS,
  title: TOKEN_TITLE_STATUS,
  icon: 'status',
  token: WorkItemStatusToken,
  fullPath: `gitlab-org`,
  unique: true,
  operators: OPERATORS_IS,
};

export const mockNamespaceCustomFieldsResponse = {
  data: {
    namespace: {
      id: 'gid://gitlab/Group/24',
      customFields: {
        count: 4,
        nodes: [
          {
            id: 'gid://gitlab/Issuables::CustomField/26',
            name: 'select type custom field',
            fieldType: 'SINGLE_SELECT',
            workItemTypes: [
              {
                id: 'gid://gitlab/WorkItems::Type/8',
                name: 'Epic',
                __typename: 'WorkItemType',
              },
              {
                id: 'gid://gitlab/WorkItems::Type/1',
                name: 'Issue',
                __typename: 'WorkItemType',
              },
              {
                id: 'gid://gitlab/WorkItems::Type/3',
                name: 'Test Case',
                __typename: 'WorkItemType',
              },
            ],
            __typename: 'CustomField',
          },
          {
            id: 'gid://gitlab/Issuables::CustomField/29',
            name: 'Text type custom field',
            fieldType: 'TEXT',
            workItemTypes: [],
            __typename: 'CustomField',
          },
          {
            id: 'gid://gitlab/Issuables::CustomField/27',
            name: 'Multi select custom field',
            fieldType: 'MULTI_SELECT',
            workItemTypes: [
              {
                id: 'gid://gitlab/WorkItems::Type/8',
                name: 'Epic',
                __typename: 'WorkItemType',
              },
              {
                id: 'gid://gitlab/WorkItems::Type/1',
                name: 'Issue',
                __typename: 'WorkItemType',
              },
              {
                id: 'gid://gitlab/WorkItems::Type/2',
                name: 'Task',
                __typename: 'WorkItemType',
              },
            ],
            __typename: 'CustomField',
          },
          {
            id: 'gid://gitlab/Issuables::CustomField/55',
            name: 'Task only Multi select custom field',
            fieldType: 'MULTI_SELECT',
            workItemTypes: [
              {
                id: 'gid://gitlab/WorkItems::Type/2',
                name: 'Task',
                __typename: 'WorkItemType',
              },
            ],
            __typename: 'CustomField',
          },
          {
            id: 'gid://gitlab/Issuables::CustomField/28',
            name: 'Number type custom field',
            fieldType: 'NUMBER',
            workItemTypes: [],
            __typename: 'CustomField',
          },
        ],
        __typename: 'CustomFieldConnection',
      },
      __typename: 'Group',
    },
  },
};
