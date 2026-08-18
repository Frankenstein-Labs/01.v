# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Unenroll the instance from secrets manager', feature_category: :secrets_management do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:mutation_name) { :instance_secrets_manager_unenroll }

  let(:mutation) { graphql_mutation(mutation_name, {}) }
  let(:mutation_response) { graphql_mutation_response(mutation_name) }

  subject(:post_mutation) { post_graphql_mutation(mutation, current_user: current_user) }

  before do
    allow(::License).to receive(:feature_available?).and_call_original
    allow(::License).to receive(:feature_available?).with(:native_secrets_management).and_return(true)
  end

  context 'when on GitLab.com', :saas do
    let_it_be(:current_user) { create(:admin) }

    it 'returns a resource not available error' do
      post_mutation

      expect_graphql_errors_to_include("you don't have permission")
    end
  end

  context 'when not on GitLab.com' do
    context 'when license is not available' do
      let_it_be(:current_user) { create(:admin) }

      before do
        allow(::License).to receive(:feature_available?).with(:native_secrets_management).and_return(false)
      end

      it 'returns a resource not available error' do
        post_mutation

        expect_graphql_errors_to_include("you don't have permission")
      end
    end

    context 'when enrollment feature flag is disabled' do
      let_it_be(:current_user) { create(:admin) }

      before do
        stub_feature_flags(secrets_manager_instance_enrollment: false)
      end

      it 'returns a resource not available error' do
        post_mutation

        expect_graphql_errors_to_include("you don't have permission")
      end
    end

    context 'when current user is not an admin' do
      it 'returns a resource not available error' do
        post_mutation

        expect_graphql_errors_to_include("you don't have permission")
      end
    end

    context 'when current user is an admin' do
      let_it_be(:current_user) { create(:admin) }

      before do
        Gitlab::CurrentSettings.update!(secrets_manager_instance_enrolled: true)
      end

      it 'disables instance enrollment', :aggregate_failures do
        post_mutation

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['errors']).to be_empty
        expect(Gitlab::CurrentSettings.secrets_manager_instance_enrolled).to be false
      end

      it 'triggers an internal event' do
        expect { post_mutation }
          .to trigger_internal_events('unenroll_secrets_manager_for_instance').with(
            category: 'Mutations::SecretsManagement::Enrollment::InstanceUnenroll',
            user: current_user
          )
      end

      context 'when the instance is not enrolled' do
        before do
          Gitlab::CurrentSettings.update!(secrets_manager_instance_enrolled: false)
        end

        it 'does not trigger an internal event' do
          expect { post_mutation }.not_to trigger_internal_events('unenroll_secrets_manager_for_instance')
        end
      end

      context 'when service results in a failure' do
        before do
          allow_next_instance_of(SecretsManagement::InstanceEnrollmentService) do |service|
            allow(service).to receive(:unenroll)
              .and_return(ServiceResponse.error(message: 'some error'))
          end
        end

        it 'returns the service error', :aggregate_failures do
          post_mutation

          expect(mutation_response['errors']).to include('some error')
        end
      end
    end
  end
end
