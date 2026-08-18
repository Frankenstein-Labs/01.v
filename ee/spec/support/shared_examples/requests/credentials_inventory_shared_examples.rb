# frozen_string_literal: true

RSpec.shared_examples_for 'credentials inventory delete SSH key' do |group_credentials_inventory: false|
  include AdminModeHelper

  let_it_be(:user, freeze: false) do
    group_credentials_inventory ? group_enterprise_users.last : create(:user, name: 'abc')
  end

  let_it_be(:ssh_key, freeze: false) { create(:personal_key, user: user) }

  let(:ssh_key_id) { ssh_key.id }

  if group_credentials_inventory
    subject { delete group_security_credential_path(group_id: group.to_param, id: ssh_key_id) }
  else
    subject { delete admin_credential_path(id: ssh_key_id) }
  end

  context 'admin user', saas: group_credentials_inventory do
    before do
      unless group_credentials_inventory
        sign_in(admin)
        enable_admin_mode!(admin)
      end
    end

    context 'when `credentials_inventory` feature is enabled' do
      before do
        if group_credentials_inventory
          stub_licensed_features(credentials_inventory: true, group_saml: true)
        else
          stub_licensed_features(credentials_inventory: true)
        end
      end

      context 'and the ssh_key exists' do
        context 'and it removes the key' do
          it 'renders a success message' do
            subject

            expect(response).to redirect_to(credentials_path)
            expect(flash[:notice]).to eql 'User key was successfully removed.'
          end

          it 'notifies the key owner' do
            perform_enqueued_jobs do
              expect { subject }.to change { ActionMailer::Base.deliveries.size }.by(1)
            end
          end
        end

        context 'and it fails to remove the key' do
          before do
            allow_next_instance_of(Keys::DestroyService) do |service|
              allow(service).to receive(:execute).and_return(false)
            end
          end

          it 'renders a failure message' do
            subject

            expect(response).to redirect_to(credentials_path)
            expect(flash[:notice]).to eql 'Failed to remove user key.'
          end
        end
      end

      context 'and the ssh_key does not exist' do
        let(:ssh_key_id) { 999999999999999999999999999999999 }

        it 'renders a not found message' do
          subject

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'when `credentials_inventory` feature is disabled' do
      before do
        stub_licensed_features(credentials_inventory: false)
      end

      it 'returns 404' do
        subject

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  context 'non-admin user' do
    before do
      sign_in(user)
    end

    it 'returns 404' do
      subject

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end
end

RSpec.shared_examples_for 'credentials inventory revoke project & group access tokens' do
  |group_credentials_inventory: false|
  include AdminModeHelper

  let_it_be(:token_creator, freeze: false) { create(:user) }
  let_it_be(:subgroup, freeze: false) { create(:group, :private, parent: group) }
  let_it_be(:project, freeze: false) { create(:project, :private, group: group) }
  let_it_be(:other_group, freeze: false) { create(:group) }

  let_it_be(:group_bot, freeze: false) do
    create(:user, :project_bot, name: "Group bot", created_by_id: token_creator.id)
  end

  let_it_be(:subgroup_bot, freeze: false) do
    create(:user, :project_bot, name: "Subgroup bot", created_by_id: token_creator.id)
  end

  let_it_be(:project_bot, freeze: false) do
    create(:user, :project_bot, name: "Project bot", created_by_id: token_creator.id)
  end

  let_it_be(:nonmember_bot, freeze: false) do
    create(:user, :project_bot, name: "Non-member bot", created_by_id: token_creator.id)
  end

  let_it_be(:group_bot_token, freeze: false) do
    create(:personal_access_token, name: group_bot.name, user: group_bot, scopes: %w[read_api])
  end

  let_it_be(:subgroup_bot_token, freeze: false) do
    create(:personal_access_token, name: subgroup_bot.name, user: subgroup_bot, scopes: %w[read_api])
  end

  let_it_be(:project_bot_token, freeze: false) do
    create(:personal_access_token, name: project_bot.name, user: project_bot, scopes: %w[read_api])
  end

  let_it_be(:nonmember_bot_token, freeze: false) do
    create(:personal_access_token, name: nonmember_bot.name, user: nonmember_bot, scopes: %w[read_api])
  end

  context 'revoke resource access tokens', saas: group_credentials_inventory do
    before do
      unless group_credentials_inventory
        sign_in(admin)
        enable_admin_mode!(admin)
      end

      stub_licensed_features(credentials_inventory: true, group_saml: true)
    end

    before_all do
      group_bot.update!(bot_namespace: group)
      subgroup_bot.update!(bot_namespace: subgroup)
      project_bot.update!(bot_namespace: project.project_namespace)
      nonmember_bot.update!(bot_namespace: other_group)

      group.add_developer(group_bot)
      subgroup.add_developer(subgroup_bot)
      project.add_developer(project_bot)
      other_group.add_developer(nonmember_bot)
    end

    subject(:revoke_token) do
      if group_credentials_inventory
        put group_security_credential_resource_revoke_path(
          group_id: group, credential_id: token_id, resource_id: resource_id, resource_type: resource_type
        )
      else
        put admin_credential_resource_revoke_path(
          credential_id: token_id, resource_id: resource_id, resource_type: resource_type
        )
      end
    end

    let_it_be(:redirect_path, freeze: false) do
      if group_credentials_inventory
        group_security_credentials_path(group_id: group)
      else
        admin_credentials_path
      end
    end

    context 'group access token' do
      let(:token_id) { group_bot_token.id }
      let(:resource_id) { group.id }
      let(:resource_type) { 'Group' }

      it 'removes group access token' do
        revoke_token

        expect(response).to redirect_to redirect_path
        expect(flash[:notice]).to eq(
          format(_("Access token %{token_name} has been revoked."), token_name: group_bot_token.name)
        )
      end
    end

    context 'subgroup access token' do
      let(:token_id) { subgroup_bot_token.id }
      let(:resource_id) { subgroup.id }
      let(:resource_type) { 'Group' }

      it 'removes subgroup access token' do
        revoke_token

        expect(response).to redirect_to redirect_path
        expect(flash[:notice]).to eq(
          format(_("Access token %{token_name} has been revoked."), token_name: subgroup_bot_token.name)
        )
      end
    end

    context 'project access token' do
      let(:token_id) { project_bot_token.id }
      let(:resource_id) { project.id }
      let(:resource_type) { 'Project' }

      it 'removes group access token' do
        revoke_token

        expect(response).to redirect_to redirect_path
        expect(flash[:notice]).to eq(
          format(_("Access token %{token_name} has been revoked."), token_name: project_bot_token.name)
        )
      end
    end

    context 'nonmember access token' do
      let(:token_id) { nonmember_bot_token.id }
      let(:resource_id) { other_group.id }
      let(:resource_type) { 'Group' }

      it "removes the access token only for admin users" do
        revoke_token

        if group_credentials_inventory
          expect(response).to have_gitlab_http_status(:not_found)
        else
          expect(response).to redirect_to redirect_path
          expect(flash[:notice]).to eq(
            format(_("Access token %{token_name} has been revoked."), token_name: nonmember_bot_token.name)
          )
        end
      end
    end
  end
end
