# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Projects::Menus::MonitorMenu do
  let(:project) { build_stubbed(:project) }
  let(:user) { project.first_owner }
  let(:context) { Sidebars::Projects::Context.new(current_user: user, container: project, show_cluster_hint: true) }

  describe 'Menu items' do
    subject { described_class.new(context).renderable_items.index { |e| e.item_id == item_id } }

    before do
      stub_feature_flags(hide_error_tracking_features: false)
    end

    describe 'On-call Schedules', feature_category: :on_call_schedule_management do
      let(:item_id) { :on_call_schedules }

      before do
        stub_licensed_features(oncall_schedules: true)
      end

      it { is_expected.not_to be_nil }

      describe 'when the user does not have access' do
        let(:user) { nil }

        it { is_expected.to be_nil }
      end
    end

    describe 'Escalation Policies', feature_category: :incident_management do
      let(:item_id) { :escalation_policies }

      before do
        stub_licensed_features(oncall_schedules: true, escalation_policies: true)
      end

      it { is_expected.not_to be_nil }

      describe 'when the user does not have access' do
        let(:user) { nil }

        it { is_expected.to be_nil }
      end
    end

    describe 'Tracing', feature_category: :observability do
      let(:item_id) { :tracing }
      let(:user) { build(:user) }
      let(:role) { :reporter }

      before do
        stub_licensed_features(observability: true)
        stub_member_access_level(project, role => user)
      end

      it { is_expected.not_to be_nil }

      describe 'when feature flag is disabled' do
        before do
          stub_feature_flags(observability_features: false)
        end

        it { is_expected.to be_nil }
      end

      describe 'when unlicensed' do
        before do
          stub_licensed_features(observability: false)
        end

        it { is_expected.to be_nil }
      end

      describe 'when user does not have permissions' do
        let(:role) { :guest }

        it { is_expected.to be_nil }
      end
    end

    describe 'Metrics', feature_category: :observability do
      let(:item_id) { :metrics }
      let(:user) { build(:user) }
      let(:role) { :reporter }

      before do
        stub_licensed_features(observability: true)
        stub_member_access_level(project, role => user)
      end

      it { is_expected.not_to be_nil }

      describe 'when feature flag is disabled' do
        before do
          stub_feature_flags(observability_features: false)
        end

        it { is_expected.to be_nil }
      end

      describe 'when unlicensed' do
        before do
          stub_licensed_features(observability: false)
        end

        it { is_expected.to be_nil }
      end

      describe 'when user does not have permissions' do
        let(:role) { :guest }

        it { is_expected.to be_nil }
      end
    end

    describe 'Logs', feature_category: :observability do
      let(:item_id) { :logs }
      let(:user) { build(:user) }
      let(:role) { :reporter }

      before do
        stub_licensed_features(observability: true)
        stub_member_access_level(project, role => user)
      end

      it { is_expected.not_to be_nil }

      describe 'when feature flag is disabled' do
        before do
          stub_feature_flags(observability_features: false)
        end

        it { is_expected.to be_nil }
      end

      describe 'when unlicensed' do
        before do
          stub_licensed_features(observability: false)
        end

        it { is_expected.to be_nil }
      end

      describe 'when user does not have permissions' do
        let(:role) { :guest }

        it { is_expected.to be_nil }
      end
    end
  end

  describe 'Feature Library metadata' do
    before do
      stub_feature_flags(hide_error_tracking_features: false)
    end

    subject(:item) do
      described_class.new(context).renderable_items.find { |e| e.item_id == item_id }
    end

    describe 'On-call Schedules' do
      let(:item_id) { :on_call_schedules }

      before do
        stub_licensed_features(oncall_schedules: true)
      end

      it 'tags the item as a Premium feature', :aggregate_failures do
        serialized = item.serialize_for_super_sidebar

        expect(serialized[:tier]).to eq(:premium)
        expect(serialized).to include(:description, :library_icon)
      end
    end

    describe 'Escalation Policies' do
      let(:item_id) { :escalation_policies }

      before do
        stub_licensed_features(oncall_schedules: true, escalation_policies: true)
      end

      it 'tags the item as a Premium feature', :aggregate_failures do
        serialized = item.serialize_for_super_sidebar

        expect(serialized[:tier]).to eq(:premium)
        expect(serialized).to include(:description, :library_icon)
      end
    end

    describe 'observability items' do
      let(:user) { build(:user) }

      before do
        stub_licensed_features(observability: true)
        stub_member_access_level(project, reporter: user)
      end

      %i[tracing metrics logs].each do |id|
        describe id.to_s do
          let(:item_id) { id }

          it 'exposes Feature Library metadata without a tier', :aggregate_failures do
            serialized = item.serialize_for_super_sidebar

            expect(serialized).to include(:description, :library_icon)
            expect(serialized[:tier]).to be_nil
          end
        end
      end
    end
  end
end
