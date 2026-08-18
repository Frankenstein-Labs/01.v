export const mockUpstream = {
  id: 5,
  name: 'Upstream Registry',
  url: 'https://gitlab.com/groups/gitlab-org/maven',
  description: 'Upstream registry description',
};

export const mavenUpstreamRegistry = {
  id: 'gid://gitlab/VirtualRegistries::Packages::Maven::Upstream/11',
  registryUpstreams: [
    {
      __typename: 'MavenRegistryUpstream',
      id: 'gid://gitlab/VirtualRegistries::Packages::Maven::RegistryUpstream/11',
      position: 2,
      registry: {
        id: 'gid://gitlab/VirtualRegistries::Packages::Maven::Registry/6',
        name: 'testing',
        __typename: 'MavenVirtualRegistry',
      },
    },
  ],
  __typename: 'MavenUpstream',
};

export const groupMavenUpstreams = {
  group: {
    id: 'gid://gitlab/Group/33',
    __typename: 'Group',
    upstreams: {
      __typename: 'MavenUpstreamConnection',
      count: 5,
      nodes: [
        {
          __typename: 'MavenUpstream',
          id: 'gid://gitlab/VirtualRegistries::Packages::Maven::Upstream/1',
          name: 'Maven Central',
          url: 'https://repo1.maven.org/maven2/',
          cacheValidityHours: 24,
          metadataCacheValidityHours: 12,
          registriesCount: 2,
        },
        {
          __typename: 'MavenUpstream',
          id: 'gid://gitlab/VirtualRegistries::Packages::Maven::Upstream/2',
          name: 'JCenter',
          url: 'https://jcenter.bintray.com/',
          cacheValidityHours: 48,
          metadataCacheValidityHours: 24,
          registriesCount: 1,
        },
      ],
      pageInfo: {
        hasPreviousPage: false,
        hasNextPage: false,
        startCursor: 'start',
        endCursor: 'end',
        __typename: 'PageInfo',
      },
    },
  },
};

export const groupMavenUpstreamsCount = {
  group: {
    id: 'gid://gitlab/Group/33',
    __typename: 'Group',
    upstreams: {
      __typename: 'MavenUpstreamConnection',
      count: 5,
    },
  },
};

export const groupMavenUpstreamsSelect = {
  group: {
    id: 'gid://gitlab/Group/33',
    __typename: 'Group',
    upstreams: {
      __typename: 'MavenUpstreamConnection',
      nodes: [
        {
          __typename: 'MavenUpstream',
          value: 'gid://gitlab/VirtualRegistries::Packages::Maven::Upstream/1',
          text: 'Maven Central',
          secondaryText: 'upstream description',
        },
      ],
      pageInfo: {
        hasPreviousPage: false,
        hasNextPage: false,
        startCursor: 'start',
        endCursor: 'end',
        __typename: 'PageInfo',
      },
    },
  },
};

export const mockContainerUpstreamResponse = {
  __typename: 'ContainerUpstream',
  id: 'gid://gitlab/VirtualRegistries::Container::Upstream/1',
  name: 'Container',
  url: 'https://gitlab.com',
  username: '',
  description: 'Container upstream description',
  cacheValidityHours: 24,
};

export const groupContainerUpstreams = {
  group: {
    id: 'gid://gitlab/Group/33',
    __typename: 'Group',
    upstreams: {
      __typename: 'ContainerUpstreamConnection',
      nodes: [
        {
          __typename: 'ContainerUpstream',
          id: 'gid://gitlab/VirtualRegistries::Container::Upstream/1',
          name: 'Container',
          url: 'https://gitlab.com',
          cacheValidityHours: 24,
          registriesCount: 2,
        },
      ],
      pageInfo: {
        hasPreviousPage: false,
        hasNextPage: false,
        startCursor: 'start',
        endCursor: 'end',
        __typename: 'PageInfo',
      },
    },
  },
};

export const groupContainerUpstreamsCount = {
  group: {
    id: 'gid://gitlab/Group/33',
    __typename: 'Group',
    upstreams: {
      __typename: 'ContainerUpstreamConnection',
      count: 5,
    },
  },
};

export const mockVirtualRegistriesCleanupPolicy = (options = {}) => {
  const { enabled = true, nextRunAt = '2025-01-15T10:00:00Z' } = options;

  return {
    data: {
      group: {
        id: 'gid://gitlab/Group/1',
        __typename: 'Group',
        virtualRegistriesCleanupPolicy: {
          __typename: 'VirtualRegistriesCleanupPolicy',
          enabled,
          nextRunAt: enabled ? nextRunAt : null,
        },
      },
    },
  };
};
