# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::CredentialsController, feature_category: :user_management do
  include AdminModeHelper

  let_it_be(:admin) { create(:admin) }
  let_it_be(:user) { create(:user) }
  let_it_be(:service_accounts) { create_list(:service_account, 2) }
  let_it_be(:personal_access_token) { create(:personal_access_token, user: user) }
  let_it_be(:service_account_token) { create(:personal_access_token, user: service_accounts.first) }
  let_it_be(:project) { create(:project, :in_group) }
  let_it_be(:group) { project.group }
  let_it_be(:project_bot) { create(:user, :project_bot, created_by_id: user.id) }
  let_it_be(:group_bot) { create(:user, :project_bot, created_by_id: user.id) }
  let_it_be(:project_member) { create(:project_member, source: project, user: project_bot) }
  let_it_be(:group_member) { create(:group_member, source: group, user: group_bot) }
  let_it_be(:project_access_token) { create(:personal_access_token, user: project_bot) }
  let_it_be(:group_access_token) { create(:personal_access_token, user: group_bot) }

  describe 'GET #index' do
    context 'as an admin user' do
      before_all do
        group.add_maintainer(group_bot)
      end

      before do
        login_as(admin)
        enable_admin_mode!(admin)
      end

      context 'when `credentials_inventory` feature is enabled' do
        before do
          stub_licensed_features(credentials_inventory: true)
        end

        it 'responds with 200' do
          get admin_credentials_path

          expect(response).to have_gitlab_http_status(:ok)
        end

        it_behaves_like 'migrated internal event' do
          subject(:admin_credentials_request) { get admin_credentials_path }

          let(:event) { 'visit_compliance_credential_inventory' }
          let(:user) { admin }
          let(:project) { nil }
          let(:namespace) { nil }
          let(:migrated_metrics) do
            [
              'redis_hll_counters.compliance.i_compliance_credential_inventory_monthly',
              'redis_hll_counters.compliance.i_compliance_credential_inventory_weekly'
            ]
          end

          let(:previous_event_name) { 'i_compliance_credential_inventory' }
          let(:previous_event_value) { user.id }
        end

        describe 'filtering by type of credential' do
          let_it_be(:personal_access_tokens) { create_list(:personal_access_token, 2, user: user) }
          let(:filter) { nil }
          let(:owner_type) { nil }

          subject(:get_request) { get admin_credentials_path(filter: filter, owner_type: owner_type) }

          before do
            # Create additional tokens for testing
            service_accounts.each do |sa|
              create(:personal_access_token, user: sa)
            end
          end

          context 'when no credential type is specified' do
            let(:filter) { nil }

            it 'returns all personal access tokens' do
              get_request

              expected_tokens = PersonalAccessToken.where.not(user: User.project_bot)
              expect(assigns(:credentials)).to match_array(expected_tokens)
            end
          end

          context 'when a non-existent credential type is specified' do
            let(:filter) { 'non_existent_credential_type' }

            it 'returns all personal access tokens' do
              get_request

              expected_tokens = PersonalAccessToken.where.not(user: User.project_bot)
              expect(assigns(:credentials)).to match_array(expected_tokens)
            end
          end

          context 'when credential type is `personal_access_tokens`' do
            let(:filter) { 'personal_access_tokens' }

            it 'returns all personal access tokens' do
              get_request

              expected_tokens = PersonalAccessToken.where.not(user: User.project_bot)
              expect(assigns(:credentials)).to match_array(expected_tokens)
            end
          end

          context 'when filtering by owner type' do
            context 'when owner_type is human' do
              let(:filter) { 'personal_access_tokens' }
              let(:owner_type) { 'human' }

              it 'returns only human user tokens' do
                get_request

                expected_tokens = PersonalAccessToken.where(user: User.human)
                expect(assigns(:credentials)).to match_array(expected_tokens)
              end
            end

            context 'when owner_type is service_account' do
              let(:filter) { 'personal_access_tokens' }
              let(:owner_type) { 'service_account' }

              it 'returns only service account tokens' do
                get_request

                expected_tokens = PersonalAccessToken.where(user: User.service_account)
                expect(assigns(:credentials)).to match_array(expected_tokens)
              end
            end

            context 'when owner_type is not specified' do
              let(:filter) { 'personal_access_tokens' }
              let(:owner_type) { nil }

              it 'returns all tokens regardless of owner type' do
                get_request

                expected_tokens = PersonalAccessToken.where.not(user: User.project_bot)
                expect(assigns(:credentials)).to match_array(expected_tokens)
              end
            end
          end

          context 'when credential type is `ssh_keys`' do
            let(:filter) { 'ssh_keys' }

            it 'filters by ssh keys' do
              create_list(:personal_key, 2, user: user)

              get_request

              expect(assigns(:credentials)).to match_array(Key.regular_keys.where(user: [user]))
            end
          end

          context 'when credential type is `resource_access_tokens`' do
            let(:filter) { 'resource_access_tokens' }

            it 'filters by project and group access tokens' do
              get_request

              expect(assigns(:credentials)).to match_array(
                [project_access_token, group_access_token]
              )
            end
          end

          context 'when credential type is `gpg_keys`' do
            let(:filter) { 'gpg_keys' }

            it 'filters by gpg keys' do
              gpg_key = create(:gpg_key)

              get_request

              expect(assigns(:credentials)).to match_array([gpg_key])
            end

            # There is currently N+1 issue when checking verified_emails per user:
            # https://gitlab.com/gitlab-org/gitlab/-/issues/322773
            # Therefore we are currently adding + 1 to the control until this is resolved
            it 'avoids N+1 queries' do
              control_user = create(:user, name: 'User Name', email: GpgHelpers::User1.emails.first)
              new_user = create(:user, name: 'User Name', email: GpgHelpers::User2.emails.first)

              create(:gpg_key, user: control_user, key: GpgHelpers::User1.public_key)
              create(:gpg_key, user: control_user, key: GpgHelpers::User1.public_key2)

              get admin_credentials_path(filter: 'gpg_keys')

              control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
                get admin_credentials_path(filter: 'gpg_keys')
              end

              create(:gpg_key, user: new_user, key: GpgHelpers::User2.public_key)

              expect do
                get admin_credentials_path(filter: 'gpg_keys')
              end.not_to exceed_query_limit(control).allow_skip_cache_inconsistency.with_threshold(1)
            end
          end

          context 'with user scope' do
            it 'includes service account tokens in the scope' do
              get_request

              expect(assigns(:credentials)).to include(service_account_token)
            end
          end
        end
      end

      context 'when `credentials_inventory` feature is disabled' do
        before do
          stub_licensed_features(credentials_inventory: false)
        end

        it 'returns 404' do
          get admin_credentials_path

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'as a non-admin user' do
      before do
        login_as(user)
      end

      it 'returns 404' do
        get admin_credentials_path

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'DELETE #destroy' do
    let(:credentials_path) { admin_credentials_path(filter: 'ssh_keys') }

    it_behaves_like 'credentials inventory delete SSH key'
  end

  describe 'PUT #revoke' do
    it_behaves_like 'credentials inventory revoke project & group access tokens'

    shared_examples_for 'responds with 404' do
      it 'returns 404 for revoke path' do
        put revoke_admin_credential_path(id: token_id)

        expect(response).to have_gitlab_http_status(:not_found)
      end

      it 'returns 404 for resource revoke path with project' do
        put admin_credential_resource_revoke_path(credential_id: token_id, resource_id: project.id,
          resource_type: 'Project')

        expect(response).to have_gitlab_http_status(:not_found)
      end

      it 'returns 404 for resource revoke path with invalid type' do
        put admin_credential_resource_revoke_path(credential_id: project_access_token.id, resource_id: project.id,
          resource_type: 'InvalidType')

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    shared_examples_for 'displays the flash success message' do
      it 'redirects with success notice for revoke path' do
        put revoke_admin_credential_path(id: token_id)

        expect(response).to redirect_to(admin_credentials_path)
        expect(flash[:notice]).to start_with 'Revoked personal access token '
      end

      it :aggregate_failures do
        put admin_credential_resource_revoke_path(credential_id: project_access_token.id, resource_id: project.id,
          resource_type: 'Project')

        expect(response).to redirect_to(admin_credentials_path)
        expect(flash[:notice]).to eq "Access token #{project_access_token.name} has been revoked."
      end

      it :aggregate_failures do
        put admin_credential_resource_revoke_path(credential_id: group_access_token.id, resource_id: group.id,
          resource_type: 'Group')

        expect(response).to redirect_to(admin_credentials_path)
        expect(flash[:notice]).to eq "Access token #{group_access_token.name} has been revoked."
      end
    end

    shared_examples_for 'displays the flash error message' do
      it 'redirects with error alert' do
        put revoke_admin_credential_path(id: token_id)

        expect(response).to redirect_to(admin_credentials_path)
        expect(flash[:alert]).to eql 'Not permitted to revoke'
      end
    end

    context 'as an admin user' do
      before do
        login_as(admin)
        enable_admin_mode!(admin)
      end

      context 'when `credentials_inventory` feature is enabled' do
        before do
          stub_licensed_features(credentials_inventory: true)
        end

        context 'when a non-existent personal access token is specified' do
          let(:token_id) { 999999999999999999999999999999999 }

          it_behaves_like 'responds with 404'
        end

        describe 'with an existing personal access token' do
          context 'when admin does not have permissions to revoke the credential' do
            before do
              allow(Ability).to receive(:allowed?).and_call_original
              allow(Ability).to receive(:allowed?).with(admin, :log_in, :global).and_return(true)
              allow(Ability).to receive(:allowed?).with(admin, :revoke_personal_access_token,
                personal_access_token).and_return(false)
            end

            let(:token_id) { personal_access_token.id }

            it_behaves_like 'displays the flash error message'
          end

          context 'when personal access token is already revoked' do
            let_it_be(:token_id) { create(:personal_access_token, revoked: true, user: user).id }

            it_behaves_like 'displays the flash success message'
          end

          context 'when personal access token is already expired' do
            let_it_be(:token_id) { create(:personal_access_token, expires_at: 5.days.ago, user: user).id }

            it_behaves_like 'displays the flash success message'
          end

          context 'when personal access token is not revoked or expired' do
            let(:token_id) { personal_access_token.id }

            it_behaves_like 'displays the flash success message'

            it 'informs the token owner' do
              expect(CredentialsInventoryMailer).to receive_message_chain(:personal_access_token_revoked_email,
                :deliver_later)

              put revoke_admin_credential_path(id: personal_access_token.id)
            end
          end

          context 'with a service account personal access token' do
            let_it_be(:token_id) { service_account_token.id }

            it_behaves_like 'displays the flash success message'

            it 'can revoke service account tokens' do
              expect { put revoke_admin_credential_path(id: service_account_token.id) }
                .to change { service_account_token.reload.revoked? }.from(false).to(true)
            end
          end
        end
      end

      context 'when `credentials_inventory` feature is disabled' do
        before do
          stub_licensed_features(credentials_inventory: false)
        end

        let(:token_id) { personal_access_token.id }

        it_behaves_like 'responds with 404'
      end
    end

    context 'as a non-admin user' do
      before do
        login_as(user)
      end

      let(:token_id) { personal_access_token.id }

      it_behaves_like 'responds with 404'
    end
  end
end

RSpec.describe Admin::CredentialsController, type: :controller, feature_category: :user_management do
  include AdminModeHelper

  let_it_be(:admin) { create(:admin) }

  before do
    stub_licensed_features(credentials_inventory: true)
    sign_in(admin)
    enable_admin_mode!(admin)
  end

  it_behaves_like 'tracking unique visits', :index do
    let(:target_id) { 'i_compliance_credential_inventory' }
  end
end
