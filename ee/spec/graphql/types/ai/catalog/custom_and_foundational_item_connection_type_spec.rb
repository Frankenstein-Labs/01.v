# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Ai::Catalog::CustomAndFoundationalItemConnectionType, :with_current_organization, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:ai_catalog_item) { create(:ai_catalog_agent, :public) }

  let(:args) { {} }

  let(:query) do
    %(
      {
        aiCatalogCustomAndFoundationalItems {
          nodes {
            ... on AiCatalogItem {
              id
              name
              itemType
              description
              softDeletedAt
            }

            ... on AiFoundationalChatAgent {
              id
              name
              description
            }
          }
        }
      }
    )
  end

  subject(:response) { GitlabSchema.execute(query, context: { current_organization: }) }

  before do
    enable_ai_catalog
  end

  describe '#nodes', :saas do
    it 'converts foundational agents to Ai::FoundationalChatAgent' do
      expect(::Ai::FoundationalChatAgent).to receive(:find_by).at_least(:once).and_call_original
      response

      expect(response.to_h.dig('data', 'aiCatalogCustomAndFoundationalItems', 'nodes').pluck('id'))
        .to include(ai_catalog_item.to_global_id.to_s, "gid://gitlab/Ai::FoundationalChatAgent/chat")
    end
  end
end
