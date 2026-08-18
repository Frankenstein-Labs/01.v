# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::GroupEnterpriseUsers, :aggregate_failures, feature_category: :user_management do
  let_it_be(:enterprise_group) { create(:group) }
  let_it_be(:saml_provider) { create(:saml_provider, group: enterprise_group) }

  let_it_be(:subgroup) { create(:group, parent: enterprise_group) }

  let_it_be(:developer_of_enterprise_group) { create(:user, developer_of: enterprise_group) }
  let_it_be(:maintainer_of_enterprise_group) { create(:user, maintainer_of: enterprise_group) }
  let_it_be(:owner_of_enterprise_group) { create(:user, owner_of: enterprise_group) }
  let_it_be(:auditor_user) { create(:auditor) }

  let_it_be(:non_enterprise_user) { create(:user) }
  let_it_be(:enterprise_user_of_another_group) { create(:enterprise_user) }

  let_it_be_with_reload(:enterprise_user_of_the_group) do
    create(:enterprise_user, :with_namespace, enterprise_group: enterprise_group).tap do |user|
      create(:group_saml_identity, user: user, saml_provider: saml_provider)
      create(:scim_identity, user: user, group: enterprise_group)
    end
  end

  let_it_be(:blocked_enterprise_user_of_the_group) do
    create(:enterprise_user, :blocked, :with_namespace, enterprise_group: enterprise_group)
  end

  let_it_be(:enterprise_user_and_member_of_the_group) do
    create(:enterprise_user, :with_namespace, enterprise_group: enterprise_group, developer_of: enterprise_group)
  end

  let(:current_user) { owner_of_enterprise_group }
  let(:group_id) { enterprise_group.id }
  let(:user_id) { enterprise_user_of_the_group.id }
  let(:params) { {} }

  shared_examples 'authentication and authorization requirements' do |allow_auditor: false|
    context 'when current_user is nil' do
      let(:current_user) { nil }

      it 'returns 401 Unauthorized' do
        subject

        expect(response).to have_gitlab_http_status(:unauthorized)
        expect(json_response['message']).to eq('401 Unauthorized')
      end
    end

    context 'when group is not found' do
      let(:group_id) { -42 }

      it 'returns 404 Group Not Found' do
        subject

        expect(response).to have_gitlab_http_status(:not_found)
        expect(json_response['message']).to eq('404 Group Not Found')
      end
    end

    context 'when group is not top-level group' do
      let(:group_id) { subgroup.id }

      it 'returns 400 Bad Request with message' do
        subject

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['message']).to eq('400 Bad request - Must be a top-level group')
      end
    end

    context 'when current_user is not owner of the group' do
      let(:current_user) { maintainer_of_enterprise_group }

      it 'returns 403 Forbidden' do
        subject

        expect(response).to have_gitlab_http_status(:forbidden)
        expect(json_response['message']).to eq('403 Forbidden')
      end
    end

    context 'when current_user is an instance auditor' do
      let(:current_user) { auditor_user }

      if allow_auditor
        it 'returns 200 OK' do
          subject

          expect(response).to have_gitlab_http_status(:ok)
        end
      else
        it 'returns 403 Forbidden' do
          subject

          expect(response).to have_gitlab_http_status(:forbidden)
          expect(json_response['message']).to eq('403 Forbidden')
        end
      end
    end
  end

  describe 'GET /groups/:id/enterprise_users' do
    subject(:get_group_enterprise_users) do
      get api("/groups/#{group_id}/enterprise_users", current_user), params: params
    end

    include_examples 'authentication and authorization requirements', allow_auditor: true

    it_behaves_like 'internal event tracking' do
      let(:event) { 'use_get_group_enterprise_users_api' }
      let(:user) { current_user }
      let(:namespace) { enterprise_group }

      subject(:track_event) { get_group_enterprise_users }
    end

    it 'returns enterprise users of the group in descending order by id' do
      get_group_enterprise_users

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response.pluck('id')).to eq(
        [
          enterprise_user_of_the_group,
          blocked_enterprise_user_of_the_group,
          enterprise_user_and_member_of_the_group
        ].sort_by(&:id).reverse.pluck(:id)
      )
    end

    it_behaves_like 'authorizing granular token permissions', :read_enterprise_user do
      let(:boundary_object) { enterprise_group }
      let(:user) { owner_of_enterprise_group }
      let(:request) { get api("/groups/#{group_id}/enterprise_users", personal_access_token: pat), params: params }
    end

    context 'for pagination parameters' do
      let(:params) { { page: 1, per_page: 2 } }

      it 'returns enterprise users according to page and per_page parameters' do
        get_group_enterprise_users

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.pluck('id')).to eq(
          [
            enterprise_user_of_the_group,
            blocked_enterprise_user_of_the_group,
            enterprise_user_and_member_of_the_group
          ].sort_by(&:id).reverse.slice(0, 2).pluck(:id)
        )
      end
    end

    context 'for username parameter' do
      let(:params) { { username: enterprise_user_of_the_group.username } }

      it 'returns single enterprise user with a specific username' do
        get_group_enterprise_users

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.count).to eq(1)
        expect(json_response.first['id']).to eq(enterprise_user_of_the_group.id)
      end
    end

    context 'for search parameter' do
      context 'for search by name' do
        let(:params) { { search: enterprise_user_of_the_group.name } }

        it 'returns enterprise users of the group according to the search parameter' do
          get_group_enterprise_users

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.count).to eq(1)
          expect(json_response.first['id']).to eq(enterprise_user_of_the_group.id)
        end
      end

      context 'for search by username' do
        let(:params) { { search: blocked_enterprise_user_of_the_group.username } }

        it 'returns enterprise users of the group according to the search parameter' do
          get_group_enterprise_users

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.count).to eq(1)
          expect(json_response.first['id']).to eq(blocked_enterprise_user_of_the_group.id)
        end
      end

      context 'for search by public email' do
        let_it_be(:enterprise_user_of_the_group_with_public_email) do
          create(:enterprise_user, :public_email, :with_namespace, enterprise_group: enterprise_group)
        end

        let(:params) do
          { search: enterprise_user_of_the_group_with_public_email.public_email }
        end

        it 'returns enterprise users of the group according to the search parameter' do
          expect(enterprise_user_of_the_group_with_public_email.public_email).to be_present

          get_group_enterprise_users

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.count).to eq(1)
          expect(json_response.first['id']).to eq(enterprise_user_of_the_group_with_public_email.id)
        end
      end

      context 'for search by private email' do
        let_it_be(:enterprise_user_of_the_group_without_public_email) do
          create(:enterprise_user, :with_namespace, enterprise_group: enterprise_group)
        end

        let(:params) do
          { search: enterprise_user_of_the_group_without_public_email.email }
        end

        it 'returns enterprise users of the group according to the search parameter' do
          expect(enterprise_user_of_the_group_without_public_email.public_email).not_to be_present

          get_group_enterprise_users

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.count).to eq(1)
          expect(json_response.first['id']).to eq(enterprise_user_of_the_group_without_public_email.id)
        end
      end
    end

    context 'for active parameter' do
      let(:params) { { active: true } }

      it 'returns only active enterprise users' do
        get_group_enterprise_users

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.pluck('id')).to eq(
          [
            enterprise_user_of_the_group,
            enterprise_user_and_member_of_the_group
          ].sort_by(&:id).reverse.pluck(:id)
        )
      end
    end

    context 'for blocked parameter' do
      let(:params) { { blocked: true } }

      it 'returns only blocked enterprise users' do
        get_group_enterprise_users

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.pluck('id')).to eq(
          [
            blocked_enterprise_user_of_the_group
          ].sort_by(&:id).reverse.pluck(:id)
        )
      end
    end

    context 'for created_after parameter' do
      let(:params) { { created_after: 10.days.ago } }

      let_it_be(:enterprise_user_of_the_group_created_12_days_ago) do
        create(:enterprise_user, :with_namespace, enterprise_group: enterprise_group).tap do |user|
          user.update_column(:created_at, 12.days.ago)
        end
      end

      let_it_be(:enterprise_user_of_the_group_created_8_days_ago) do
        create(:enterprise_user, :with_namespace, enterprise_group: enterprise_group).tap do |user|
          user.update_column(:created_at, 8.days.ago)
        end
      end

      it 'returns only enterprise users created after the specified time', :freeze_time do
        get_group_enterprise_users

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.pluck('id')).to eq(
          [
            enterprise_user_of_the_group,
            blocked_enterprise_user_of_the_group,
            enterprise_user_and_member_of_the_group,
            enterprise_user_of_the_group_created_8_days_ago
          ].sort_by(&:id).reverse.pluck(:id)
        )
      end
    end

    context 'for created_before parameter' do
      let(:params) { { created_before: 10.days.ago } }

      let_it_be(:enterprise_user_of_the_group_created_12_days_ago) do
        create(:enterprise_user, :with_namespace, enterprise_group: enterprise_group).tap do |user|
          user.update_column(:created_at, 12.days.ago)
        end
      end

      let_it_be(:enterprise_user_of_the_group_created_8_days_ago) do
        create(:enterprise_user, :with_namespace, enterprise_group: enterprise_group).tap do |user|
          user.update_column(:created_at, 8.days.ago)
        end
      end

      it 'returns only enterprise users created before the specified time', :freeze_time do
        get_group_enterprise_users

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.pluck('id')).to eq(
          [
            enterprise_user_of_the_group_created_12_days_ago
          ].sort_by(&:id).reverse.pluck(:id)
        )
      end
    end

    context 'for two_factor parameter' do
      let_it_be(:enterprise_user_of_the_group_with_two_factor_enabled) do
        create(:enterprise_user, :two_factor, :with_namespace, enterprise_group: enterprise_group)
      end

      context 'when enabled value' do
        let(:params) { { two_factor: 'enabled' } }

        it 'returns only enterprise users with two-factor enabled' do
          get_group_enterprise_users

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.pluck('id')).to eq(
            [
              enterprise_user_of_the_group_with_two_factor_enabled
            ].sort_by(&:id).reverse.pluck(:id)
          )
        end
      end

      context 'when disabled value' do
        let(:params) { { two_factor: 'disabled' } }

        it 'returns only enterprise users with two-factor disabled' do
          get_group_enterprise_users

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.pluck('id')).to eq(
            [
              enterprise_user_of_the_group,
              blocked_enterprise_user_of_the_group,
              enterprise_user_and_member_of_the_group
            ].sort_by(&:id).reverse.pluck(:id)
          )
        end
      end
    end
  end

  describe 'GET /groups/:id/enterprise_users/:user_id' do
    subject(:get_group_enterprise_user) do
      get api("/groups/#{group_id}/enterprise_users/#{user_id}", current_user)
    end

    include_examples 'authentication and authorization requirements', allow_auditor: true

    it 'returns the enterprise user of the group' do
      get_group_enterprise_user

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['id']).to eq(enterprise_user_of_the_group.id)
    end

    it_behaves_like 'authorizing granular token permissions', :read_enterprise_user do
      let(:boundary_object) { enterprise_group }
      let(:user) { owner_of_enterprise_group }
      let(:request) { get api("/groups/#{group_id}/enterprise_users/#{user_id}", personal_access_token: pat) }
    end

    context 'when user_id does not refer to an enterprise user of the group' do
      let(:user_id) { enterprise_user_of_another_group.id }

      it 'returns 404 Not found' do
        get_group_enterprise_user

        expect(response).to have_gitlab_http_status(:not_found)
        expect(json_response['message']).to eq('404 Not found')
      end
    end
  end

  describe 'PATCH /groups/:id/enterprise_users/:user_id/disable_two_factor', :saas do
    before do
      stub_licensed_features(domain_verification: true)
    end

    let_it_be(:enterprise_user_of_the_group_with_two_factor_enabled) do
      create(:enterprise_user, :two_factor, :with_namespace, enterprise_group: enterprise_group)
    end

    subject(:disable_enterprise_user_two_factor) do
      patch api("/groups/#{group_id}/enterprise_users/#{user_id}/disable_two_factor", current_user)
    end

    include_examples 'authentication and authorization requirements'

    context 'when the enterprise user has two-factor authentication enabled' do
      let(:user_id) { enterprise_user_of_the_group_with_two_factor_enabled.id }

      it 'disables 2FA for the user' do
        expect { disable_enterprise_user_two_factor }.to change {
          enterprise_user_of_the_group_with_two_factor_enabled.reload.two_factor_enabled?
        }.from(true).to(false)
        expect(response).to have_gitlab_http_status(:no_content)
      end

      it_behaves_like 'authorizing granular token permissions', :disable_two_factor_enterprise_user do
        let(:boundary_object) { enterprise_group }
        let(:user) { owner_of_enterprise_group }
        let(:request) do
          patch api("/groups/#{group_id}/enterprise_users/#{user_id}/disable_two_factor", personal_access_token: pat)
        end
      end
    end

    context 'when the enterprise user does not have two-factor authentication enabled' do
      it 'returns 400 Bad request' do
        disable_enterprise_user_two_factor

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['message']).to eq(
          '400 Bad request - Two-factor authentication is not enabled for this user')
      end
    end

    context 'when user_id does not refer to an enterprise user of the group' do
      let(:user_id) { enterprise_user_of_another_group.id }

      it 'returns 404 Not found' do
        disable_enterprise_user_two_factor

        expect(response).to have_gitlab_http_status(:not_found)
        expect(json_response['message']).to eq('404 Not found')
      end
    end
  end

  describe 'PATCH /groups/:id/enterprise_users/:user_id', :saas do
    before do
      stub_licensed_features(domain_verification: true)
    end

    subject(:update_enterprise_user) do
      patch api("/groups/#{group_id}/enterprise_users/#{user_id}", current_user), params: params
    end

    include_examples 'authentication and authorization requirements'

    context 'when without any update attributes specified' do
      it 'returns 200 OK and the user' do
        update_enterprise_user

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['id']).to eq(enterprise_user_of_the_group.id)
      end

      it_behaves_like 'authorizing granular token permissions', :update_enterprise_user do
        let(:boundary_object) { enterprise_group }
        let(:user) { owner_of_enterprise_group }
        let(:request) do
          patch api("/groups/#{group_id}/enterprise_users/#{user_id}", personal_access_token: pat), params: params
        end
      end
    end

    context 'for name update' do
      let(:params) { { name: name } }

      let(:name) { 'New name' }

      it 'updates the user name and returns the user' do
        update_enterprise_user

        enterprise_user_of_the_group.reload
        expect(enterprise_user_of_the_group.name).to eq(name)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['id']).to eq(enterprise_user_of_the_group.id)
        expect(json_response['name']).to eq(name)
      end
    end

    context 'for email update' do
      let(:params) { { email: email } }

      let_it_be(:project) { create(:project, group: enterprise_group) }
      let_it_be(:enterprise_group_verified_domain) { create(:pages_domain, project: project) }

      context 'when specified email address is from a verified domain of the group' do
        let_it_be(:email) { "new-email@#{enterprise_group_verified_domain.domain}" }

        it 'updates the user email without requiring its confirmation and returns the user' do
          update_enterprise_user

          enterprise_user_of_the_group.reload
          expect(enterprise_user_of_the_group.email).to eq(email)
          # This expectation ensures that the group's email is automatically confirmed
          expect(enterprise_user_of_the_group.unconfirmed_email).to be_nil

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['id']).to eq(enterprise_user_of_the_group.id)
          expect(json_response['email']).to eq(email)
        end

        context 'when specified email address is already taken by another user' do
          let_it_be(:existing_user_with_specified_email) do
            create(:enterprise_user, enterprise_group: enterprise_group, email: email)
          end

          it 'returns 400 Bad Request with message' do
            current_enterprise_user_of_the_group_email = enterprise_user_of_the_group.email

            update_enterprise_user

            enterprise_user_of_the_group.reload

            expect(enterprise_user_of_the_group.email).to eq(current_enterprise_user_of_the_group_email)
            expect(enterprise_user_of_the_group.unconfirmed_email).to be_nil

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['message']).to eq('Email has already been taken')
          end
        end

        context 'when specified email address is invalid' do
          let_it_be(:email) { "invalid email@#{enterprise_group_verified_domain.domain}" }

          it 'returns 400 Bad Request with message' do
            current_enterprise_user_of_the_group_email = enterprise_user_of_the_group.email

            update_enterprise_user

            enterprise_user_of_the_group.reload

            expect(enterprise_user_of_the_group.email).to eq(current_enterprise_user_of_the_group_email)
            expect(enterprise_user_of_the_group.unconfirmed_email).to be_nil

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['message']).to eq(
              "Email is invalid. Email must be owned by the user's enterprise group"
            )
          end
        end
      end

      context 'when specified email address is not from a verified domain of the group' do
        let_it_be(:email) { "new-email@example.com" }

        it 'returns 400 Bad Request with message' do
          current_enterprise_user_of_the_group_email = enterprise_user_of_the_group.email

          update_enterprise_user

          enterprise_user_of_the_group.reload

          expect(enterprise_user_of_the_group.email).to eq(current_enterprise_user_of_the_group_email)
          expect(enterprise_user_of_the_group.unconfirmed_email).to be_nil

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['message']).to eq("Email must be owned by the user's enterprise group")
        end
      end
    end

    context 'for projects_limit update' do
      let(:params) { { projects_limit: 0 } }

      it 'updates the projects_limit and returns the user', :aggregate_failures do
        update_enterprise_user

        enterprise_user_of_the_group.reload
        expect(enterprise_user_of_the_group.projects_limit).to eq(0)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['id']).to eq(enterprise_user_of_the_group.id)
        expect(json_response['projects_limit']).to eq(0)
      end
    end

    context 'for can_create_group update' do
      let(:params) { { can_create_group: false } }

      it 'updates the can_create_group and returns the user', :aggregate_failures do
        update_enterprise_user

        enterprise_user_of_the_group.reload
        expect(enterprise_user_of_the_group.can_create_group).to be(false)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['id']).to eq(enterprise_user_of_the_group.id)
        expect(json_response['can_create_group']).to be(false)
      end
    end

    context 'when user_id does not refer to an enterprise user of the group' do
      let(:user_id) { enterprise_user_of_another_group.id }

      it 'returns 404 Not found' do
        update_enterprise_user

        expect(response).to have_gitlab_http_status(:not_found)
        expect(json_response['message']).to eq('404 Not found')
      end
    end
  end

  describe 'DELETE /groups/:id/enterprise_users/:user_id', :sidekiq_inline, :saas do
    let(:delete_params) { {} }
    let(:delete_headers) { {} }

    subject(:delete_group_enterprise_user) do
      delete api("/groups/#{group_id}/enterprise_users/#{user_id}", current_user),
        params: delete_params,
        headers: delete_headers
    end

    before do
      stub_licensed_features(domain_verification: true)
    end

    include_examples 'authentication and authorization requirements'

    it 'deletes the given user' do
      expect { delete_group_enterprise_user }
        .to change {
          Users::GhostUserMigration
            .where(user_id: user_id, initiator_user: current_user, hard_delete: false)
            .count
        }.by(1)

      expect(response).to have_gitlab_http_status(:no_content)
    end

    context 'when the enterprise user has personal projects' do
      before do
        create(:project, namespace: enterprise_user_of_the_group.namespace)
      end

      it 'deletes the user and their personal projects successfully', :aggregate_failures do
        expect { delete_group_enterprise_user }
          .to change {
            Users::GhostUserMigration
              .where(user_id: user_id, initiator_user: current_user, hard_delete: false)
              .count
          }.by(1)

        expect(response).to have_gitlab_http_status(:no_content)
      end

      context 'when hard_delete is true' do
        let(:delete_params) { { hard_delete: true } }

        it 'deletes the user and their personal projects successfully', :aggregate_failures do
          expect { delete_group_enterprise_user }
            .to change {
              Users::GhostUserMigration
                .where(user_id: user_id, initiator_user: current_user, hard_delete: true)
                .count
            }.by(1)

          expect(response).to have_gitlab_http_status(:no_content)
        end
      end
    end

    it_behaves_like 'authorizing granular token permissions', :delete_enterprise_user do
      let(:boundary_object) { enterprise_group }
      let(:user) { owner_of_enterprise_group }
      let(:request) do
        delete api("/groups/#{group_id}/enterprise_users/#{user_id}", personal_access_token: pat),
          params: delete_params,
          headers: delete_headers
      end
    end

    context 'when the user being deleted has a solo owned group' do
      let(:group) { create(:group) }

      before do
        group.add_member(enterprise_user_of_the_group, GroupMember::OWNER)
      end

      it 'does not delete the user or the group' do
        expect { delete_group_enterprise_user }
          .not_to change { Users::GhostUserMigration.count }

        expect(Group.exists?(group.id)).to be_truthy
      end

      it 'returns 409 Conflict' do
        delete_group_enterprise_user

        expect(response).to have_gitlab_http_status(:conflict)
        expect(json_response['message']).to eq('Can not remove a user who is the sole owner of a group.')
      end

      context 'when the hard_delete flag is provided' do
        let(:delete_params) { { hard_delete: true } }

        it 'deletes the user and the group' do
          expect { delete_group_enterprise_user }
            .to change {
              Users::GhostUserMigration
                .where(user_id: user_id, initiator_user: current_user, hard_delete: true)
                .count
            }.by(1)

          expect(Group.exists?(group.id)).to be_falsy
          expect(response).to have_gitlab_http_status(:no_content)
        end
      end
    end

    context 'when the If-Unmodified-Since header is provided by the client' do
      context 'when the user record has been modified since the given time' do
        let(:delete_headers) { { 'If-Unmodified-Since' => (enterprise_user_of_the_group.updated_at - 1.hour).to_s } }

        it 'does not delete the user' do
          expect { delete_group_enterprise_user }
            .not_to change { Users::GhostUserMigration.count }
          expect(response).to have_gitlab_http_status(:precondition_failed)
        end
      end

      context 'when the user record has not been modified since the given time' do
        let(:delete_headers) { { 'If-Unmodified-Since' => (enterprise_user_of_the_group.updated_at + 1.hour).to_s } }

        it 'deletes the user' do
          expect { delete_group_enterprise_user }
            .to change { Users::GhostUserMigration.where(user_id: user_id, initiator_user: current_user).count }.by(1)
          expect(response).to have_gitlab_http_status(:no_content)
        end
      end
    end

    context 'when user_id does not refer to an enterprise user of the group' do
      let(:user_id) { enterprise_user_of_another_group.id }

      it 'returns 404 Not found' do
        expect { delete_group_enterprise_user }
          .not_to change { Users::GhostUserMigration.count }
        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when the group does not have a feature license for the Enterprise Users feature' do
      before do
        stub_licensed_features(domain_verification: false)
      end

      it 'does not delete the user' do
        expect { delete_group_enterprise_user }.not_to change { Users::GhostUserMigration.count }
        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end
end
