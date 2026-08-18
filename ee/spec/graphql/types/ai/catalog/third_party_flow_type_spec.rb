# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['AiCatalogThirdPartyFlowVersion'], feature_category: :system_access do
  let_it_be(:current_user) { create(:user) }
  let_it_be(:project) { create(:project, maintainers: [current_user]) }
  let_it_be_with_reload(:item) { create(:ai_catalog_item, :third_party_flow, :public, project: project) }
  let_it_be(:current_organization) { item.organization }

  let(:query) do
    %{
      query {
        aiCatalogItem(id: "#{item.to_global_id}") {
          latestVersion {
            ... on #{described_class.graphql_name} {
              definition
            }
          }
        }
      }
    }
  end

  let(:returned_definition) { subject.dig('data', 'aiCatalogItem', 'latestVersion', 'definition') }

  subject { GitlabSchema.execute(query, context: { current_organization:, current_user: }).as_json }

  specify { expect(described_class.graphql_name).to eq('AiCatalogThirdPartyFlowVersion') }
  specify { expect(described_class.interfaces).to include(::Types::Ai::Catalog::VersionInterface) }

  it_behaves_like 'AI catalog version definition field'
  it_behaves_like 'AI catalog version definition field with yaml_definition not present'
end
