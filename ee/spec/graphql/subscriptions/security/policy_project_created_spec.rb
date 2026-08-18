# frozen_string_literal: true

require "spec_helper"

RSpec.describe Subscriptions::Security::PolicyProjectCreated, feature_category: :security_policy_management do
  include GraphqlHelpers
  include ::Graphql::Subscriptions::Security::PolicyProjectCreated::Helper

  let_it_be(:project) { create(:project) }
  let_it_be(:security_policy_project) { create(:project) }
  let_it_be(:user) { create(:user) }

  let(:current_user) { nil }
  let(:subscribe) { security_policy_project_created_subscription(project, current_user) }
  let(:status) { :success }
  let(:errors) { [] }

  let(:security_policy_project_created) do
    graphql_dig_at(graphql_data(response[:result]), :securityPolicyProjectCreated)
  end

  before_all do
    project.add_owner(user)
  end

  before do
    stub_licensed_features(security_orchestration_policies: true)

    stub_const('GitlabSchema', Graphql::Subscriptions::ActionCable::MockGitlabSchema)
    Graphql::Subscriptions::ActionCable::MockActionCable.clear_mocks
  end

  subject(:response) do
    subscription_response do
      GraphqlTriggers.security_policy_project_created(project, status, security_policy_project, errors)
    end
  end

  context 'when user is unauthorized' do
    it 'does not receive any data' do
      expect(response).to be_nil
    end
  end

  context 'when user is authorized' do
    let(:current_user) { user }

    it 'does not receive the security policy project' do
      created_response = security_policy_project_created

      expect(created_response['project']).to be_nil
      expect(created_response['errors']).to eq([])
      expect(created_response['errorMessage']).to be_nil
      expect(created_response['status']).to eq('SUCCESS')
    end

    context 'and user has access to the security policy project' do
      before_all do
        security_policy_project.add_owner(user)
      end

      it 'receives the security policy project' do
        created_response = security_policy_project_created

        expect(created_response['project']['name']).to eq(security_policy_project.name)
        expect(created_response['errors']).to eq([])
        expect(created_response['errorMessage']).to be_nil
        expect(created_response['status']).to eq('SUCCESS')
      end

      context 'and there is an error' do
        let_it_be(:security_policy_project) { nil }

        let(:errors) { ['Error'] }
        let(:status) { :error }

        it 'receives the error message' do
          created_response = security_policy_project_created

          expect(created_response['project']).to be_nil
          expect(created_response['errors']).to contain_exactly('Error')
          expect(created_response['errorMessage']).to eq('Error')
          expect(created_response['status']).to eq('ERROR')
        end
      end
    end
  end
end
