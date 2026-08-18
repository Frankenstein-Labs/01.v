# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/MultipleMemoizedHelpers -- Need helpers for testing multiple scenarios
RSpec.describe Groups::Security::CredentialsController, :saas, feature_category: :user_management do
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:subgroup) { create(:group, :private, parent: group) }
  let_it_be(:project) { create(:project, :private, group: subgroup) }

  let_it_be(:enterprise_user1) { create(:enterprise_user, enterprise_group: group) }
  let_it_be(:enterprise_user2) { create(:enterprise_user, enterprise_group: group) }
  let_it_be(:group_enterprise_users) { [enterprise_user1, enterprise_user2] }

  let_it_be(:service_account1) { create(:service_account, provisioned_by_group: group) }
  let_it_be(:service_account2) { create(:service_account, provisioned_by_group: group) }
  let_it_be(:group_service_accounts) { [service_account1, service_account2] }

  let_it_be(:owner) { enterprise_user1 }
  let_it_be(:maintainer) { enterprise_user2 }

  let_it_be(:group_id) { group.to_param }

  let_it_be(:enterprise_user1_personal_access_token) do
    create(:personal_access_token, user: enterprise_user1, group: group)
  end

  let_it_be(:enterprise_user2_personal_access_token) do
    create(:personal_access_token, user: enterprise_user2, group: group)
  end

  let_it_be(:enterprise_user2_revoked_personal_access_token) do
    create(:personal_access_token, revoked: true, user: enterprise_user2, group: group)
  end

  let_it_be(:enterprise_user2_expired_personal_access_token) do
    create(:personal_access_token, expires_at: 5.days.ago, user: enterprise_user2, group: group)
  end

  let_it_be(:service_account1_personal_access_token) do
    create(:personal_access_token, user: service_account1, group: group)
  end

  let_it_be(:service_account2_personal_access_token) do
    create(:personal_access_token, user: service_account2, group: group)
  end

  let_it_be(:another_group) { create(:group) }
  let_it_be(:enterprise_user_of_another_group) { create(:enterprise_user, enterprise_group: another_group) }
  let_it_be(:service_account_of_another_group) { create(:service_account, provisioned_by_group: another_group) }

  let_it_be(:enterprise_user_of_another_group_personal_access_token) do
    create(:personal_access_token, user: enterprise_user_of_another_group, group: another_group)
  end

  let_it_be(:service_account_of_another_group_personal_access_token) do
    create(:personal_access_token, user: service_account_of_another_group, group: another_group)
  end

  let_it_be(:token_that_does_not_belong_to_any_group) do
    create(:personal_access_token)
  end

  let_it_be(:resource_access_token_that_belong_to_the_group1) do
    create(:resource_access_token, resource: group, group: group, scopes: [:api])
  end

  let_it_be(:resource_access_token_that_belong_to_the_group2) do
    create(:resource_access_token, resource: subgroup, group: group, scopes: [:api])
  end

  let_it_be(:resource_access_token_that_belong_to_the_group3) do
    create(:resource_access_token, resource: project, group: group, scopes: [:api])
  end

  let_it_be(:resource_access_token_that_belongs_to_another_group) do
    create(:resource_access_token, resource: another_group, group: another_group, scopes: [:api])
  end

  let_it_be(:resource_access_token_that_does_not_belong_to_any_group) do
    create(:resource_access_token, scopes: [:api])
  end

  before do
    group.add_owner(owner)
    group.add_maintainer(maintainer)

    login_as(owner)
  end

  describe 'GET #index' do
    let(:filter) { nil }
    let(:owner_type) { nil }

    subject(:get_request) { get group_security_credentials_path(group_id: group_id, filter: filter, owner_type: owner_type) }

    context 'when `credentials_inventory` feature is licensed' do
      before do
        stub_licensed_features(credentials_inventory: true)
      end

      context 'for a user with access to view credentials inventory' do
        it_behaves_like 'internal event tracking' do
          let(:event) { 'visit_authentication_credentials_inventory' }
          let(:user) { owner }
          let(:project) { nil }
          let(:namespace) { group }

          subject(:group_security_credentials_request) { get_request }
        end

        it 'responds with 200' do
          get_request

          expect(response).to have_gitlab_http_status(:ok)
        end

        context 'filtering by type of credential' do
          context 'no credential type specified' do
            let(:filter) { nil }

            it 'returns all personal access tokens' do
              get_request

              expected_tokens = PersonalAccessToken.where(user: group_enterprise_users + group_service_accounts)
              expect(assigns(:credentials)).to match_array(expected_tokens)
            end
          end

          context 'non-existent credential type specified' do
            let(:filter) { 'non_existent_credential_type' }

            it 'returns all personal access tokens' do
              get_request

              expected_tokens = PersonalAccessToken.where(user: group_enterprise_users + group_service_accounts)
              expect(assigns(:credentials)).to match_array(expected_tokens)
            end
          end

          context 'credential type specified as `personal_access_tokens`' do
            let(:filter) { 'personal_access_tokens' }

            it 'returns all personal access tokens' do
              get_request

              expected_tokens = PersonalAccessToken.where(user: group_enterprise_users + group_service_accounts)
              expect(assigns(:credentials)).to match_array(expected_tokens)
            end
          end

          context 'credential type specified as `ssh_keys`' do
            let(:filter) { 'ssh_keys' }

            before do
              group_enterprise_users.each do |user|
                create(:personal_key, user: user)
              end
              group_service_accounts.each do |user|
                create(:personal_key, user: user)
              end
            end

            it 'filters by ssh keys' do
              get_request

              expect(assigns(:credentials)).to match_array(Key.regular_keys.where(user: group_enterprise_users + group_service_accounts))
            end
          end

          context 'credential type specified as `resource access tokens`' do
            let(:filter) { 'resource_access_tokens' }

            it 'returns all resource access tokens that belong to the hierarchy of the group' do
              get_request

              expected_tokens = PersonalAccessToken.where(user_type: :project_bot, group: group)
              expect(assigns(:credentials)).to match_array(expected_tokens)
            end
          end
        end

        context 'filtering by owner type' do
          context 'when owner_type is human' do
            let(:filter) { 'personal_access_tokens' }
            let(:owner_type) { 'human' }

            it 'returns only human user tokens' do
              get_request

              expected_tokens = PersonalAccessToken.where(user: group_enterprise_users)
              expect(assigns(:credentials)).to match_array(expected_tokens)
            end
          end

          context 'when owner_type is service_account' do
            let(:filter) { 'personal_access_tokens' }
            let(:owner_type) { 'service_account' }

            it 'returns only service account tokens' do
              get_request

              expected_tokens = PersonalAccessToken.where(user: group_service_accounts)
              expect(assigns(:credentials)).to match_array(expected_tokens)
            end
          end

          context 'when owner_type is not specified' do
            let(:filter) { 'personal_access_tokens' }
            let(:owner_type) { nil }

            it 'returns all tokens regardless of owner type' do
              get_request

              expected_tokens = PersonalAccessToken.where(user: group_enterprise_users + group_service_accounts)
              expect(assigns(:credentials)).to match_array(expected_tokens)
            end
          end
        end

        context 'for a user without access to view credentials inventory' do
          before do
            sign_in(maintainer)
          end

          it 'responds with 404' do
            get_request

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end
      end
    end

    context 'when `credentials_inventory` feature is unlicensed' do
      before do
        stub_licensed_features(credentials_inventory: false)
      end

      it 'returns 404' do
        get_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'DELETE #destroy' do
    let(:credentials_path) { group_security_credentials_path(filter: 'ssh_keys') }

    it_behaves_like 'credentials inventory delete SSH key', group_credentials_inventory: true
  end

  describe 'PUT #revoke' do
    it_behaves_like 'credentials inventory revoke project & group access tokens', group_credentials_inventory: true

    shared_examples_for 'responds with 404' do
      it do
        put revoke_group_security_credential_path(group_id: group_id, id: token_id)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    shared_examples_for 'displays the flash success message' do
      it do
        put revoke_group_security_credential_path(group_id: group_id, id: token_id)

        expect(response).to redirect_to(group_security_credentials_path)
        expect(flash[:notice]).to start_with 'Revoked personal access token '
      end
    end

    shared_examples_for 'displays the flash error message' do
      it do
        put revoke_group_security_credential_path(group_id: group_id, id: token_id)

        expect(response).to redirect_to(group_security_credentials_path)
        expect(flash[:alert]).to eql 'Not permitted to revoke'
      end
    end

    context 'when `credentials_inventory` feature is enabled', :saas do
      before do
        stub_licensed_features(credentials_inventory: true, domain_verification: true)
      end

      context 'for a group with enterprise users' do
        context 'for a user with access to view credentials inventory' do
          context 'non-existent personal access token specified' do
            let(:token_id) { 999999999999999999999999999999999 }

            it_behaves_like 'responds with 404'
          end

          describe 'with an existing personal access token' do
            context 'personal access token is already revoked' do
              let_it_be(:token_id) { enterprise_user2_revoked_personal_access_token.id }

              it_behaves_like 'displays the flash success message'
            end

            context 'personal access token is already expired' do
              let_it_be(:token_id) { enterprise_user2_expired_personal_access_token.id }

              it_behaves_like 'displays the flash success message'
            end

            context 'does not have permissions to revoke the credential' do
              let_it_be(:token_id) { enterprise_user_of_another_group_personal_access_token.id }

              it_behaves_like 'responds with 404'
            end

            context 'personal access token is not revoked or expired' do
              let_it_be(:token_id) { enterprise_user2_personal_access_token.id }

              it_behaves_like 'displays the flash success message'

              it 'informs the token owner' do
                expect(CredentialsInventoryMailer).to receive_message_chain(:personal_access_token_revoked_email, :deliver_later)

                put revoke_group_security_credential_path(group_id: group_id, id: token_id)
              end
            end

            context 'service account personal access token' do
              let_it_be(:token_id) { service_account2_personal_access_token.id }

              it_behaves_like 'displays the flash success message'

              it 'can revoke service account tokens' do
                expect { put revoke_group_security_credential_path(group_id: group_id, id: token_id) }
                  .to change { service_account2_personal_access_token.reload.revoked? }.from(false).to(true)
              end
            end
          end
        end

        context 'for a user without access to view credentials inventory' do
          let_it_be(:token_id) { enterprise_user2_personal_access_token.id }

          before do
            sign_in(maintainer)
          end

          it_behaves_like 'responds with 404'
        end

        context 'for a token that does not belong to any group' do
          let_it_be(:token_id) { token_that_does_not_belong_to_any_group.id }

          it_behaves_like 'responds with 404'
        end
      end
    end

    context 'when `credentials_inventory` feature is disabled' do
      let_it_be(:token_id) { enterprise_user2_personal_access_token.id }

      before do
        stub_licensed_features(credentials_inventory: false)
      end

      it_behaves_like 'responds with 404'
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
