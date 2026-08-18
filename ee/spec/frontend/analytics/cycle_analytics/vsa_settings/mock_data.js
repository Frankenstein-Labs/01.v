import { groupLabels } from '../mock_data';

export const MERGE_REQUEST_CREATED = 'merge_request_created';
export const ISSUE_CREATED = 'issue_created';
export const MERGE_REQUEST_CLOSED = 'merge_request_closed';
export const ISSUE_CLOSED = 'issue_closed';

export const emptyState = {
  id: null,
  name: null,
  startEventIdentifier: null,
  startEventLabelId: null,
  endEventIdentifier: null,
  endEventLabelId: null,
};

export const firstLabel = groupLabels[0];

export const defaultStages = [
  {
    name: 'issue',
    custom: false,
    relativePosition: 1,
    startEventIdentifier: 'issue_created',
    endEventIdentifier: 'issue_stage_end',
  },
  {
    name: 'plan',
    custom: false,
    relativePosition: 2,
    startEventIdentifier: 'plan_stage_start',
    endEventIdentifier: 'issue_first_mentioned_in_commit',
  },
  {
    name: 'code',
    custom: false,
    relativePosition: 3,
    startEventIdentifier: 'code_stage_start',
    endEventIdentifier: 'merge_request_created',
  },
];

export const mockLabels = [
  {
    id: 'gid://gitlab/GroupLabel/1',
    title: 'Red',
    color: '#FF0000',
    textColor: '#FFF',
    __typename: 'Label',
  },
  {
    id: 'gid://gitlab/GroupLabel/2',
    title: 'Green',
    color: '#00FF00',
    textColor: '#FFF',
    __typename: 'Label',
  },
  {
    id: 'gid://gitlab/GroupLabel/3',
    title: 'Blue',
    color: '#0000FF',
    textColor: '#FFF',
    __typename: 'Label',
  },
];

export const createMockLabelsResponse = (nodes, hasNextPage = false, endCursor = null) => ({
  data: {
    group: {
      id: 'gid://gitlab/Group/1',
      labels: {
        nodes,
        pageInfo: {
          hasNextPage,
          endCursor,
        },
      },
    },
  },
});

export const mockLabelsResponse = createMockLabelsResponse(mockLabels);

export const mockStages = [
  {
    id: 'gid://gitlab/ValueStream::Stage/1',
    name: 'default',
    custom: false,
    hidden: false,
    startEventHtmlDescription: 'description',
    endEventHtmlDescription: 'description',
    startEventIdentifier: 'ISSUE_CREATED',
    endEventIdentifier: 'ISSUE_CLOSED',
    startEventLabel: null,
    endEventLabel: null,
    __typename: 'ValueStreamStage',
  },
  {
    id: 'gid://gitlab/ValueStream::Stage/2',
    name: 'custom',
    custom: true,
    hidden: false,
    startEventHtmlDescription: 'description',
    endEventHtmlDescription: 'description',
    startEventIdentifier: 'ISSUE_LABEL_ADDED',
    endEventIdentifier: 'ISSUE_LABEL_REMOVED',
    startEventLabel: {
      id: mockLabels[0].id,
      title: mockLabels[0].title,
      color: mockLabels[0].color,
      __typename: 'Label',
    },
    endEventLabel: {
      id: mockLabels[1].id,
      title: mockLabels[1].title,
      color: mockLabels[1].color,
      __typename: 'Label',
    },
    __typename: 'ValueStreamStage',
  },
  {
    id: 'gid://gitlab/ValueStream::Stage/3',
    name: 'hidden',
    custom: false,
    hidden: true,
    startEventHtmlDescription: 'description',
    endEventHtmlDescription: 'description',
    startEventIdentifier: 'MERGE_REQUEST_CREATED',
    endEventIdentifier: 'MERGE_REQUEST_CLOSED',
    startEventLabel: null,
    endEventLabel: null,
    __typename: 'ValueStreamStage',
  },
];

export const mockValueStream = {
  id: 'gid://gitlab/ValueStream/1',
  name: 'oink',
  stages: mockStages,
  __typename: 'ValueStream',
};

export const createMockValueStreamResponse = (valueStream) => ({
  data: {
    group: {
      id: 'gid://gitlab/Group/1',
      valueStreams: {
        nodes: [valueStream],
        __typename: 'ValueStreamConnection',
      },
      __typename: 'Group',
    },
    project: null,
  },
});

export const mockValueStreamResponse = createMockValueStreamResponse(mockValueStream);

export const mockChangeValueStreamResponse = {
  data: {
    valueStreamChange: {
      valueStream: {
        id: 13,
      },
      errors: [],
    },
  },
};
