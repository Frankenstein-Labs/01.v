# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Issuables::CustomFieldPolicy, feature_category: :team_planning do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:custom_field) { create(:custom_field, namespace: group) }

  subject(:policy) { described_class.new(user, custom_field) }

  before do
    stub_licensed_features(custom_fields: true)
  end

  context 'when user does not have access to the group' do
    it { is_expected.to be_disallowed(:read_custom_field) }
  end

  context 'when user has access to the group' do
    before_all do
      group.add_guest(user)
    end

    it { is_expected.to be_allowed(:read_custom_field) }
  end

  context 'when feature is not available' do
    before do
      stub_licensed_features(custom_fields: false)
    end

    it { is_expected.to be_disallowed(:read_custom_field) }
  end
end
