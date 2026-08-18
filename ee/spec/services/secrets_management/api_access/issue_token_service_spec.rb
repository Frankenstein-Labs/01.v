# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::ApiAccess::IssueTokenService, :gitlab_secrets_manager, feature_category: :secrets_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user) }

  before_all do
    project.add_developer(user)
  end

  describe '#execute' do
    subject(:result) { described_class.new(secrets_manager, user, auth_via: 'personal_access_token').execute }

    context 'with a project secrets manager' do
      let_it_be_with_refind(:secrets_manager) { create(:project_secrets_manager, project: project) }

      context 'when active' do
        before do
          provision_project_secrets_manager(secrets_manager, user)
        end

        it 'returns a token with the OpenBao connection details' do
          expect(result).to be_success

          token = result.payload[:token]
          expect(token.token).to be_present
          expect(token.expires_at).to be_present
          expect(token.namespace).to eq(secrets_manager.full_project_namespace_path)
          expect(token.kv_mount).to eq(secrets_manager.ci_secrets_mount_path)
          expect(token.secrets_path).to eq(secrets_manager.ci_data_root_path)
          expect(token.auth_mount).to eq("#{secrets_manager.api_auth_mount}/cel")
          expect(token.auth_role).to eq(secrets_manager.api_auth_role)
        end
      end

      context 'when not active' do
        it 'returns an error' do
          expect(result).to be_error
          expect(result.message).to include('not active')
        end
      end
    end

    context 'with a group secrets manager' do
      let_it_be_with_refind(:secrets_manager) { create(:group_secrets_manager, group: group) }

      before_all do
        group.add_developer(user)
      end

      before do
        provision_group_secrets_manager(secrets_manager, user)
      end

      it 'returns a token scoped to the group namespace' do
        expect(result).to be_success
        expect(result.payload[:token].namespace).to eq(secrets_manager.full_group_namespace_path)
      end
    end
  end
end
