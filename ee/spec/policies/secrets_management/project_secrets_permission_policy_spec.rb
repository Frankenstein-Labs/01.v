# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::ProjectSecretsPermissionPolicy, feature_category: :secrets_management do
  subject(:policy) { described_class.new(user, secrets_permission) }

  let_it_be(:user) { build(:user) }
  let_it_be(:project) { build(:project) }
  let_it_be(:secrets_permission) do
    SecretsManagement::ProjectSecretsPermission.new(
      resource: project,
      principal_type: 'User',
      principal_id: 1,
      actions: %w[read]
    )
  end

  let(:delegations) { policy.delegated_policies }

  it 'delegates to ProjectPolicy' do
    expect(delegations.size).to eq(1)

    delegations.each_value do |delegated_policy|
      expect(delegated_policy).to be_instance_of(::ProjectPolicy)
    end
  end
end
