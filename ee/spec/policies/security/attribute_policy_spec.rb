# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::AttributePolicy, feature_category: :security_asset_inventories do
  let_it_be(:root_group) { create(:group) }
  let_it_be(:group) { create(:group, parent: root_group) }
  let_it_be(:user) { create(:user) }
  let_it_be(:attribute) { build_stubbed(:security_attribute, namespace: root_group) }

  subject { described_class.new(user, attribute) }

  before do
    stub_licensed_features(security_attributes: true)
  end

  context 'when user is maintainer of root group' do
    before_all do
      root_group.add_maintainer(user)
    end

    it { is_expected.to be_allowed(:read_security_attribute) }
  end

  context 'when user is maintainer of subgroup' do
    before_all do
      group.add_maintainer(user)
    end

    it { is_expected.to be_disallowed(:read_security_attribute) }
  end

  context 'when user has developer access to root group' do
    before_all do
      root_group.add_developer(user)
    end

    it { is_expected.to be_allowed(:read_security_attribute) }
  end

  context 'when user has no access to any group' do
    subject { described_class.new(user, attribute) }

    it { is_expected.to be_disallowed(:read_security_attribute) }
  end

  context 'when user is owner of subgroup' do
    before_all do
      group.add_owner(user)
    end

    it { is_expected.to be_disallowed(:read_security_attribute) }
  end

  context 'when user has reporter access to root group' do
    before_all do
      root_group.add_reporter(user)
    end

    it { is_expected.to be_disallowed(:read_security_attribute) }
  end

  context 'when user has planner access to root group' do
    before_all do
      root_group.add_planner(user)
    end

    it { is_expected.to be_disallowed(:read_security_attribute) }
  end

  context 'when user has guest access to root group' do
    before_all do
      root_group.add_guest(user)
    end

    it { is_expected.to be_disallowed(:read_security_attribute) }
  end
end
