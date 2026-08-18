# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ai::Catalog::ThirdPartyFlow::Delete, feature_category: :workflow_catalog do
  include GraphqlHelpers

  subject(:mutation) { described_class }

  it { is_expected.to have_graphql_name('AiCatalogThirdPartyFlowDelete') }

  it { expect(described_class).to require_graphql_authorizations(:delete_ai_catalog_item) }

  it { is_expected.to have_graphql_fields(:success, :errors, :client_mutation_id) }

  it { is_expected.to have_graphql_arguments(:id, :force_hard_delete, :client_mutation_id) }
end
