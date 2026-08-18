# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::GroupSecrets::ListNeedingRotationService, :gitlab_secrets_manager, feature_category: :secrets_management do
  let_it_be_with_reload(:group) { create(:group) }

  let!(:secrets_manager) { create(:group_secrets_manager, group: group) }

  let(:user) { create(:user, owner_of: group) }
  let(:service) { described_class.new(group, user) }

  def provision_secrets_manager(secrets_manager, user)
    provision_group_secrets_manager(secrets_manager, user)
  end

  def create_rotation_secret(name:, rotation_interval_days:)
    create_group_secret(
      user: user,
      group: group,
      name: name,
      description: "#{name} description",
      protected: false,
      environment: 'production',
      value: "#{name.downcase}-value",
      rotation_interval_days: rotation_interval_days
    )
  end

  it_behaves_like 'a service for listing secrets needing rotation', 'group'

  describe '#execute', :aggregate_failures do
    subject(:result) { service.execute }

    context 'when user is a maintainer and no permissions' do
      let(:user) { create(:user, maintainer_of: group) }

      it 'returns an error' do
        provision_group_secrets_manager(secrets_manager, user)

        expect { service.execute }.to raise_error(
          SecretsManagement::SecretsManagerClient::ApiError,
          "1 error occurred:\n\t* permission denied\n\n"
        )
      end
    end

    context 'when user is a maintainer and has proper permissions' do
      let(:user) { create(:user, maintainer_of: group) }

      before do
        provision_group_secrets_manager(secrets_manager, user)
        update_group_secrets_permission(
          user: user, group: group, actions: %w[read], principal: {
            id: Gitlab::Access.sym_options[:maintainer], type: 'Role'
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
