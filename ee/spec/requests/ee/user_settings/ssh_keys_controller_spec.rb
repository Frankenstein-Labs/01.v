# frozen_string_literal: true

require 'spec_helper'

RSpec.describe UserSettings::SshKeysController, feature_category: :source_code_management do
  context 'for enterprise users', :saas do
    before do
      stub_licensed_features(disable_ssh_keys: true)
      stub_saas_features(disable_ssh_keys: true)

      login_as(user)
    end

    let_it_be_with_reload(:group) { create(:group) }
    let_it_be_with_reload(:user) { create(:enterprise_user, :with_namespace, enterprise_group: group) }

    let_it_be(:ssh_key) { create(:key, user: user) }

    describe 'GET #index' do
      subject(:request_index) { get user_settings_ssh_keys_path }

      it 'renders page' do
        request_index

        expect(response).to have_gitlab_http_status(:success)
      end

      context 'when SSH Keys are disabled by the group' do
        before do
          group.namespace_settings.update!(disable_ssh_keys: true)
        end

        it 'renders 404' do
          request_index

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    describe 'GET #show' do
      subject(:request_show) { get user_settings_ssh_key_path(ssh_key) }

      it 'renders page' do
        request_show

        expect(response).to have_gitlab_http_status(:success)
      end

      context 'when SSH Keys are disabled by the group' do
        before do
          group.namespace_settings.update!(disable_ssh_keys: true)
        end

        it 'renders 404' do
          request_show

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    describe 'POST #create' do
      subject(:request_create) do
        post user_settings_ssh_keys_path, params: { key: { title: 'SSH Key', key: build(:key).key } }
      end

      it 'creates the key' do
        expect do
          request_create
        end.to change { user.reload.keys.count }.by(1)

        expect(response).to have_gitlab_http_status(:found)
      end

      context 'when SSH Keys are disabled by the group' do
        before do
          group.namespace_settings.update!(disable_ssh_keys: true)
        end

        it 'does not create the key' do
          expect do
            request_create
          end.not_to change { user.reload.keys.count }

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    describe 'DELETE #destroy' do
      subject(:request_destroy) { delete user_settings_ssh_key_path(ssh_key) }

      it 'destroys the key' do
        expect do
          request_destroy
        end.to change { user.reload.keys.count }.by(-1)

        expect(response).to have_gitlab_http_status(:found)
      end

      context 'when SSH Keys are disabled by the group' do
        before do
          group.namespace_settings.update!(disable_ssh_keys: true)
        end

        it 'does not destroy the key' do
          expect do
            request_destroy
          end.not_to change { user.reload.keys.count }

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    describe 'DELETE #revoke' do
      subject(:request_revoke) { delete revoke_user_settings_ssh_key_path(ssh_key) }

      it 'revokes the key' do
        expect do
          request_revoke
        end.to change { user.reload.keys.count }.by(-1)

        expect(response).to have_gitlab_http_status(:found)
      end

      context 'when SSH Keys are disabled by the group' do
        before do
          group.namespace_settings.update!(disable_ssh_keys: true)
        end

        it 'does not revoke the key' do
          expect do
            request_revoke
          end.not_to change { user.reload.keys.count }

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end
  end
end
