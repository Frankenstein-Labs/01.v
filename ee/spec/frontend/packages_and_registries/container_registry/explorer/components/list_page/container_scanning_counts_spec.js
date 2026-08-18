import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlSkeletonLoader, GlSprintf, GlLink } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { getProjectContainerScanning } from 'ee/packages_and_registries/container_registry/explorer/graphql/queries/get_project_container_scanning.query.graphql';
import component from 'ee/packages_and_registries/container_registry/explorer/components/list_page/container_scanning_counts.vue';

import {
  graphQLProjectContainerScanningForRegistryOnMock,
  graphQLProjectContainerScanningForRegistryOnMockCapped,
  graphQLProjectContainerScanningForRegistryOffMock,
} from './mock_data';

Vue.use(VueApollo);

describe('Container Scanning Counts', () => {
  let apolloProvider;
  let wrapper;

  const findCounts = () => wrapper.findByTestId('counts');
  const findVulnerabilityReportlink = () => findCounts().findComponent(GlLink);
  const findSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);

  const waitForApolloRequestRender = async () => {
    await waitForPromises();
  };

  const mountComponent = ({
    config = {
      projectPath: 'project',
      securityConfigurationPath: '/path',
      vulnerabilityReportPath: '/vulnerability/report/path',
    },
    requestHandlers,
    containerScanningForRegistryMock,
  } = {}) => {
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
        capped: true,
      },
      data: graphQLProjectContainerScanningForRegistryOnMock.data,
    });

    wrapper = shallowMountExtended(component, {
      apolloProvider,
      provide() {
        return {
          config,
        };
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  it('renders the counts after skeleton loader', async () => {
    const requestHandlers = [
      [
        getProjectContainerScanning,
        jest.fn().mockResolvedValue(graphQLProjectContainerScanningForRegistryOnMock),
      ],
    ];

    const containerScanningForRegistryMock =
      graphQLProjectContainerScanningForRegistryOnMock.data.project.containerScanningForRegistry;

    mountComponent({ requestHandlers, containerScanningForRegistryMock });

    expect(findSkeletonLoader().exists()).toBe(true);

    await waitForApolloRequestRender();

    expect(findCounts().text()).toBe(
      '3 critical, 12 high and 35 other vulnerabilities detected. View vulnerabilities',
    );
    expect(findVulnerabilityReportlink().attributes('href')).toBe('/vulnerability/report/path');
    expect(findSkeletonLoader().exists()).toBe(false);
  });

  it('renders the counts with capped limit', async () => {
    const requestHandlers = [
      [
        getProjectContainerScanning,
        jest.fn().mockResolvedValue(graphQLProjectContainerScanningForRegistryOnMockCapped),
      ],
    ];

    const containerScanningForRegistryMock =
      graphQLProjectContainerScanningForRegistryOnMockCapped.data.project
        .containerScanningForRegistry;

    mountComponent({ requestHandlers, containerScanningForRegistryMock });

    await waitForApolloRequestRender();

    expect(findCounts().text()).toBe(
      '1000+ critical, 20 high and 1000+ other vulnerabilities detected. View vulnerabilities',
    );
    expect(findVulnerabilityReportlink().attributes('href')).toBe('/vulnerability/report/path');
  });

  it('does not render when disabled', async () => {
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

    expect(findCounts().exists()).toBe(false);
  });
});
