# frozen_string_literal: true

require "spec_helper"

RSpec.describe WorkItems::RolledupDates::UpdateMultipleRolledupDatesWorker, feature_category: :portfolio_management do
  describe "#perform" do
    it "does nothing when no work_items are found" do
      expect(::WorkItems::Widgets::RolledupDatesService::HierarchiesUpdateService)
        .not_to receive(:new)

      described_class.new.perform([non_existing_record_id])
    end

    it "updates the hierarchy tree" do
      work_items = create_list(:work_item, 2, :epic)

      expect_next_instance_of(
        ::WorkItems::Widgets::RolledupDatesService::HierarchiesUpdateService,
        match_array(work_items)
      ) do |service|
        expect(service).to receive(:execute)
      end

      described_class.new.perform(work_items.pluck(:id))
    end
  end
end
