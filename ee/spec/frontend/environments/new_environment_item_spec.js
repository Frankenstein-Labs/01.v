import VueApollo from 'vue-apollo';
import Vue from 'vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import EnvironmentItem from '~/environments/components/new_environment_item.vue';
import EnvironmentAlert from 'ee/environments/components/environment_alert.vue';
import EnvironmentApproval from 'ee/environments/components/environment_approval.vue';
import alertQuery from 'ee/environments/graphql/queries/environment.query.graphql';
import { resolvedEnvironment } from 'jest/environments/graphql/mock_data';

Vue.use(VueApollo);

describe('~/environments/components/new_environment_item.vue', () => {
  let wrapper;

  const createApolloProvider = () => {
    return createMockApollo([
      [
        alertQuery,
        jest.fn().mockResolvedValue({
          data: {
            project: {
              id: '1',
              environment: {
                id: '2',
                latestOpenedMostSevereAlert: {
                  id: '4',
                  severity: 'CRITICAL',
                  title: 'alert title',
                  detailsUrl: '/alert/details',
                  startedAt: new Date(),
                },
              },
            },
          },
        }),
      ],
    ]);
  };

  const createWrapper = ({ propsData = {}, apolloProvider } = {}) => {
    wrapper = shallowMountExtended(EnvironmentItem, {
      apolloProvider,
      propsData: { environment: resolvedEnvironment, ...propsData },
      provide: { helpPagePath: '/help', projectId: '1', projectPath: '/1' },
      stubs: { EnvironmentAlert, EnvironmentApproval },
    });
  };

  const findAlert = () => wrapper.findComponent(EnvironmentAlert);

  it('shows an alert if one is opened', () => {
    const environment = { ...resolvedEnvironment, hasOpenedAlert: true };
    createWrapper({ propsData: { environment }, apolloProvider: createApolloProvider() });

    expect(findAlert().exists()).toBe(true);
    expect(findAlert().props('environment')).toBe(environment);
  });

  it('does not show an alert if one is opened', () => {
    createWrapper({ apolloProvider: createApolloProvider() });

    expect(findAlert().exists()).toBe(false);
  });
});
