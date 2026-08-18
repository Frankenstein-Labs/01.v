import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMount } from '@vue/test-utils';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { getProjectContainerScanning } from 'ee/packages_and_registries/container_registry/explorer/graphql/queries/get_project_container_scanning.query.graphql';
import component from 'ee/packages_and_registries/container_registry/explorer/components/list_page/metadata_container_scanning.vue';
import {
  graphQLProjectContainerScanningForRegistryOnMock,
  graphQLProjectContainerScanningForRegistryOffMock,
  graphQLProjectContainerScanningForRegistryHiddenMock,
} from './mock_data';

describe('Metadata Container Scanning', () => {
  let apolloProvider;
  let wrapper;

  const waitForApolloRequestRender = async () => {
    await waitForPromises();
  };

  const mountComponent = ({
    config = {
      projectPath: 'project',
      securityConfigurationPath: '/path',
    },
    requestHandlers,
    containerScanningForRegistryMock,
  } = {}) => {
    Vue.use(VueApollo);

    const cacheOptions = {
      typePolicies: {
        Project: {
          fields: {
            containerScanningForRegistry: {
              read() {
                return containerScanningForRegistryMock;
              },
            },
          },
        },
      },
    };

    apolloProvider = createMockApollo(requestHandlers, {}, cacheOptions);

    apolloProvider.clients.defaultClient.writeQuery({
      query: getProjectContainerScanning,
      variables: {
        fullPath: config.projectPath,
        securityConfigurationPath: config.securityConfigurationPath,
      },
      data: graphQLProjectContainerScanningForRegistryOnMock.data,
    });

    wrapper = shallowMount(component, {
      apolloProvider,
      provide() {
        return {
          config,
        };
      },
    });
  };

  it('renders the on status', async () => {
    const requestHandlers = [
      [
        getProjectContainerScanning,
        jest.fn().mockResolvedValue(graphQLProjectContainerScanningForRegistryOnMock),
      ],
    ];

    const containerScanningForRegistryMock =
      graphQLProjectContainerScanningForRegistryOnMock.data.project.containerScanningForRegistry;

    mountComponent({ requestHandlers, containerScanningForRegistryMock });

    await waitForApolloRequestRender();

    expect(wrapper.text()).toContain('Container scanning for registry: On');
  });

  it('renders the off status', async () => {
    const requestHandlers = [
      [
        getProjectContainerScanning,
        jest.fn().mockResolvedValue(graphQLProjectContainerScanningForRegistryOffMock),
      ],
    ];

    const containerScanningForRegistryMock =
      graphQLProjectContainerScanningForRegistryOffMock.data.project.containerScanningForRegistry;

    mountComponent({ requestHandlers, containerScanningForRegistryMock });

    await waitForApolloRequestRender();

    expect(wrapper.text()).toContain('Container scanning for registry: Off');
  });

  it('does not render when disabled', async () => {
    const requestHandlers = [
      [
        getProjectContainerScanning,
        jest.fn().mockResolvedValue(graphQLProjectContainerScanningForRegistryHiddenMock),
      ],
    ];

    const containerScanningForRegistryMock =
      graphQLProjectContainerScanningForRegistryHiddenMock.data.project
        .containerScanningForRegistry;

    mountComponent({ requestHandlers, containerScanningForRegistryMock });

    await waitForApolloRequestRender();

    expect(wrapper.text()).toBe('');
  });

  it('does not render when feature flag disabled', async () => {
    const requestHandlers = [
      [
        getProjectContainerScanning,
        jest.fn().mockResolvedValue(graphQLProjectContainerScanningForRegistryHiddenMock),
      ],
    ];

    const containerScanningForRegistryMock =
      graphQLProjectContainerScanningForRegistryHiddenMock.data.project
        .containerScanningForRegistry;

    mountComponent({ requestHandlers, containerScanningForRegistryMock });

    await waitForApolloRequestRender();

    expect(wrapper.text()).toBe('');
  });
});
