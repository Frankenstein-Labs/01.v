# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Entities::LegacyEpicResourceLabelEvent, feature_category: :portfolio_management do
  let_it_be(:epic) { create(:epic) }
  let_it_be(:event) { create(:resource_label_event, epic: epic) }

  subject(:entity_json) { described_class.new(event, epic: epic).as_json }

  it 'inherits fields from ResourceLabelEvent' do
    expect(entity_json).to include(:id, :user, :created_at, :resource_type, :resource_id, :label, :action)
  end

  it 'returns resource_type as Epic' do
    expect(entity_json[:resource_type]).to eq('Epic')
  end

  it 'returns resource_id as the epic id' do
    expect(entity_json[:resource_id]).to eq(epic.id)
  end

  it 'returns resource_work_item_id as the work item id' do
    expect(entity_json[:resource_work_item_id]).to eq(epic.work_item.id)
  end
end
