# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::ThirdPartyFlows::DestroyService, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers

  before do
    enable_ai_catalog
  end

  it_behaves_like Ai::Catalog::Items::BaseDestroyService do
    let_it_be_with_reload(:incorrect_item_type) { create(:ai_catalog_flow, project: project) }
    let!(:item) { create(:ai_catalog_third_party_flow, :public, project: project) }
    let(:not_found_error) { 'Third Party Flow not found' }

    let(:expected_delete_event_properties) do
      {
        label: 'third_party_flow',
        item_type: 'custom_external_agent',
        item_version: item.latest_version.version,
        custom_item_id: item.id,
        hard_deleted: 'false'
      }
    end

    describe 'ai_catalog_third_party_flows feature flag' do
      before do
        project.add_maintainer(user)
      end

      it_behaves_like 'a successful request'

      context 'when ai_catalog_third_party_flows feature flag is disabled' do
        before do
          stub_feature_flags(ai_catalog_third_party_flows: false)
        end

        it_behaves_like 'returns insufficient permissions error'
      end
    end
  end
end
