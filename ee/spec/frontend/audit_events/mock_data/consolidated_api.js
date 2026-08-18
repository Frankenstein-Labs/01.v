export const groupStreamingDestinationDataPopulator = (nodes) => ({
  data: {
    group: {
      id: 'test-group-id',
      externalAuditEventStreamingDestinations: {
        nodes: nodes.map((node) => ({
          ...node,
          active: node.active !== undefined ? node.active : true,
        })),
      },
    },
  },
});

export const instanceStreamingDestinationDataPopulator = (nodes) => ({
  data: {
    auditEventsInstanceStreamingDestinations: {
      nodes: nodes.map((node) => ({
        ...node,
        active: node.active !== undefined ? node.active : true,
      })),
    },
  },
});

export const streamingDestinationDeleteMutationPopulator = (errors = []) => ({
  data: {
    groupAuditEventStreamingDestinationsDelete: {
      errors,
    },
  },
});

export const destinationCreateMutationPopulator = (errors = []) => ({
  errors,
  externalAuditEventDestination: {
    __typename: 'GroupAuditEventStreamingDestination',
    id: 'test-create-id',
    name: 'newDestinationName',
    category: 'http',
    config: {
      url: 'http://test.url',
    },
    secretToken: 'newSecretToken',
    eventTypeFilters: [],
    namespaceFilters: [],
    active: true,
  },
});

export const mockHttpTypeDestination = [
  {
    __typename: 'GroupAuditEventStreamingDestination',
    id: 'mock-streaming-destination-1',
    name: 'HTTP Destination 1',
    category: 'http',
    config: {
      url: 'http://destination1.local',
      headers: {
        key1: {
          value: 'test',
          active: true,
        },
      },
    },
    secretToken: 'mockSecretToken',
    eventTypeFilters: ['user_created'],
    namespaceFilters: [
      {
        __typename: 'GroupAuditEventNamespaceFilter',
        id: 'gid://gitlab/AuditEvents::Group::NamespaceFilter/1',
        namespace: {
          __typename: 'Namespace',
          id: 'gid://gitlab/Namespaces::ProjectNamespace/107',
          name: 'project1',
          fullPath: 'myGroup/project1',
        },
      },
    ],
    active: true,
  },
  {
    __typename: 'GroupAuditEventStreamingDestination',
    id: 'mock-streaming-destination-2',
    name: 'HTTP Destination 2',
    category: 'http',
    config: {
      url: 'http://destination1.local',
      headers: {
        key1: {
          value: 'test',
          active: false,
        },
      },
    },
    secretToken: 'mockSecretToken',
    eventTypeFilters: ['add_gpg_key', 'user_created'],
    namespaceFilters: [],
    active: true,
  },
];

export const mockAwsTypeDestination = [
  {
    __typename: 'GroupAuditEventStreamingDestination',
    id: 'mock-streaming-destination-3',
    name: 'AWS Destination 1',
    category: 'aws',
    config: {
      awsRegion: 'us-test-1',
      bucketName: 'bucket-name',
      accessKeyXid: 'myAwsAccessKey_needs_16_chars_min',
    },
    secretToken: 'SECRET_ACCESS_KEY_1',
    eventTypeFilters: [],
    namespaceFilters: [],
    active: true,
  },
  {
    __typename: 'GroupAuditEventStreamingDestination',
    id: 'mock-streaming-destination-4',
    name: 'AWS Destination 2',
    category: 'aws',
    config: {
      awsRegion: 'eu-test-2',
      bucketName: 'bucket-name-2',
      accessKeyXid: 'mySecond_AwsAccessKey_needs_16_chars_min',
    },
    secretToken: 'SECRET_ACCESS_KEY_2',
    eventTypeFilters: [],
    namespaceFilters: [],
    active: true,
  },
];

export const mockGcpTypeDestination = [
  {
    __typename: 'GroupAuditEventStreamingDestination',
    id: 'mock-streaming-destination-5',
    name: 'GCP Destination 1',
    category: 'gcp',
    config: {
      logIdName: 'gcp-log-id-name',
      clientEmail: 'clientEmail@example.com',
      googleProjectIdName: 'google-project-id-name',
    },
    secretToken: 'PRIVATE_KEY_1',
    eventTypeFilters: [],
    namespaceFilters: [],
    active: true,
  },
  {
    __typename: 'GroupAuditEventStreamingDestination',
    id: 'mock-streaming-destination-6',
    name: 'GCP Destination 2',
    category: 'gcp',
    config: {
      logIdName: 'gcp-log-id-name2',
      clientEmail: 'clientEmail2@example.com',
      googleProjectIdName: 'google-project-id-name-2',
    },
    secretToken: 'PRIVATE_KEY_2',
    eventTypeFilters: [],
    namespaceFilters: [],
    active: true,
  },
];

export const mockAllAPIDestinations = [
  ...mockHttpTypeDestination,
  ...mockAwsTypeDestination,
  ...mockGcpTypeDestination,
];
