# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Create project subscription', feature_category: :continuous_integration do
  include GraphqlHelpers

  let_it_be_with_reload(:project) { create(:project, :repository, :public) }
  let_it_be(:upstream_project) { create(:project, :repository, :public) }
  let_it_be(:current_user) { create(:user) }

  let(:mutation) do
    graphql_mutation(:project_subscription_create, params) do
      <<~QL
        subscription {
          id
          downstreamProject {
            name
          }
          upstreamProject {
            id
            name
          }
        }
        errors
      QL
    end
  end

  let(:params) { { project_path: project.full_path, upstream_path: upstream_project.full_path } }
  let(:mutation_response) { graphql_mutation_response(:project_subscription_create) }

  subject(:post_mutation) { post_graphql_mutation(mutation, current_user: current_user) }

  before do
    stub_licensed_features(ci_project_subscriptions: true)
  end

  context 'when the user has the required permissions' do
    before_all do
      project.add_maintainer(current_user)
      upstream_project.add_developer(current_user)
    end

    context 'when a successful result is yielded' do
      it 'does creates a new record' do
        expect { post_mutation }.to change { ::Ci::Subscriptions::Project.count }.by(1)
      end

      it 'returns the subscription' do
        post_mutation
        expect(mutation_response['subscription']['downstreamProject']['name']).to eq(project.name)
      end
    end

    context 'when the downstream path is invalid' do
      let(:params) { { project_path: 'An/Invalid/Path', upstream_path: upstream_project.full_path } }

      it 'returns an error' do
        post_mutation
        expect(graphql_errors)
          .to include(a_hash_including('message' => "The resource that you are attempting to access does " \
                                                    "not exist or you don't have permission to perform this action"))
      end

      it 'does not create a new record' do
        expect { post_mutation }.not_to change { ::Ci::Subscriptions::Project.count }
      end
    end

    context 'when the upstream path is invalid' do
      let(:params) { { project_path: project.full_path, upstream_path: 'An/Invalid/Path' } }

      it 'returns an error' do
        post_mutation
        expect(graphql_errors)
          .to include(a_hash_including('message' => "The resource that you are attempting to access does " \
                                                    "not exist or you don't have permission to perform this action"))
      end

      it 'does not create a new record' do
        expect { post_mutation }.not_to change { ::Ci::Subscriptions::Project.count }
      end
    end

    context 'when the service returns an error' do
      let(:service) { instance_double(::Ci::CreateProjectSubscriptionService) }
      let(:service_response) { ServiceResponse.error(message: 'An error message.') }

      before do
        allow(::Ci::CreateProjectSubscriptionService).to receive(:new) { service }
        allow(service).to receive(:execute) { service_response }
      end

      it_behaves_like 'a mutation that returns errors in the response',
        errors: ['An error message.']

      it 'does not create a new record' do
        expect { post_mutation }.not_to change { ::Ci::Subscriptions::Project.count }
      end
    end
  end

  context 'when the user does not have the maintainer role' do
    before_all do
      upstream_project.add_developer(current_user)
    end

    it 'returns an error' do
      post_mutation
      expect(graphql_errors)
        .to include(a_hash_including('message' => "The resource that you are attempting to access does " \
                                                  "not exist or you don't have permission to perform this action"))
    end

    it 'does not create a new record' do
      expect { post_mutation }.not_to change { ::Ci::Subscriptions::Project.count }
    end
  end

  context 'when the user does not have the developer role' do
    before_all do
      project.add_maintainer(current_user)
    end

    it 'returns an error' do
      post_mutation
      expect(graphql_errors)
        .to include(a_hash_including('message' => "The resource that you are attempting to access does " \
                                                  "not exist or you don't have permission to perform this action"))
    end

    it 'does not create a new record' do
      expect { post_mutation }.not_to change { ::Ci::Subscriptions::Project.count }
    end
  end
end
