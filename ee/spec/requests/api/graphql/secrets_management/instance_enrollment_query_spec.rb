# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Querying instance secrets manager enrollment', feature_category: :secrets_management do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let(:query) { graphql_query_for(:instance_secrets_manager_enrollment, {}, 'enrolled beta') }

  subject(:resolved_value) do
    post_graphql(query, current_user: current_user)
    graphql_data_at(:instance_secrets_manager_enrollment)
  end

  before do
    allow(::License).to receive(:feature_available?).and_call_original
    allow(::License).to receive(:feature_available?).with(:native_secrets_management).and_return(true)
  end

  context 'when on GitLab.com', :saas do
    let_it_be(:current_user) { create(:admin) }

    it 'returns a resource not available error (instance enrollment is self-managed only)' do
      post_graphql(query, current_user: current_user)
      expect_graphql_errors_to_include("you don't have permission")
    end
  end

  context 'when not on GitLab.com' do
    it_behaves_like 'authorizing granular token permissions for GraphQL', :read_secrets_manager_enrollment do
      let(:user) { create(:admin) }
      let(:boundary_object) { :instance }
      let(:request) { post_graphql(query, token: { personal_access_token: pat }) }
    end

    context 'when current user is not an admin' do
      it 'returns a resource not available error' do
        post_graphql(query, current_user: current_user)
        expect_graphql_errors_to_include("you don't have permission")
      end
    end

    context 'when license is not available' do
      let_it_be(:current_user) { create(:admin) }

      before do
        allow(::License).to receive(:feature_available?).with(:native_secrets_management).and_return(false)
      end

      it 'returns a resource not available error' do
        post_graphql(query, current_user: current_user)
        expect_graphql_errors_to_include("you don't have permission")
      end
    end

    context 'when enrollment feature flag is disabled' do
      let_it_be(:current_user) { create(:admin) }

      before do
        stub_feature_flags(secrets_manager_instance_enrollment: false)
      end

      it 'returns a resource not available error' do
        post_graphql(query, current_user: current_user)
        expect_graphql_errors_to_include("you don't have permission")
      end
    end

    context 'when current user is an admin' do
      let_it_be(:current_user) { create(:admin) }

      context 'when instance is enrolled' do
        before do
          stub_application_setting(secrets_manager_instance_enrolled: true)
        end

        it 'returns an enrollment marked as beta' do
          expect(resolved_value).to eq('enrolled' => true, 'beta' => true)
        end
      end

      context 'when instance is not enrolled' do
        it 'returns an unenrolled, non-beta enrollment' do
          expect(resolved_value).to eq('enrolled' => false, 'beta' => false)
        end
      end
    end
  end
end
