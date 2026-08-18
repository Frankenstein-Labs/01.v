# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::AnalyticsDashboardHelper, feature_category: :value_stream_management do
  let_it_be(:group) { build_stubbed(:group) }
  let_it_be(:current_user) { build_stubbed(:user) }

  before do
    stub_licensed_features(group_level_analytics_dashboard: true)
  end

  describe '#group_analytics_dashboard_available?' do
    before do
      allow(helper).to receive(:can?).with(current_user, :read_group_analytics_dashboards, group).and_return(true)
    end

    it 'is true for the group' do
      expect(helper.group_analytics_dashboard_available?(current_user, group)).to be(true)
    end

    context 'when the current user does not have permission' do
      before do
        allow(helper).to receive(:can?).with(current_user, :read_group_analytics_dashboards, group).and_return(false)
      end

      it 'is false for the group' do
        expect(helper.group_analytics_dashboard_available?(current_user, group)).to be(false)
      end
    end
  end

  describe '#group_analytics_settings_available?' do
    using RSpec::Parameterized::TableSyntax
    subject { group_analytics_settings_available?(current_user, group) }

    before do
      allow(self).to receive(:can?).with(current_user, :admin_group, group).and_return(can_admin_group)
      allow(self).to receive(:group_analytics_dashboard_available?).with(current_user, group)
        .and_return(can_see_analytics_dashboards)
      allow(group).to receive(:insights_available?).and_return(can_see_insights)
      allow(self).to receive(:can?).with(current_user, :modify_value_stream_dashboard_settings, group)
        .and_return(can_see_vsd_settings)
    end

    context 'when user cannot admin group' do
      let(:can_admin_group) { false }
      let(:can_see_analytics_dashboards) { true }
      let(:can_see_insights) { true }
      let(:can_see_vsd_settings) { true }

      it { is_expected.to be false }
    end

    context 'when user can admin group' do
      let(:can_admin_group) { true }

      where(:can_see_analytics_dashboards, :can_see_insights, :can_see_vsd_settings, :expected_result) do
        true | true | true | true
        true | true | false | true
        true | false | true | true
        true | false | false | true
        false | true | true | true
        false | true | false | true
        false | false | true | true
        false | false | false | false
      end

      with_them do
        it { is_expected.to eq(expected_result) }
      end
    end
  end
end
