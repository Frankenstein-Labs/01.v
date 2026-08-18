# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::WorkItems::Instrumentation::EventMappings, feature_category: :portfolio_management do
  describe '.events_for' do
    let(:work_item) { instance_double(WorkItem) }
    let(:old_associations) { {} }
    let(:previous_changes) { {} }

    before do
      allow(work_item).to receive(:previous_changes).and_return(previous_changes)
    end

    subject(:events) { described_class.events_for(work_item: work_item, old_associations: old_associations) }

    context 'when marked as duplicate' do
      let(:old_status) { instance_double(WorkItems::Statuses::SystemDefined::Status, name: 'To do') }
      let(:new_status) { instance_double(WorkItems::Statuses::SystemDefined::Status, name: 'Duplicate') }
      let(:current_status_wrapper) { instance_double(WorkItems::Statuses::CurrentStatus, status: new_status) }
      let(:old_associations) { { status: old_status } }

      before do
        allow(work_item).to receive(:current_status).and_return(current_status_wrapper)
      end

      it 'returns work_item_marked_as_duplicate' do
        expect(events).to contain_exactly('work_item_marked_as_duplicate')
      end

      it 'uses the accessor to retrieve current status' do
        mapping = described_class::ASSOCIATION_MAPPINGS.find { |m| m[:key] == :status }
        expect(mapping[:accessor]).not_to be_nil

        result = mapping[:accessor].call(work_item)
        expect(result).to eq(new_status)
      end
    end

    context 'when status changes but not to duplicate' do
      let(:old_status) { instance_double(WorkItems::Statuses::SystemDefined::Status, name: 'In progress') }
      let(:new_status) { instance_double(WorkItems::Statuses::SystemDefined::Status, name: 'Done') }
      let(:current_status_wrapper) { instance_double(WorkItems::Statuses::CurrentStatus, status: new_status) }
      let(:old_associations) { { status: old_status } }

      before do
        allow(work_item).to receive(:current_status).and_return(current_status_wrapper)
      end

      it 'does not return marked_as_duplicate event' do
        expect(events).not_to include('work_item_marked_as_duplicate')
      end
    end

    context 'when marked_as_duplicate compare function has nil values' do
      let(:mapping) { described_class::ASSOCIATION_MAPPINGS.find { |m| m[:key] == :status } }
      let(:duplicate_status) { instance_double(WorkItems::Statuses::SystemDefined::Status, name: 'Duplicate') }
      let(:todo_status) { instance_double(WorkItems::Statuses::SystemDefined::Status, name: 'To do') }

      it 'returns true when old is nil and new is Duplicate' do
        expect(mapping[:compare].call(nil, duplicate_status)).to be true
      end

      it 'returns false when new is nil' do
        expect(mapping[:compare].call(todo_status, nil)).to be false
      end

      it 'returns false when both are nil' do
        expect(mapping[:compare].call(nil, nil)).to be false
      end

      it 'returns false when old is Duplicate and new is nil' do
        old_duplicate = instance_double(WorkItems::Statuses::SystemDefined::Status, name: 'Duplicate')
        expect(mapping[:compare].call(old_duplicate, nil)).to be false
      end
    end

    context 'when marked_as_duplicate accessor function has nil values' do
      let(:mapping) { described_class::ASSOCIATION_MAPPINGS.find { |m| m[:key] == :status } }
      let(:test_work_item) { instance_double(WorkItem) }

      it 'returns nil when current_status is nil' do
        allow(test_work_item).to receive(:current_status).and_return(nil)

        result = mapping[:accessor].call(test_work_item)
        expect(result).to be_nil
      end

      it 'returns nil when current_status.status is nil' do
        current_status_without_status = instance_double(WorkItems::Statuses::CurrentStatus, status: nil)
        allow(test_work_item).to receive(:current_status).and_return(current_status_without_status)

        result = mapping[:accessor].call(test_work_item)
        expect(result).to be_nil
      end

      it 'returns the status when both current_status and status exist' do
        status = instance_double(WorkItems::Statuses::SystemDefined::Status, name: 'Done')
        current_status_with_status = instance_double(WorkItems::Statuses::CurrentStatus, status: status)
        allow(test_work_item).to receive(:current_status).and_return(current_status_with_status)

        result = mapping[:accessor].call(test_work_item)
        expect(result).to eq(status)
      end
    end
  end
end
