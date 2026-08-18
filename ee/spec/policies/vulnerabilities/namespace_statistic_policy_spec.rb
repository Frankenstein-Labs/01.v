# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::NamespaceStatisticPolicy, feature_category: :security_asset_inventories do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user) }
  let_it_be(:namespace_statistic) { build(:vulnerability_namespace_statistic, namespace: group) }

  subject { described_class.new(user, namespace_statistic) }

  context 'when the security_dashboard feature is enabled' do
    before do
      stub_licensed_features(security_dashboard: true)
    end

    context 'when the current user has maintainer access to the group of the vulnerability project' do
      before_all do
        group.add_maintainer(user)
      end

      it { is_expected.to be_allowed(:admin_security_testing) }
    end

    context 'when the current user has developer access to the group of the vulnerability project' do
      before_all do
        group.add_developer(user)
      end

      it { is_expected.to be_disallowed(:admin_security_testing) }
    end

    context 'when the current user does not have developer access to the group of the vulnerability project' do
      it { is_expected.to be_disallowed(:admin_security_testing) }
    end
  end

  context 'when the security_dashboard feature is disabled' do
    before do
      stub_licensed_features(security_dashboard: false)
    end

    it { is_expected.to be_disallowed(:admin_security_testing) }
  end
end
