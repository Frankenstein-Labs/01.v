# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Projects::Menus::AnalyticsMenu, feature_category: :navigation do
  using RSpec::Parameterized::TableSyntax

  let_it_be_with_refind(:project) { create(:project, :small_repo) }

  let(:user) { project.first_owner }
  let(:context) { Sidebars::Projects::Context.new(current_user: user, container: project, current_ref: project.repository.root_ref) }

  subject { described_class.new(context) }

  describe 'Menu items' do
    subject { described_class.new(context).renderable_items.index { |e| e.item_id == item_id } }

    describe 'Code Review' do
      let(:item_id) { :code_review }

      it { is_expected.not_to be_nil }

      describe 'when the user does not have access' do
        let(:user) { nil }

        it { is_expected.to be_nil }
      end
    end

    describe 'Insights' do
      let(:item_id) { :insights }
      let(:insights_available) { true }

      before do
        allow(project).to receive(:insights_available?).and_return(insights_available)
      end

      it { is_expected.not_to be_nil }

      context 'when insights are not available' do
        let(:insights_available) { false }

        it { is_expected.to be_nil }
      end

      describe 'when the user does not have access' do
        let(:user) { nil }

        it { is_expected.to be_nil }
      end
    end

    describe 'Issue' do
      let(:item_id) { :issues }
      let(:licensed) { true }

      before do
        stub_licensed_features(issues_analytics: licensed)
      end

      it { is_expected.not_to be_nil }

      describe 'when the user does not have access' do
        let(:user) { nil }

        it { is_expected.to be_nil }
      end

      describe 'when licensed feature issues analytics is not enabled' do
        let(:licensed) { false }

        it { is_expected.to be_nil }
      end

      describe 'when issues are disabled' do
        before do
          project.issues_enabled = false
          project.save!
        end

        it { is_expected.to be_nil }
      end
    end

    describe 'Dashboards' do
      let(:item_id) { :dashboards_analytics }

      before do
        stub_licensed_features(project_level_analytics_dashboard: true)
      end

      describe 'for personal namespace projects' do
        it 'is nil for personal namespace projects' do
          is_expected.to be_nil
        end
      end

      describe 'for group namespace projects' do
        let_it_be(:user) { create(:user) }
        let_it_be(:group) { create(:group) }
        let_it_be_with_reload(:project) { create(:project, group: group) }

        before_all do
          project.add_maintainer(user)
        end

        it { is_expected.not_to be_nil }

        context 'with different user access levels' do
          where(:access_level, :has_menu_item) do
            nil         | false
            :guest      | false
            :reporter   | true
            :developer  | true
            :maintainer | true
          end

          with_them do
            let(:user) { create(:user) }

            before do
              project.add_member(user, access_level)
            end

            context "when the user is not allowed to view the menu item", if: !params[:has_menu_item] do
              it { is_expected.to be_nil }
            end

            context "when the user is allowed to view the menu item", if: params[:has_menu_item] do
              it { is_expected.not_to be_nil }
            end
          end
        end

        describe 'when the license does not support the feature' do
          before do
            stub_licensed_features(project_level_analytics_dashboard: false)
          end

          it { is_expected.to be_nil }
        end
      end
    end
  end

  describe 'Feature Library metadata' do
    subject(:item) do
      described_class.new(context).renderable_items.find { |e| e.item_id == item_id }
    end

    describe 'Insights' do
      let(:item_id) { :insights }

      before do
        allow(project).to receive(:insights_available?).and_return(true)
      end

      it 'tags the item as an Ultimate feature', :aggregate_failures do
        serialized = item.serialize_for_super_sidebar

        expect(serialized[:tier]).to eq(:ultimate)
        expect(serialized).to include(:description, :library_icon)
      end
    end

    describe 'Code Review' do
      let(:item_id) { :code_review }

      it 'tags the item as a Premium feature', :aggregate_failures do
        serialized = item.serialize_for_super_sidebar

        expect(serialized[:tier]).to eq(:premium)
        expect(serialized).to include(:description, :library_icon)
      end
    end

    describe 'Issue' do
      let(:item_id) { :issues }

      before do
        stub_licensed_features(issues_analytics: true)
      end

      it 'tags the item as a Premium feature', :aggregate_failures do
        serialized = item.serialize_for_super_sidebar

        expect(serialized[:tier]).to eq(:premium)
        expect(serialized).to include(:description, :library_icon)
      end
    end

    describe 'Dashboards' do
      let(:item_id) { :dashboards_analytics }
      let_it_be(:user) { create(:user) }
      let_it_be(:group) { create(:group) }
      let_it_be_with_reload(:project) { create(:project, group: group) }

      before_all do
        project.add_maintainer(user)
      end

      before do
        stub_licensed_features(project_level_analytics_dashboard: true)
      end

      it 'tags the item as a Premium feature', :aggregate_failures do
        serialized = item.serialize_for_super_sidebar

        expect(serialized[:tier]).to eq(:premium)
        expect(serialized).to include(:description, :library_icon)
      end
    end
  end
end
