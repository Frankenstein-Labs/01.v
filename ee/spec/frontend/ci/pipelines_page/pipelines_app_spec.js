import { shallowMount } from '@vue/test-utils';
import { createMockSubscription } from 'mock-apollo-client';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import PipelineAccountVerificationAlert from 'ee/vue_shared/components/pipeline_account_verification_alert.vue';
import waitForPromises from 'helpers/wait_for_promises';
import { mockGetPipelinesResponse, mockPipelinesCount } from 'jest/ci/pipelines_page/mock_data';

import PipelinesApp from '~/ci/pipelines_page/pipelines_app.vue';
import getPipelinesQuery from '~/ci/pipelines_page/graphql/queries/get_pipelines.query.graphql';
import getAllPipelinesCountQuery from '~/ci/pipelines_page/graphql/queries/get_all_pipelines_count.query.graphql';
import ciPipelineStatusesUpdatedSubscription from '~/ci/pipelines_page/graphql/subscriptions/ci_pipeline_statuses_updated.subscription.graphql';

Vue.use(VueApollo);

describe('Pipelines App', () => {
  let wrapper;
  let apolloProvider;
  let mockSubscription;
  let subscriptionHandler;

  const successHandler = jest.fn().mockResolvedValue(mockGetPipelinesResponse);
  const countHandler = jest.fn().mockResolvedValue(mockPipelinesCount);

  const defaultHandlers = [
    [getPipelinesQuery, successHandler],
    [getAllPipelinesCountQuery, countHandler],
  ];

  const createMockApolloProvider = () => {
    return createMockApollo(defaultHandlers);
  };

  const createComponent = ({ identityVerificationRequired = false } = {}) => {
    apolloProvider = createMockApolloProvider();

    subscriptionHandler = jest.fn(() => {
      mockSubscription = createMockSubscription();
      return mockSubscription;
    });

    apolloProvider.defaultClient.setRequestHandler(
      ciPipelineStatusesUpdatedSubscription,
      subscriptionHandler,
    );

    wrapper = shallowMount(PipelinesApp, {
      propsData: {
        hasGitlabCi: true,
        canCreatePipeline: false,
        params: {},
      },
      provide: {
        fullPath: 'gitlab-org/gitlab',
        identityVerificationRequired,
        identityVerificationPath: '#',
        usesExternalConfig: false,
      },
      apolloProvider,
    });
  };

  // PipelineAccountVerificationAlert handles its own rendering, we just need to check that the component is mounted
  // regardless what the value of identityVerificationRequired is.
  it.each([true, false])(
    'shows pipeline account verification alert when identityVerificationRequired is %s',
    async (identityVerificationRequired) => {
      createComponent({ identityVerificationRequired });
      await waitForPromises();

      expect(wrapper.findComponent(PipelineAccountVerificationAlert).exists()).toBe(true);
    },
  );
});
