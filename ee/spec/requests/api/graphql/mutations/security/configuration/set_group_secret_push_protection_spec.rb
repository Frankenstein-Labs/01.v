# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Setting Group Secret Push Protection', feature_category: :security_testing_configuration do
  include GraphqlHelpers

  let(:mutation_name) { 'SetGroupSecretPushProtection' }
  let_it_be_with_reload(:namespace) { create(:group) }
  let_it_be_with_reload(:current_user) { create(:user) }
  let(:enable) { true }
  let(:mutation_params) do
    {
      namespace_path: namespace.full_path,
      secret_push_protection_enabled: enable
    }
  end

  let(:mutation) do
    graphql_mutation(
      mutation_name,
      **mutation_params
    )
  end

  describe 'projects of a group by toggling secret push protection' do
    context 'with group' do
      before do
        allow(::Security::Configuration::SetGroupSecretPushProtectionWorker).to receive(:perform_async)
        stub_licensed_features(secret_push_protection: true)
      end

      # user is not a member of the group at all, so they're got an unauthorized error
      context 'when user is not a member of the group' do
        it_behaves_like 'a mutation that returns a top-level access error'

        it 'does not call the worker' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(::Security::Configuration::SetGroupSecretPushProtectionWorker)
            .not_to have_received(:perform_async)
        end
      end

      # user is a member of the group
      context 'when user is a member of the group' do
        context 'when user has proper permissions' do
          let_it_be(:maintainer) { create(:user, maintainer_of: namespace) }
          let_it_be(:current_user) { maintainer }

          it 'returns success response' do
            post_graphql_mutation(mutation, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(graphql_mutation_response(mutation_name)).to include(
              'clientMutationId' => nil,
              'errors' => []
            )
          end

          it 'calls the worker with the correct parameters' do
            post_graphql_mutation(mutation, current_user: current_user)

            expect(::Security::Configuration::SetGroupSecretPushProtectionWorker)
              .to have_received(:perform_async)
              .with(namespace.id, true, current_user.id, [])
          end

          context 'when disabling the setting' do
            let(:enable) { false }

            it 'calls the worker with disable parameter' do
              post_graphql_mutation(mutation, current_user: current_user)

              expect(::Security::Configuration::SetGroupSecretPushProtectionWorker)
                .to have_received(:perform_async)
                .with(namespace.id, false, current_user.id, [])
            end
          end

          context 'with excluded projects' do
            let_it_be(:project1) { create(:project, namespace: namespace) }
            let_it_be(:project2) { create(:project, namespace: namespace) }
            let(:mutation_params) do
              super().merge(projects_to_exclude: [project1.id, project2.id])
            end

            let(:projects_to_exclude) { [project1.id, project2.id] }

            it 'calls the worker with excluded projects' do
              post_graphql_mutation(mutation, current_user: current_user)

              expect(::Security::Configuration::SetGroupSecretPushProtectionWorker)
                .to have_received(:perform_async)
                .with(namespace.id, true, current_user.id, projects_to_exclude)
            end
          end
        end

        context 'when user lacks permissions' do
          let_it_be(:developer) { create(:user, developer_of: namespace) }
          let_it_be(:current_user) { developer }

          it_behaves_like 'a mutation that returns a top-level access error'

          it 'does not call the worker' do
            post_graphql_mutation(mutation, current_user: current_user)

            expect(::Security::Configuration::SetGroupSecretPushProtectionWorker)
              .not_to have_received(:perform_async)
          end
        end

        context 'when the namespace is not a group' do
          let_it_be_with_reload(:namespace) { create(:namespace) }
          let_it_be_with_reload(:current_user) { create(:user, namespace: namespace) }

          it_behaves_like 'a mutation that returns a top-level access error'
        end
      end
    end
  end
end
