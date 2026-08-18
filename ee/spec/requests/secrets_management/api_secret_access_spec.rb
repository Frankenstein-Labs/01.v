# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Secrets Manager non-CI API secret access', :gitlab_secrets_manager, feature_category: :secrets_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :repository, group: group) }
  let_it_be(:owner) { create(:user, owner_of: project) }
  let_it_be(:reader) { create(:user) }

  let_it_be(:project_secrets_manager, freeze: false) { create(:project_secrets_manager, project: project) }

  before_all do
    project.add_developer(reader)
  end

  before do
    provision_project_secrets_manager(project_secrets_manager, owner)
    create_project_secret(
      user: owner, project: project, name: 'db_password', branch: 'master', environment: '*', value: 'super-secret'
    )
  end

  def grant(user, actions)
    SecretsManagement::ProjectSecretsPermissions::UpdateService.new(project, owner).execute(
      principal_id: user.id,
      principal_type: 'User',
      actions: actions,
      expired_at: nil
    )
  end

  def read_value_via_api(user, secret_name)
    jwt = SecretsManagement::ProjectApiJwt.new(
      current_user: user, project: project, auth_via: 'personal_access_token'
    ).encoded

    client = SecretsManagement::TestClient.new(
      jwt: jwt,
      role: project_secrets_manager.api_auth_role,
      auth_mount: project_secrets_manager.api_auth_mount,
      use_cel_auth: true,
      auth_namespace: project_secrets_manager.full_project_namespace_path,
      namespace: project_secrets_manager.full_project_namespace_path
    )

    client.read_kv_secret_value(
      project_secrets_manager.ci_secrets_mount_path,
      project_secrets_manager.ci_data_path(secret_name)
    )
  end

  context 'when the principal is granted read_value' do
    before do
      grant(reader, %w[read_metadata read_value])
    end

    it 'reads the secret value through the API mount' do
      expect(read_value_via_api(reader, 'db_password')).to eq('super-secret')
    end
  end

  context 'when the principal is granted only read_metadata' do
    before do
      grant(reader, %w[read_metadata])
    end

    it 'cannot read the secret value' do
      expect { read_value_via_api(reader, 'db_password') }
        .to raise_error(SecretsManagement::SecretsManagerClient::ApiError, /permission denied/)
    end
  end

  context 'when read_value is revoked' do
    before do
      grant(reader, %w[read_metadata read_value])
      grant(reader, %w[read_metadata])
    end

    it 'can no longer read the secret value' do
      expect { read_value_via_api(reader, 'db_password') }
        .to raise_error(SecretsManagement::SecretsManagerClient::ApiError, /permission denied/)
    end
  end

  context 'when the principal has no secrets permission' do
    it 'cannot read the secret value' do
      expect { read_value_via_api(reader, 'db_password') }
        .to raise_error(SecretsManagement::SecretsManagerClient::ApiError, /permission denied/)
    end
  end

  describe 'minted OpenBao token TTL' do
    # Without lease_options in the CEL program, OpenBao would mint a token with
    # its 32-day default TTL, far outliving the 5-minute JWT. The CEL program
    # caps it to the 5-minute default instead.
    it 'defaults the project mount token TTL to 5 minutes' do
      api_jwt = SecretsManagement::ProjectApiJwt.new(
        current_user: reader, project: project, auth_via: 'personal_access_token'
      ).encoded

      response = secrets_manager_client
        .with_namespace(project_secrets_manager.full_project_namespace_path)
        .cel_login_jwt(
          mount_path: project_secrets_manager.api_auth_mount,
          role: project_secrets_manager.api_auth_role,
          jwt: api_jwt
        )

      expect(response.dig('auth', 'lease_duration')).to eq(300)
    end

    context 'for the group mount' do
      let_it_be(:group_owner) { create(:user, owner_of: group) }
      let_it_be(:group_secrets_manager, freeze: false) { create(:group_secrets_manager, group: group) }

      before do
        provision_group_secrets_manager(group_secrets_manager, group_owner)
      end

      it 'defaults the group mount token TTL to 5 minutes' do
        group_api_jwt = SecretsManagement::GroupApiJwt.new(
          current_user: group_owner, group: group, auth_via: 'personal_access_token'
        ).encoded

        response = secrets_manager_client
          .with_namespace(group_secrets_manager.full_group_namespace_path)
          .cel_login_jwt(
            mount_path: group_secrets_manager.api_auth_mount,
            role: group_secrets_manager.api_auth_role,
            jwt: group_api_jwt
          )

        expect(response.dig('auth', 'lease_duration')).to eq(300)
      end
    end
  end
end
