# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Delete action for project subscriptions', feature_category: :continuous_integration do
  include GraphqlHelpers

  let_it_be(:project) { create(:project, :repository, :public) }
  let_it_be(:upstream_project) { create(:project, :repository, :public) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:subscription) do
    create(:ci_subscriptions_project, downstream_project: project, upstream_project: upstream_project)
  end

  let(:subscription_global_id) { subscription.to_global_id }
  let(:mutation) do
    graphql_mutation(:project_subscription_delete, subscription_id: subscription_global_id) do
      <<~QL
        project {
          name
        }
        errors
      QL
    end
  end

  let(:mutation_response) { graphql_mutation_response(:project_subscription_delete) }

  subject { post_graphql_mutation(mutation, current_user: current_user) }

  before do
    stub_licensed_features(ci_project_subscriptions: true)
  end

  context 'when the user is authorized' do
    before_all do
      project.add_maintainer(current_user)
    end

    context 'when a successful result is yielded' do
      it 'returns the project' do
        subject
        expect(mutation_response['project']['name']).to eq(project.name)
      end

      it 'deletes the subscription' do
        expect { subject }.to change { ::Ci::Subscriptions::Project.count }.by(-1)
      end
    end

    context 'when the subscription_id is invalid' do
      let(:subscription_global_id) { 'gid://gitlab/Ci::Subscriptions::Project/-12' }

      it 'does not reduce the subscriptions' do
        expect { subject }.to not_change { ::Ci::Subscriptions::Project.count }
      end

      it 'raises an exception' do
        subject
        expect(graphql_errors)
          .to include(a_hash_including('message' => "The resource that you are attempting to access does " \
                                                    "not exist or you don't have permission to perform this action"))
      end
    end

    context 'when the service returns an error' do
      let(:service) { instance_double(::Ci::DeleteProjectSubscriptionService) }
      let(:service_response) { ServiceResponse.error(message: 'An error message.') }

      before do
        allow(::Ci::DeleteProjectSubscriptionService).to receive(:new) { service }
        allow(service).to receive(:execute) { service_response }
      end

      it_behaves_like 'a mutation that returns errors in the response',
        errors: ['An error message.']

      it 'does not create a new record' do
        expect { subject }.not_to change { ::Ci::Subscriptions::Project.count }
      end
    end
  end

  context 'when the user is not authorized' do
    it 'does not reduce the subscriptions' do
      expect { subject }.to not_change { ::Ci::Subscriptions::Project.count }
    end

    it 'returns an error' do
      subject
      expect(graphql_errors)
        .to include(a_hash_including('message' => "The resource that you are attempting to access does " \
                                                  "not exist or you don't have permission to perform this action"))
    end
  end
end
