import createMockApollo from 'helpers/mock_apollo_helper';
import getMavenUpstreamsCountQuery from 'ee/packages_and_registries/virtual_registries/graphql/queries/get_maven_upstreams_count.query.graphql';
import showToast from '~/vue_shared/plugins/global_toast';
import UpstreamsList from './upstreams_list.vue';

export default {
  component: UpstreamsList,
  title: 'ee/virtual_registries/upstreams_list',
  argTypes: {
    reorderUpstream: {
      description: 'Emitted when an upstream is reordered',
      action: 'reorderUpstream',
      table: {
        type: {
          summary: '(direction: "up" | "down", upstreamId: string) => void',
        },
      },
    },
    upstreamCreated: {
      description: 'Emitted when a new upstream is created',
      action: 'upstreamCreated',
      table: {
        type: {
          summary: '() => void',
        },
      },
    },
    editUpstream: {
      description: 'Emitted when a upstream is edited',
      action: 'editUpstream',
      table: {
        type: {
          summary:
            '(upstream: { name: string, url: string, cacheValidityHours?: number, description?: string, username?: string, password?: string }) => void',
        },
      },
    },
    testUpstream: {
      description: 'Emitted when an upstream is tested',
      action: 'testUpstream',
      table: {
        type: {
          summary:
            '(upstream: { name: string, url: string, cacheValidityHours?: number, description?: string, username?: string, password?: string }) => void',
        },
      },
    },
    deleteUpstream: {
      description: 'Emitted when the upstream is deleted',
      action: 'deleteUpstream',
      table: {
        type: {
          summary: '(upstreamId: string) => void',
        },
      },
    },
  },
};

const mockUpstreamsCountResponse = {
  data: {
    group: {
      upstreams: {
        count: 5,
      },
    },
  },
};

const requestHandlers = [
  [getMavenUpstreamsCountQuery, () => Promise.resolve(mockUpstreamsCountResponse)],
];

const apolloProvider = createMockApollo(requestHandlers);

const Template = (_, { argTypes }) => ({
  components: { UpstreamsList },
  apolloProvider,
  props: Object.keys(argTypes),
  provide: {
    glAbilities: {
      createVirtualRegistry: true,
      updateVirtualRegistry: true,
    },
    fullPath: 'my-group',
    getUpstreamsCountQuery: getMavenUpstreamsCountQuery,
    ids: {
      baseRegistry: 'VirtualRegistries::Packages::Maven::Registry',
    },
    maxRegistryUpstreamsCount: 20,
    registryEditPath: 'edit_path',
    editUpstreamPathTemplate: 'path/:id/edit',
    showUpstreamPathTemplate: 'path/:id',
  },
  template:
    '<upstreams-list v-bind="$props" @upstreamCreated="upstreamCreated" @testUpstream="testUpstream" @upstreamReordered="upstreamReordered" @editUpstream="editUpstream" @deleteUpstream="deleteUpstream" />',
});

export const Default = Template.bind({});
Default.args = {
  id: 'gid://gitlab/VirtualRegistries::Packages::Maven::Registry/1',
  registryUpstreams: [
    {
      id: 1,
      position: 1,
      upstream: {
        id: 1,
        name: 'Upstream title',
        description: 'Upstream description',
        url: 'http://maven.org/test',
        cacheValidityHours: 24,
        metadataCacheValidityHours: 48,
        cacheSize: '100 MB',
        canClearCache: true,
        artifactCount: 100,
      },
    },
    {
      id: 2,
      position: 2,
      upstream: {
        id: 2,
        name: 'Upstream title 2',
        description: 'Upstream description 2',
        url: 'http://maven.org/test2',
        cacheValidityHours: 1,
        metadataCacheValidityHours: 2,
        cacheSize: '11.2 GB',
        canClearCache: false,
        artifactCount: 1,
      },
    },
  ],
  canTestUpstream: true,
  upstreamCreated: () => {
    showToast('Upstream created');
  },
  testUpstream: (upstream) => {
    showToast(`Upstream test called for "${upstream.name}"`);
  },
  upstreamReordered: () => {
    showToast('Upstream reordered');
  },
  deleteUpstream: (upstreamId) => {
    showToast(`Upstream delete called for "${upstreamId}"`);
  },
};

Default.parameters = {
  docs: {
    description: {
      story:
        'Note that the `UpstreamsList` component delegates CRUD actions like creating, testing, reordering, and deleting upstreams and clearing cache to its parent via emits.',
    },
  },
};
