# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ai::Catalog::ThirdPartyFlow::Update, feature_category: :workflow_catalog do
  include GraphqlHelpers

  subject(:mutation) { described_class }

  it { is_expected.to have_graphql_name('AiCatalogThirdPartyFlowUpdate') }

  it { expect(described_class).to require_graphql_authorizations(:admin_ai_catalog_item) }

  it { is_expected.to have_graphql_fields(:item, :errors, :client_mutation_id) }

  it 'has expected arguments' do
    is_expected.to have_graphql_arguments(
      :id,
      :description,
      :name,
      :public,
      :visibility,
      :release,
      :definition,
      :version_bump,
      :client_mutation_id
    )
  end
end
