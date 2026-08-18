# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::GroupSecretsManagerPolicy, feature_category: :secrets_management do
  subject(:policy) { described_class.new(user, secrets_manager) }

  let_it_be(:user) { build(:user) }
  let_it_be(:secrets_manager) { build(:group_secrets_manager) }

  let(:delegations) { policy.delegated_policies }

  it 'delegates to GroupPolicy' do
    expect(delegations.size).to eq(1)

    delegations.each_value do |delegated_policy|
      expect(delegated_policy).to be_instance_of(::GroupPolicy)
    end
  end
end
