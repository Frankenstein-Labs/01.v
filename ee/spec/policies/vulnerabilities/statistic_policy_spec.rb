# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::StatisticPolicy, feature_category: :security_asset_inventories do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be(:statistic) { build(:vulnerability_statistic, letter_grade: nil, critical: 5, project: project) }

  subject { described_class.new(user, statistic) }

  context 'when the security_dashboard feature is enabled' do
    before do
      stub_licensed_features(security_dashboard: true)
    end

    context 'when the current user has maintainer access to the vulnerability project' do
      before_all do
        project.add_maintainer(user)
      end

      it { is_expected.to be_allowed(:admin_security_testing) }
    end

    context 'when the current user has developer access to the vulnerability project' do
      before_all do
        project.add_developer(user)
      end

      it { is_expected.to be_disallowed(:admin_security_testing) }
    end

    context 'when the current user does not have developer access to the vulnerability project' do
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
