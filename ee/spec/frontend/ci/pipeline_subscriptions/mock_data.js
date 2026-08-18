// fixtures located in ee/spec/frontend/fixtures/pipeline_subscriptions.rb
import mockUpstreamSubscriptions from 'test_fixtures/graphql/pipeline_subscriptions/upstream.json';
import mockDownstreamSubscriptions from 'test_fixtures/graphql/pipeline_subscriptions/downstream.json';

export const deleteMutationResponse = {
  data: {
    projectSubscriptionDelete: {
      project: {
        id: 'gid://gitlab/Project/20',
        __typename: 'Project',
      },
      errors: [],
      __typename: 'ProjectSubscriptionDeletePayload',
    },
  },
};

export const addMutationResponse = {
  data: {
    projectSubscriptionCreate: {
      subscription: {
        id: 'gid://gitlab/Ci::Subscriptions::Project/18',
        __typename: 'CiSubscriptionsProject',
      },
      errors: [],
      __typename: 'ProjectSubscriptionCreatePayload',
    },
  },
};

export { mockUpstreamSubscriptions, mockDownstreamSubscriptions };
