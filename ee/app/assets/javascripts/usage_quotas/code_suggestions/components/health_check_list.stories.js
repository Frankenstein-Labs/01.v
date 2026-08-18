import createMockApollo from 'helpers/mock_apollo_helper';
import getCloudConnectorHealthStatus from 'ee/usage_quotas/add_on/graphql/cloud_connector_health_check.query.graphql';
import HealthCheckList from './health_check_list.vue';

export default {
  component: HealthCheckList,
  title: 'ee/usage_quotas/code_suggestions/health_check_list',
};

const template = `
    <div>
      <health-check-list />
    </div>
  `;

const createTemplate = (config = {}) => {
  const requestHandlers = [
    [
      getCloudConnectorHealthStatus,
      () =>
        Promise.resolve({
          data: {
            cloudConnectorStatus: {
              ...config,
            },
          },
        }),
    ],
  ];
  const apolloProvider = createMockApollo(requestHandlers);

  return () => ({
    components: { HealthCheckList },
    apolloProvider,
    template,
  });
};

export const Failure = {
  render: createTemplate({
    success: false,
    probeResults: [
      {
        name: 'license_probe',
        success: false,
        message: 'Online Cloud License found',
      },
      {
        name: 'host_probe',
        success: false,
        message: 'customers.gitlab.com reachable',
      },
      {
        name: 'host_probe',
        success: false,
        message: 'cloud.gitlab.com reachable',
      },
    ],
  }),
};
export const Success = {
  render: createTemplate({
    success: true,
    probeResults: [
      {
        name: 'license_probe',
        success: true,
        message: 'Online Cloud License found',
      },
      {
        name: 'host_probe',
        success: true,
        message: 'customers.gitlab.com reachable',
      },
      {
        name: 'host_probe',
        success: true,
        message: 'cloud.gitlab.com reachable',
      },
    ],
  }),
};
export const Mixed = {
  render: createTemplate({
    success: false,
    probeResults: [
      {
        name: 'license_probe',
        success: true,
        message: 'Online Cloud License found',
      },
      {
        name: 'host_probe',
        success: false,
        message: 'customers.gitlab.com not reachable',
      },
      {
        name: 'host_probe',
        success: true,
        message: 'cloud.gitlab.com reachable',
      },
    ],
  }),
};
