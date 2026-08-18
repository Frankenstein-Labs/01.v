# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::NamespaceEnrollmentPolicy, feature_category: :secrets_management do
  subject(:policy) { described_class.new(user, enrollment) }

  let_it_be(:user) { build(:user) }
  let_it_be(:enrollment) { build(:secrets_manager_namespace_enrollment) }

  let(:delegations) { policy.delegated_policies }

  it 'delegates to the namespace policy' do
    expect(delegations.size).to eq(1)

    delegations.each_value do |delegated_policy|
      expect(delegated_policy).to be_instance_of(::GroupPolicy)
    end
  end
end
