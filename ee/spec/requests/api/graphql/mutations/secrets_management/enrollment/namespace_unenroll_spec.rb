# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Unenroll a namespace from secrets manager', feature_category: :secrets_management do
  include GraphqlHelpers

  let_it_be_with_reload(:group) { create(:group) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:mutation_name) { :namespace_secrets_manager_unenroll }

  let(:mutation) { graphql_mutation(mutation_name, namespace_path: group.full_path) }
  let(:mutation_response) { graphql_mutation_response(mutation_name) }

  subject(:post_mutation) { post_graphql_mutation(mutation, current_user: current_user) }

  before do
    stub_licensed_features(native_secrets_management: true)
  end

  context 'when not on GitLab.com' do
    before_all do
      group.add_owner(current_user)
    end

    it 'returns a resource not available error' do
      post_mutation

      expect_graphql_errors_to_include("you don't have permission")
    end
  end

  context 'when on GitLab.com', :saas do
    context 'when current user is not part of the group' do
      it_behaves_like 'a mutation on an unauthorized resource'
    end

    context 'when current user is not the group owner' do
      before_all do
        group.add_maintainer(current_user)
      end

      it_behaves_like 'a mutation on an unauthorized resource'
    end

    context 'when current user is the group owner' do
      before_all do
        group.add_owner(current_user)
      end

      context 'when namespace is enrolled' do
        before do
          create(:secrets_manager_namespace_enrollment, namespace: group)
        end

        it 'unenrolls the namespace', :aggregate_failures do
          post_mutation

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_response['errors']).to be_empty
          expect(SecretsManagement::NamespaceEnrollment.enrolled?(group)).to be false
        end

        it 'triggers an internal event' do
          expect { post_mutation }
            .to trigger_internal_events('unenroll_secrets_manager_for_namespace').with(
              category: 'Mutations::SecretsManagement::Enrollment::NamespaceUnenroll',
              user: current_user,
              namespace: group
            )
        end
      end

      context 'when namespace is not enrolled' do
        it 'returns an error', :aggregate_failures do
          post_mutation

          expect(mutation_response['errors']).to include('Enrollment not found.')
        end

        it 'does not trigger an internal event' do
          expect { post_mutation }.not_to trigger_internal_events('unenroll_secrets_manager_for_namespace')
        end
      end

      context 'when service results in a failure' do
        before do
          allow_next_instance_of(SecretsManagement::NamespaceEnrollmentService) do |service|
            allow(service).to receive(:unenroll)
              .and_return(ServiceResponse.error(message: 'some error'))
          end
        end

        it 'returns the service error', :aggregate_failures do
          post_mutation

          expect(mutation_response['errors']).to include('some error')
        end
      end

      context 'when the namespace enrollment feature flag is disabled' do
        before do
          stub_feature_flags(secrets_manager_namespace_enrollment: false)
        end

        it_behaves_like 'a mutation on an unauthorized resource'
      end

      context 'when license is not available' do
        before do
          stub_licensed_features(native_secrets_management: false)
        end

        it_behaves_like 'a mutation on an unauthorized resource'
      end
    end
  end
end
