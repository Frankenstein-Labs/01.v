# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::AnalyzerNamespaceStatusPolicy, feature_category: :security_asset_inventories do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user) }
  let_it_be(:analyzer_group_status) do
    build(:analyzer_namespace_status, success: 1, failure: 2,
      analyzer_type: :sast, namespace: group)
  end

  subject { described_class.new(user, analyzer_group_status) }

  context 'when the security_dashboard feature is enabled' do
    before do
      stub_licensed_features(security_inventory: true)
    end

    context 'when the current user has maintainer access to the group' do
      before_all do
        group.add_maintainer(user)
      end

      it { is_expected.to be_allowed(:read_security_inventory) }
    end

    context 'when the current user has developer access to the group' do
      before_all do
        group.add_developer(user)
      end

      it { is_expected.to be_allowed(:read_security_inventory) }
    end

    context 'when the current user does not have developer access to the group' do
      it { is_expected.to be_disallowed(:read_security_inventory) }
    end
  end

  context 'when the security_dashboard feature is disabled' do
    before do
      stub_licensed_features(security_dashboard: false)
    end

    it { is_expected.to be_disallowed(:read_security_inventory) }
  end
end
