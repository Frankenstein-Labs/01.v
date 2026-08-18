# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::ProjectSecrets::ListNeedingRotationService, :gitlab_secrets_manager, feature_category: :secrets_management do
  let_it_be_with_reload(:project) { create(:project) }

  let!(:secrets_manager) { create(:project_secrets_manager, project: project) }

  let(:user) { create(:user, owner_of: project) }
  let(:service) { described_class.new(project, user) }

  def provision_secrets_manager(secrets_manager, user)
    provision_project_secrets_manager(secrets_manager, user)
  end

  def create_rotation_secret(name:, rotation_interval_days:)
    create_project_secret(
      user: user,
      project: project,
      name: name,
      description: "#{name} description",
      branch: 'main',
      environment: 'production',
      value: "#{name.downcase}-value",
      rotation_interval_days: rotation_interval_days
    )
  end

  it_behaves_like 'a service for listing secrets needing rotation', 'project'

  describe '#execute', :aggregate_failures do
    subject(:result) { service.execute }

    context 'when user is a developer and no permissions' do
      let(:user) { create(:user, developer_of: project) }

      it 'returns an error' do
        provision_project_secrets_manager(secrets_manager, user)

        expect { service.execute }.to raise_error(
          SecretsManagement::SecretsManagerClient::ApiError,
          "1 error occurred:\n\t* permission denied\n\n"
        )
      end
    end

    context 'when user is a developer and has proper permissions' do
      let(:user) { create(:user, developer_of: project) }

      before do
        provision_project_secrets_manager(secrets_manager, user)
        update_project_secrets_permission(
          user: user, project: project, actions: %w[read], principal: {
            id: Gitlab::Access.sym_options[:developer], type: 'Role'
          }
        )
      end

      it 'returns success' do
        expect(result).to be_success
        expect(result.payload[:secrets]).to eq([])
      end
    end
  end
end
