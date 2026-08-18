import showToast from '~/vue_shared/plugins/global_toast';
import RegistryUpstreamItem from './registry_upstream_item.vue';

export default {
  component: RegistryUpstreamItem,
  title: 'ee/virtual_registries/registry_upstream_item',
  argTypes: {
    reorderUpstream: {
      description: 'Emitted when the upstream is reordered',
      action: 'reorderUpstream',
      table: {
        type: {
          summary: '(direction: "up" | "down", upstream: object) => void',
        },
      },
    },
    clearCache: {
      description: 'Emitted when the cache is cleared',
      action: 'clearCache',
      table: {
        type: {
          summary: '(upstream: object) => void',
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

const Template = (_, { argTypes }) => ({
  components: { RegistryUpstreamItem },
  props: Object.keys(argTypes),
  provide: {
    glAbilities: {
      updateVirtualRegistry: true,
      destroyVirtualRegistry: true,
    },
    editUpstreamPathTemplate: 'path/:id/edit',
    showUpstreamPathTemplate: 'path/:id',
  },
  template:
    '<registry-upstream-item v-bind="$props" @clearCache="clearCache" @deleteUpstream="deleteUpstream" @reorderUpstream="reorderUpstream" />',
});

export const Default = Template.bind({});
Default.args = {
  index: 0,
  upstreamsCount: 2,
  registryUpstream: {
    id: 1,
    position: 1,
    upstream: {
      id: 1,
      name: 'Upstream title',
      description: 'Upstream description',
      url: 'http://maven.org/test',
      cacheValidityHours: 24,
      metadataCacheValidityHours: 48,
    },
  },
  clearCache: (id) => {
    showToast(`clearCache: ${id}`);
  },
  deleteUpstream: (id) => {
    showToast(`deleteUpstream: ${id}`);
  },
  reorderUpstream: (direction, upstreamId) => {
    showToast(`reorderUpstream: ${direction} ${upstreamId}`);
  },
};
Default.parameters = {
  docs: {
    description: {
      story: `The \`RegistryUpstreamItem\` component is used to display an upstream in the virtual registry list. Many parts of the component are conditionally rendered based on the \`upstream\` object.

- The "Clear cache" button is only displayed if \`canClearCache\` is \`true\`. This button emits a \`clearCache\` event when clicked.
- The "Edit" button is only displayed if \`canEdit\` is \`true\` and \`editPath\` is defined. This button is a link to the upstream edit page.
- The "Delete" button is only displayed if \`canDelete\` is \`true\`. This button emits a \`deleteUpstream\` event when clicked.
`,
    },
  },
};
