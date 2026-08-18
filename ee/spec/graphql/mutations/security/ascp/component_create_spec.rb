# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Security::Ascp::ComponentCreate, feature_category: :static_application_security_testing do
  include GraphqlHelpers

  specify { expect(described_class).to require_graphql_authorizations(:create_ascp_component) }

  it 'has expected arguments' do
    expect(described_class.arguments.keys).to match_array(
      %w[projectPath title subDirectory description expectedUserBehavior scanId clientMutationId]
    )
  end

  it 'has expected fields' do
    expect(described_class).to have_graphql_fields(:component, :errors, :client_mutation_id)
  end

  it_behaves_like 'an ASCP mutation with scopes', field_name: 'component'
end
