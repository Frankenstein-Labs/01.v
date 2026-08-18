# frozen_string_literal: true

require "spec_helper"

RSpec.describe WorkItems::RolledupDates::UpdateMilestoneRelatedWorkItemDatesEventHandler, feature_category: :team_planning do
  subject(:handler) { described_class.new }

  let_it_be(:service_class) { ::WorkItems::Widgets::RolledupDatesService::HierarchiesUpdateService }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:milestone) { create(:milestone, project: project) }
  let_it_be(:milestone_work_items) { create_list(:work_item, 2, project: project, milestone: milestone) }
  # Just to ensure that work_items not associated with the given milestone are used
  let_it_be(:other_work_item) { create(:work_item, project: project) }

  let(:event) { instance_double(Milestones::MilestoneUpdatedEvent, data: { id: milestone.id }) }

  describe ".can_handle?" do
    let(:milestone) { create(:milestone, :on_project, project: project) }

    context "when project milestone" do
      it "returns false if no expected widget or attribute changed" do
        expect(described_class.can_handle?(event)).to be(false)
      end

      it "returns true when expected attribute changed" do
        described_class::UPDATE_TRIGGER_ATTRIBUTES.each do |attribute|
          event = instance_double(Milestones::MilestoneUpdatedEvent, data: {
            id: milestone.id,
            updated_attributes: [attribute]
          })

          expect(described_class.can_handle?(event)).to be(true)
        end
      end
    end

    context "when group milestone" do
      let(:milestone) { create(:milestone, :on_group, group: group) }

      it "returns false if no expected widget or attribute changed" do
        expect(described_class.can_handle?(event)).to be(false)
      end

      it "returns true when expected attribute changed" do
        described_class::UPDATE_TRIGGER_ATTRIBUTES.each do |attribute|
          event = instance_double(Milestones::MilestoneUpdatedEvent, data: {
            id: milestone.id,
            updated_attributes: [attribute]
          })

          expect(described_class.can_handle?(event)).to be(true)
        end
      end
    end
  end

  describe ".handle_event" do
    it "calls the service with the associated work_items" do
      expect_next_instance_of(service_class, match_array(milestone_work_items)) do |service|
        expect(service).to receive(:execute)
      end

      handler.handle_event(event)
    end
  end
end
