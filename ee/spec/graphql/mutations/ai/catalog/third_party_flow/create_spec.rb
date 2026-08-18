# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ai::Catalog::ThirdPartyFlow::Create, feature_category: :workflow_catalog do
  include GraphqlHelpers

  subject(:mutation) { described_class }

  it { is_expected.to have_graphql_name('AiCatalogThirdPartyFlowCreate') }

  it { expect(described_class).to require_graphql_authorizations(:create_ai_catalog_third_party_flow) }

  it { is_expected.to have_graphql_fields(:item, :errors, :client_mutation_id) }

  it 'has expected arguments' do
    is_expected.to have_graphql_arguments(
      :description,
      :name,
      :project_id,
      :public,
      :visibility,
      :release,
      :definition,
      :client_mutation_id
    )
  end
end
