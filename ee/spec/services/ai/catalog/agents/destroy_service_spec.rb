# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Agents::DestroyService, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers

  before do
    enable_ai_catalog
  end

  it_behaves_like Ai::Catalog::Items::BaseDestroyService do
    let_it_be_with_reload(:incorrect_item_type) { create(:ai_catalog_flow, project: project) }
    let!(:item) { create(:ai_catalog_agent, :public, project: project) }
    let(:not_found_error) { 'Agent not found' }

    let(:expected_delete_event_properties) do
      {
        label: 'agent',
        item_type: 'custom_agent',
        item_version: item.latest_version.version,
        item_schema_version: 'v1',
        custom_item_id: item.id,
        tools: 'gitlab_blob_search',
        hard_deleted: 'false'
      }
    end
  end
end
