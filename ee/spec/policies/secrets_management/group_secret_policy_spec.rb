# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::GroupSecretPolicy, feature_category: :secrets_management do
  subject(:policy) { described_class.new(user, secret) }

  let_it_be(:user) { build(:user) }
  let_it_be(:group) { build(:group) }
  let_it_be(:secret) do
    SecretsManagement::GroupSecret.new(
      group: group
    )
  end

  let(:delegations) { policy.delegated_policies }

  it 'delegates to GroupPolicy' do
    expect(delegations.size).to eq(1)

    delegations.each_value do |delegated_policy|
      expect(delegated_policy).to be_instance_of(::GroupPolicy)
    end
  end
end
