import { testProviderName, testTrainingUrls } from 'jest/security_configuration/mock_data';
import {
  SECURITY_TRAINING_URL_STATUS_COMPLETED,
  SUPPORTED_IDENTIFIER_TYPE_CWE,
} from 'ee/vulnerabilities/constants';

export const testIdentifierName = 'cwe-1';

export const testIdentifiers = [
  { externalType: SUPPORTED_IDENTIFIER_TYPE_CWE, externalId: testIdentifierName },
  { externalType: 'cve', externalId: 'cve-1' },
];

export const generateNote = ({ id = 1295 } = {}) => ({
  __typename: 'Note',
  id: `gid://gitlab/DiscussionNote/${id}`,
  body: 'Created a note.',
  bodyHtml: '\u003cp\u003eCreated a note\u003c/p\u003e',
  createdAt: '2021-08-25T16:19:10Z',
  updatedAt: '2021-08-25T16:21:18Z',
  system: false,
  systemNoteIconName: null,
  userPermissions: {
    adminNote: true,
  },
  author: {
    __typename: 'UserCore',
    id: 'gid://gitlab/User/1',
    name: 'Administrator',
    username: 'root',
    webPath: '/root',
  },
});

export const addTypenamesToDiscussion = (discussion) => {
  return {
    ...discussion,
    notes: {
      nodes: discussion.notes.nodes.map((n) => ({
        ...n,
        __typename: 'Note',
        author: {
          ...n.author,
          __typename: 'UserCore',
        },
      })),
    },
  };
};

const createSecurityTrainingUrls = ({ urlOverrides = {}, urls } = {}) =>
  urls || [
    {
      name: testProviderName[0],
      url: testTrainingUrls[0],
      status: SECURITY_TRAINING_URL_STATUS_COMPLETED,
      identifier: testIdentifierName,
      ...urlOverrides.first,
    },
    {
      name: testProviderName[1],
      url: testTrainingUrls[1],
      status: SECURITY_TRAINING_URL_STATUS_COMPLETED,
      identifier: testIdentifierName,
      ...urlOverrides.second,
    },
    {
      name: testProviderName[2],
      url: testTrainingUrls[2],
      status: SECURITY_TRAINING_URL_STATUS_COMPLETED,
      identifier: testIdentifierName,
      ...urlOverrides.third,
    },
  ];

export const getSecurityTrainingProjectData = (urlOverrides = {}) => ({
  response: {
    data: {
      project: {
        id: 'gid://gitlab/Project/1',
        __typename: 'Project',
        securityTrainingUrls: createSecurityTrainingUrls(urlOverrides),
      },
    },
  },
});

export const getVulnerabilityStatusMutationResponse = (queryName, expected) => ({
  data: {
    [queryName]: {
      errors: [],
      vulnerability: {
        id: 'gid://gitlab/Vulnerability/54',
        [`${expected}At`]: '2020-09-16T11:13:26Z',
        state: expected.toUpperCase(),
        ...(expected !== 'detected' && {
          [`${expected}By`]: {
            id: 'gid://gitlab/User/1',
          },
        }),
        stateTransitions: {
          nodes: [
            {
              dismissalReason: 'USED_IN_TESTS',
            },
          ],
        },
      },
    },
  },
});

export const dismissalDescriptions = {
  acceptable_risk:
    'The vulnerability is known, and has not been remediated or mitigated, but is considered to be an acceptable business risk.',
  false_positive:
    'An error in reporting in which a test result incorrectly indicates the presence of a vulnerability in a system when the vulnerability is not present.',
  mitigating_control:
    'A management, operational, or technical control (that is, safeguard or countermeasure) employed by an organization that provides equivalent or comparable protection for an information system.',
  used_in_tests: 'The finding is not a vulnerability because it is part of a test or is test data.',
  not_applicable:
    'The vulnerability is known, and has not been remediated or mitigated, but is considered to be in a part of the application that will not be updated.',
};

export const getAiSubscriptionResponse = (content = 'response text') => ({
  id: '123',
  content,
  contentHtml: `<p>${content}</p>`,
  errors: [],
  requestId: '123',
  role: 'assistant',
  timestamp: '2021-05-26T14:00:00.000Z',
  type: null,
  chunkId: null,
  extras: null,
  threadId: null,
});

export const AI_SUBSCRIPTION_ERROR_RESPONSE = {
  ...getAiSubscriptionResponse(),
  errors: ['subscription error'],
};

export const MUTATION_AI_ACTION_DEFAULT_RESPONSE = jest.fn().mockResolvedValue({
  data: { aiAction: { errors: [] } },
});

export const MUTATION_AI_ACTION_GLOBAL_ERROR = jest.fn().mockResolvedValue({
  data: { aiAction: null },
  errors: [{ message: 'mutation global error' }],
});

export const MUTATION_AI_ACTION_ERROR = jest.fn().mockResolvedValue({
  data: { aiAction: { errors: ['mutation ai action error'] } },
});

export const TEST_ALL_BLOBS_INFO_GRAPHQL_SUCCESS_RESPONSE = {
  data: {
    project: {
      __typename: 'Project',
      id: '1',
      repository: {
        __typename: 'Repository',
        empty: false,
        blobs: {
          __typename: 'RepositoryBlobConnection',
          nodes: [
            {
              __typename: 'RepositoryBlob',
              id: '2',
              webPath: 'src/url/test.java',
              name: 'test.java',
              size: '10271',
              rawSize: '10271',
              rawTextBlob: '{\n  "newArray": [],\n }',
              fileType: null,
              language: 'java',
              path: 'src/url/test.java',
              blamePath: 'src/url/test.java',
              editBlobPath: 'src/url/test.java',
              gitpodBlobUrl: null,
              ideEditPath: 'src/url/test.java',
              forkAndEditPath: 'test.java&namespace_key=1',
              ideForkAndEditPath: 'src%2Furl%2Ftest.java&namespace_key=1',
              codeNavigationPath: null,
              projectBlobPathRoot: 'd474dea0d13ca8ed94fd6b8ac0431998cc6d04e0',
              forkAndViewPath: 'src%2Furl%2Ftest.java&namespace_key=1',
              environmentFormattedExternalUrl: null,
              environmentExternalUrlForRouteMap: null,
              canModifyBlob: false,
              canModifyBlobWithWebIde: false,
              canCurrentUserPushToBranch: false,
              archived: false,
              storedExternally: null,
              externalStorage: null,
              externalStorageUrl: null,
              rawPath: 'src/url/test.java',
              replacePath: 'src/url/test.java',
              pipelineEditorPath: null,
              simpleViewer: {
                fileType: 'text',
                tooLarge: false,
                type: 'simple',
                renderError: null,
                __typename: 'BlobViewer',
              },
              richViewer: null,
            },
          ],
        },
      },
    },
  },
};

export const mockVulnerability = {
  id: 123,
  description: 'vulnerability description',
  descriptionHtml: 'vulnerability description <code>sample</code>',
  details: {
    name: 'code_flows',
    type: 'code_flows',
    items: [
      [
        {
          nodeType: 'source',
          fileDescription: '{',
          rawTextBlobs: '{ a: 1, a: 2 }',
          stepNumber: 1,
          fileLocation: {
            fileName: 'src/url/test.java',
            lineStart: 1,
          },
        },
        {
          nodeType: 'propagation',
          fileDescription: '{',
          rawTextBlobs: '{ b: 1, b: 2 }',
          stepNumber: 2,
          fileLocation: { fileName: 'src/url/test.java', lineStart: 1 },
        },
        {
          nodeType: 'sink',
          fileDescription: '{',
          rawTextBlobs: '{ c: 1, c: 2 }',
          stepNumber: 3,
          fileLocation: {
            lineEnd: 2,
            fileName: 'src/url/test.java',
            lineStart: 1,
          },
        },
      ],
    ],
  },
  rawTextBlobs: {
    'src/url/test.java': '{\n  "newArray": [],\n }',
  },
};
