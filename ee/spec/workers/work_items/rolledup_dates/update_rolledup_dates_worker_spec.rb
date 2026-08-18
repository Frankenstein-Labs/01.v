# frozen_string_literal: true

require "spec_helper"

RSpec.describe WorkItems::RolledupDates::UpdateRolledupDatesWorker, feature_category: :portfolio_management do
  describe "#perform" do
    it "updates the hierarchy tree" do
      work_item = create(:work_item, :epic)

      expect_next_instance_of(
        ::WorkItems::Widgets::RolledupDatesService::HierarchiesUpdateService,
        WorkItem.id_in(work_item.id)
      ) do |service|
        expect(service).to receive(:execute)
      end

      described_class.new.perform(work_item.id)
    end
  end
end
