# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Widgets::Statuses::StatusMatcherService, feature_category: :team_planning do
  subject(:service) { described_class.new(old_status, new_lifecycle).find_fallback }

  context "when old_status is nil" do
    let(:old_status) { nil }
    let(:new_lifecycle) { create(:work_item_custom_lifecycle) }

    it { is_expected.to be_nil }
  end

  context "when new_lifecycle is nil" do
    let(:old_status) { build_stubbed(:work_item_system_defined_status, :to_do) }
    let(:new_lifecycle) { nil }

    it { is_expected.to be_nil }
  end

  context "when new_licycle is system defined" do
    let(:new_lifecycle) { build_stubbed(:work_item_system_defined_lifecycle) }

    context "and old_status is system defined" do
      it "always return to same status as old status" do
        lifecycle = build_stubbed(:work_item_system_defined_lifecycle)
        lifecycle.statuses.each do |status|
          result = described_class.new(status, new_lifecycle).find_fallback
          expect(result.id).to eq(status.id)
        end
      end
    end

    context "when old_status is custom" do
      context "and matches by name and state" do
        let(:old_status) { create(:work_item_custom_status, category: :done, name: "Done") }

        it "returns the equivalent system defined status" do
          expected_result = build_stubbed(:work_item_system_defined_status, :done)
          expect(service.id).to eq(expected_result.id)
        end
      end

      context "and matches by name but not state" do
        let(:old_status) { create(:work_item_custom_status, category: :done, name: "In progress") }

        it "does not return the in progress status" do
          expected_result = build_stubbed(:work_item_system_defined_status, :in_progress)
          expect(service.id).not_to eq(expected_result.id)
        end
      end

      context "and matches by category" do
        let(:old_status) { create(:work_item_custom_status, category: :in_progress, name: "Custom in progress") }

        it "returns the in progress status" do
          expected_result = build_stubbed(:work_item_system_defined_status, :in_progress)
          expect(service.id).to eq(expected_result.id)
        end
      end

      context "when doesn't match by name and state or category" do
        let(:old_status) { create(:work_item_custom_status, category: :triage, name: "Custom Triage") }

        it "returns the default status for the old status state" do
          expected_result = build_stubbed(:work_item_system_defined_status, :to_do)
          expect(service.id).to eq(expected_result.id)
        end
      end
    end
  end

  context "when new lifecycle is custom" do
    let(:triage_status) { create(:work_item_custom_status, category: :triage, name: "Custom Triage") }
    let(:to_do_status) { create(:work_item_custom_status, category: :to_do, name: "Custom To Do") }
    let(:in_progress_status) { create(:work_item_custom_status, category: :in_progress, name: "Custom in progress") }
    let(:done_status) { create(:work_item_custom_status, category: :done, name: "Custom Done") }
    let(:canceled_status) { create(:work_item_custom_status, category: :canceled, name: "Custom Canceled") }
    let(:duplicate_status) { create(:work_item_custom_status, category: :canceled, name: "Custom Duplicated") }
    let!(:new_lifecycle) do
      create(:work_item_custom_lifecycle,
        default_open_status: to_do_status,
        default_closed_status: done_status,
        default_duplicate_status: duplicate_status,
        statuses: [triage_status, to_do_status, in_progress_status, done_status, canceled_status, duplicate_status])
    end

    context "and old_status is system defined" do
      context "when matches by name and state" do
        let(:old_status) { build_stubbed(:work_item_system_defined_status, :to_do) }

        before do
          to_do_status.update!(name: "To do")
        end

        it { is_expected.to eq(to_do_status) }
      end

      context "when only matches by name but not state" do
        let(:old_status) { build_stubbed(:work_item_system_defined_status, :duplicate) }

        before do
          canceled_status.update!(name: "Won't do", category: :done)
        end

        it { is_expected.not_to eq(canceled_status) }
      end

      context "when matches by category" do
        let(:old_status) { build_stubbed(:work_item_system_defined_status, :in_progress) }

        it { is_expected.to eq(in_progress_status) }
      end

      context "when doesn't match by name and state or category" do
        let(:old_status) { build_stubbed(:work_item_system_defined_status, :wont_do) }

        before do
          canceled_status.update!(category: :done)
          duplicate_status.update!(category: :done)
        end

        it "returns the default status for the old status state" do
          expect(service).to eq(done_status)
        end
      end
    end

    context "when old_status is custom" do
      context "and matches by name and state" do
        let(:old_status) { create(:work_item_custom_status, category: :to_do, name: "Custom To Do") }

        it { is_expected.to eq(to_do_status) }
      end

      context "and matches by name and state case insensitive" do
        let(:old_status) { create(:work_item_custom_status, category: :to_do, name: "custom to do") }

        it { is_expected.to eq(to_do_status) }
      end

      context "and matches by name but not state" do
        let(:old_status) { create(:work_item_custom_status, category: :done, name: "Custom To Do") }

        it { is_expected.not_to eq(to_do_status) }
      end

      context "when matches by category" do
        let(:old_status) { create(:work_item_custom_status, category: :in_progress, name: "Progress") }

        it { is_expected.to eq(in_progress_status) }
      end

      context "when doesn't match by name and state or category" do
        let(:old_status) { create(:work_item_custom_status, category: :in_progress, name: "Progress") }

        before do
          in_progress_status.destroy!
          new_lifecycle.reload
        end

        it "returns the default status for the old status state" do
          expect(service).to eq(new_lifecycle.default_open_status)
        end
      end
    end
  end
end
