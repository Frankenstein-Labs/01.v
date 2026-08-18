# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Security::Ascp::ComponentsResolver, feature_category: :static_application_security_testing do
  include GraphqlHelpers

  it { expect(described_class).to require_graphql_authorizations(:read_ascp_component) }

  it 'has expected arguments' do
    expect(described_class.arguments.keys).to contain_exactly('title', 'subDirectory')
  end
end
