import showToast from '~/vue_shared/plugins/global_toast';
import RegistryUpstreamForm from './form.vue';

export default {
  component: RegistryUpstreamForm,
  title: 'ee/virtual_registries/common/upstreams/form',
  argTypes: {
    createUpstream: {
      description: 'Emitted when a new upstream is created',
      action: 'createUpstream',
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
    cancel: {
      description: 'Emitted when the form is cancelled',
      action: 'cancel',
    },
  },
};

const Template = (_, { argTypes }) => ({
  components: { RegistryUpstreamForm },
  props: Object.keys(argTypes),
  template:
    '<registry-upstream-form v-bind="$props" @createUpstream="createUpstream" @testUpstream="testUpstream" @cancel="cancel" />',
});

export const Default = Template.bind({});
Default.args = {
  canTestUpstream: true,
  createUpstream: (upstream) => {
    showToast(`Upstream create called for "${upstream.name}"`);
  },
  testUpstream: (upstream) => {
    showToast(`Upstream test called for "${upstream.name}"`);
  },
  cancel: () => {
    showToast('Cancel called');
  },
};

Default.parameters = {
  docs: {
    description: {
      story:
        'Note that the `RegistryUpstreamForm` component delegates CRUD actions like creating and testing upstreams to its parent via emits.',
    },
  },
};
