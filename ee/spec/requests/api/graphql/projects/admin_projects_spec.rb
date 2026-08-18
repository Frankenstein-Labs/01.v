# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting a collection of projects to admin', feature_category: :groups_and_projects do
  it_behaves_like 'getting a collection of projects EE' do
    let(:field) { :admin_projects }
    let(:query) do
      graphql_query_for(
        field,
        filters,
        "nodes { ... on Project { #{project_fields} } }"
      )
    end

    it_behaves_like 'projects graphql query with SAML session filtering'
  end
end
