# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Ai::Catalog::FlowVersionType, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:project) { create(:project, maintainers: [current_user]) }
  # `freeze: false` is required in this spec: one or more `let_it_be` subjects
  # cannot be frozen by default (deep_freeze traversal failure, a non-AR
  # subject, or an in-memory mutation that survives reload/refind). Do not
  # drop these opt-outs or convert them to `let_it_be_with_reload`/`refind`
  # (see gitlab-org/gitlab#602925).
  let_it_be(:item, freeze: false) { create(:ai_catalog_item, :flow, :public, project: project) }

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

  before do
    enable_ai_catalog
  end

  subject { GitlabSchema.execute(query, context: { current_organization:, current_user: }).as_json }

  specify { expect(described_class.graphql_name).to eq('AiCatalogFlowVersion') }
  specify { expect(described_class.interfaces).to include(::Types::Ai::Catalog::VersionInterface) }

  it_behaves_like 'AI catalog version definition field'
end
