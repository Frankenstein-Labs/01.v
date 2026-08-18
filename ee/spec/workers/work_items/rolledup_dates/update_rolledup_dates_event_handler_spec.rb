# frozen_string_literal: true

require "spec_helper"

RSpec.describe WorkItems::RolledupDates::UpdateRolledupDatesEventHandler, feature_category: :portfolio_management do
  describe ".can_handle_update?", :aggregate_failures do
    it "returns false if no expected widget or attribute changed" do
      event = ::WorkItems::WorkItemCreatedEvent.new(data: { id: 1, namespace_id: 2 })
      expect(described_class.can_handle_update?(event)).to be(false)
    end

    it "returns true when expected attribute changed" do
      described_class::UPDATE_TRIGGER_ATTRIBUTES.each do |attribute|
        event = ::WorkItems::WorkItemCreatedEvent.new(data: {
          id: 1,
          namespace_id: 2,
          updated_attributes: [attribute]
        })

        expect(described_class.can_handle_update?(event)).to be(true)
      end
    end

    it "returns true when expected widget changed" do
      described_class::UPDATE_TRIGGER_WIDGETS.each do |widget|
        event = ::WorkItems::WorkItemCreatedEvent.new(data: {
          id: 1,
          namespace_id: 2,
          updated_widgets: [widget]
        })

        expect(described_class.can_handle_update?(event)).to be(true)
      end
    end
  end

  describe "handle_event" do
    let_it_be(:service_class) { ::WorkItems::Widgets::RolledupDatesService::HierarchiesUpdateService }

    let_it_be(:work_items) do
      create_list(:work_item, 3)
    end

    it "does nothing when the work item no longer exists" do
      expect(service_class).not_to receive(:new)

      event = ::WorkItems::WorkItemCreatedEvent.new(data: {
        id: non_existing_record_id,
        namespace_id: 1
      })

      expect { described_class.new.handle_event(event) }.not_to raise_error
    end

    shared_examples "updates the work_item hierarchy" do
      specify do
        expect_next_instance_of(service_class) do |service|
          expect(service).to receive(:execute)
        end

        event = ::WorkItems::WorkItemCreatedEvent.new(data: event_data)

        described_class.new.handle_event(event)
      end
    end

    it_behaves_like "updates the work_item hierarchy" do
      let(:event_data) { { id: work_items[0].id, namespace_id: 1 } }
    end

    it_behaves_like "updates the work_item hierarchy" do
      let(:event_data) do
        {
          id: work_items[0].id,
          work_item_parent_id: work_items[1].id,
          namespace_id: 1
        }
      end
    end

    it_behaves_like "updates the work_item hierarchy" do
      let(:event_data) do
        {
          id: work_items[0].id,
          work_item_parent_id: work_items[1].id,
          previous_work_item_parent_id: work_items[2].id,
          namespace_id: 1
        }
      end
    end
  end
end
