# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Notifications::TargetedMessagePolicy, feature_category: :acquisition do
  let_it_be(:user) { create(:user) }
  let_it_be(:public_namespace) { create(:group) }
  let_it_be(:owned_namespace) { create(:group, owners: [user]) }
  let_it_be(:private_namespace) { create(:group, :private) }

  let(:targeted_message) { create(:targeted_message, namespaces: [owned_namespace]) }

  subject(:policy) { described_class.new(user, targeted_message) }

  context 'when user owns the associated namespace' do
    it { is_expected.to be_allowed(:read_namespace) }
  end

  context 'when user can read the associated namespace' do
    let(:targeted_message) { create(:targeted_message, namespaces: [public_namespace]) }

    it { is_expected.to be_allowed(:read_namespace) }
  end

  context 'when user cannot read the associated namespace' do
    let(:targeted_message) { create(:targeted_message, namespaces: [private_namespace]) }

    it { is_expected.to be_disallowed(:read_namespace) }
  end
end
