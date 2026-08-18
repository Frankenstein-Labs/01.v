# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../app/events/work_items/status_changed_event'
require_relative '../../../../spec/support/shared_examples/events/cloud_event_with_schema_shared_examples'

RSpec.describe WorkItems::StatusChangedEvent, feature_category: :team_planning do
  let_it_be(:user) { create(:user) }
  let_it_be(:work_item) { create(:work_item) }

  let(:status) { build(:work_item_system_defined_status, :in_progress) }

  describe '.build' do
    it 'returns a valid StatusChangedEvent', :aggregate_failures do
      event = described_class.build(work_item: work_item, current_user: user, status: status)
      expect(event.event_category).to eq(:work_items)
      expect(event.event_type).to eq(:status_changed)
    end

    context 'when current_user is nil' do
      it 'returns nil' do
        expect(described_class.build(work_item: work_item, current_user: nil, status: status)).to be_nil
      end
    end

    context 'when status is nil' do
      it 'returns nil' do
        expect(described_class.build(work_item: work_item, current_user: user, status: nil)).to be_nil
      end
    end
  end

  it_behaves_like 'a cloud event with schema',
    valid_data: {
      work_item_id: 1,
      work_item_iid: 10,
      project_id: 100,
      namespace_id: 1000,
      work_item_type: 'issue',
      confidential: false,
      status: {
        name: 'In progress',
        category: 'in_progress'
      }
    },
    missing_required: %i[work_item_id work_item_iid namespace_id work_item_type confidential status],
    invalid_types: {
      work_item_id: 'not_an_integer',
      work_item_iid: 'not_an_integer',
      namespace_id: 'not_an_integer',
      status: 'not_an_object'
    }
end
