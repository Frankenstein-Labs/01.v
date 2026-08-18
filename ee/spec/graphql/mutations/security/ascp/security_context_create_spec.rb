# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Security::Ascp::SecurityContextCreate, feature_category: :static_application_security_testing do
  include GraphqlHelpers

  specify { expect(described_class).to require_graphql_authorizations(:create_ascp_security_context) }

  it 'has expected arguments' do
    expect(described_class.arguments.keys).to match_array(
      %w[
        projectPath componentId scanId summary authenticationModel
        authorizationModel dataSensitivity guidelines clientMutationId
      ]
    )
  end

  it 'has expected fields' do
    expect(described_class).to have_graphql_fields(:security_context, :errors, :client_mutation_id)
  end
end
