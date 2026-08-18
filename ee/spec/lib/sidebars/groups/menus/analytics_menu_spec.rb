# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Groups::Menus::AnalyticsMenu, feature_category: :navigation do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:owner) { create(:user) }
  let_it_be_with_refind(:group) do
    create(:group, :private, name: 'group_one').tap do |g|
      g.add_owner(owner)
    end
  end

  let(:user) { owner }
  let(:context) { Sidebars::Groups::Context.new(current_user: user, container: group) }
  let(:menu) { described_class.new(context) }

  describe '#link' do
    before do
      stub_licensed_features(cycle_analytics_for_groups: true, group_ci_cd_analytics_releases: true)
    end

    it 'returns link to the value stream page' do
      expect(menu.link).to include("/groups/#{group.full_path}/-/analytics/value_stream_analytics")
    end

    context 'when Value Stream is not visible' do
      before do
        stub_licensed_features(cycle_analytics_for_groups: false, group_ci_cd_analytics_releases: true)
      end

      it 'returns link to the the first visible menu item' do
        allow(menu).to receive(:cycle_analytics_menu_item).and_return(double(render?: false))

        expect(menu.link).not_to include("/groups/#{group.full_path}/-/analytics/value_stream_analytics")
        expect(menu.link).to eq menu.renderable_items.first.link
      end
    end
  end

  describe 'Menu items' do
    subject(:menu_item) { described_class.new(context).renderable_items.find { |e| e.item_id == item_id } }

    describe 'CI/CD' do
      let(:item_id) { :ci_cd_analytics }

      before do
        stub_licensed_features(group_ci_cd_analytics_releases: true)
      end

      it { is_expected.not_to be_nil }

      describe 'when licensed feature :group_ci_cd_analytics_releases is disabled' do
        specify do
          stub_licensed_features(group_ci_cd_analytics_releases: false)

          is_expected.to be_nil
        end
      end

      describe 'when the user does not have access' do
        let(:user) { nil }

        it { is_expected.to be_nil }
      end
    end

    describe 'Devops adoptions' do
      let(:item_id) { :devops_adoption }

      before do
        stub_licensed_features(group_level_devops_adoption: true)
      end

      it { is_expected.not_to be_nil }

      describe 'when the user does not have access' do
        let(:user) { nil }

        it { is_expected.to be_nil }
      end
    end

    describe 'Repository' do
      let(:item_id) { :repository_analytics }

      before do
        stub_licensed_features(group_coverage_reports: true, group_repository_analytics: true)
      end

      it { is_expected.not_to be_nil }

      describe 'when licensed feature :group_coverage_reports is disabled' do
        specify do
          stub_licensed_features(group_coverage_reports: false)

          is_expected.to be_nil
        end
      end

      describe 'when licensed feature :group_repository_analytics is disabled' do
        specify do
          stub_licensed_features(group_repository_analytics: false)

          is_expected.to be_nil
        end
      end

      describe 'when the user does not have access' do
        let(:user) { nil }

        it { is_expected.to be_nil }
      end
    end

    describe 'Contribution analytics' do
      let(:item_id) { :contribution_analytics }

      before do
        stub_licensed_features(contribution_analytics: true)
        stub_feature_flags(contributions_analytics_dashboard: false)
      end

      it { is_expected.not_to be_nil }

      describe 'when contributions_analytics_dashboard feature flag is enabled' do
        specify do
          stub_feature_flags(contributions_analytics_dashboard: true)

          is_expected.to be_nil
        end
      end

      describe 'when licensed feature :contribution_analytics is disabled' do
        specify do
          stub_licensed_features(contribution_analytics: false)

          is_expected.to be_nil
        end
      end

      describe 'when the user does not have access' do
        let(:user) { nil }

        it 'is not available' do
          is_expected.to be_nil
        end
      end
    end

    describe 'Insights' do
      let(:item_id) { :insights }
      let(:insights_available) { true }

      before do
        allow(group).to receive(:insights_available?).and_return(insights_available)
      end

      it { is_expected.not_to be_nil }

      describe 'when insights are not available' do
        let(:insights_available) { false }

        it { is_expected.to be_nil }
      end
    end

    describe 'Issue analytics' do
      let(:item_id) { :issues_analytics }
      let(:issues_analytics_enabled) { true }

      before do
        stub_licensed_features(issues_analytics: issues_analytics_enabled)
      end

      it { is_expected.not_to be_nil }

      describe 'when licensed feature :issues_analytics is disabled' do
        let(:issues_analytics_enabled) { false }

        it { is_expected.to be_nil }
      end
    end

    describe 'Productivity analytics' do
      let(:item_id) { :productivity_analytics }
      let(:productivity_analytics_enabled) { true }

      before do
        stub_licensed_features(productivity_analytics: productivity_analytics_enabled)
      end

      it { is_expected.not_to be_nil }

      describe 'when licensed feature :productivity_analytics is disabled' do
        let(:productivity_analytics_enabled) { false }

        it { is_expected.to be_nil }
      end

      describe 'when the user does not have access' do
        let(:user) { nil }

        it { is_expected.to be_nil }
      end
    end

    describe 'Value Stream' do
      let(:item_id) { :cycle_analytics }
      let(:cycle_analytics_enabled) { true }

      before do
        stub_licensed_features(cycle_analytics_for_groups: cycle_analytics_enabled)
      end

      it { is_expected.not_to be_nil }

      describe 'when licensed feature :cycle_analytics_for_groups is disabled' do
        let(:cycle_analytics_enabled) { false }

        it { is_expected.to be_nil }
      end

      describe 'when the user does not have access' do
        let(:user) { nil }

        it { is_expected.to be_nil }
      end
    end

    describe 'Analytics dashboards' do
      let(:item_id) { :analytics_dashboards }
      let(:group_level_analytics_dashboard_enabled) { true }

      before do
        stub_licensed_features(group_level_analytics_dashboard: group_level_analytics_dashboard_enabled)
      end

      it { is_expected.not_to be_nil }
      specify { expect(menu_item.link).to eq('/groups/group_one/-/analytics/dashboards') }

      context 'with different user access levels' do
        where(:access_level, :has_menu_item) do
          nil         | false
          :reporter   | true
          :developer  | true
          :maintainer | true
        end

        with_them do
          let(:user) { create(:user) }

          before do
            group.add_member(user, access_level)
          end

          describe "when the user is not allowed to view the menu item", if: !params[:has_menu_item] do
            it { is_expected.to be_nil }
          end

          describe "when the user is allowed to view the menu item", if: params[:has_menu_item] do
            it { is_expected.not_to be_nil }
          end
        end
      end

      describe 'when the license does not support the feature' do
        let(:group_level_analytics_dashboard_enabled) { false }

        it { is_expected.to be_nil }
      end
    end
  end

  describe 'Feature Library metadata' do
    before do
      stub_licensed_features(
        group_ci_cd_analytics_releases: true,
        contribution_analytics: true,
        group_level_devops_adoption: true,
        issues_analytics: true,
        productivity_analytics: true,
        group_coverage_reports: true,
        group_repository_analytics: true,
        cycle_analytics_for_groups: true,
        group_level_analytics_dashboard: true
      )
      stub_feature_flags(contributions_analytics_dashboard: false)
      allow(group).to receive(:insights_available?).and_return(true)
    end

    subject(:serialized) { menu.renderable_items.map(&:serialize_for_super_sidebar) }

    it 'gives every item a description and a unique library_icon', :aggregate_failures do
      expect(serialized).not_to be_empty
      expect(serialized).to all(include(:description, :library_icon))
      icons = serialized.map { |item| item[:library_icon] }
      expect(icons).to match_array(icons.uniq)
    end

    it 'tags licensed items with the correct tier', :aggregate_failures do
      tiers = serialized.index_by { |item| item[:id] }.transform_values { |item| item[:tier] }

      expect(tiers).to include(
        contribution_analytics: :premium,
        devops_adoption: :ultimate,
        insights: :ultimate,
        issues_analytics: :premium,
        productivity_analytics: :premium,
        repository_analytics: :premium,
        analytics_dashboards: :premium
      )
    end
  end
end
