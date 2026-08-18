# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.spdxLicenses', feature_category: :dependency_management do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }

  let(:fields) do
    <<~FIELDS
      name
      spdxIdentifier
      url
    FIELDS
  end

  let(:query) { graphql_query_for(:spdx_licenses, {}, fields) }

  context 'when user is authenticated' do
    before do
      post_graphql(query, current_user: current_user)
    end

    it 'returns a list of SPDX licenses' do
      licenses = graphql_data_at(:spdx_licenses)

      expect(licenses).to be_an(Array)

      license = licenses.find { |l| l['spdxIdentifier'] == 'MIT' }

      expect(license).to eq(
        'name' => 'MIT License',
        'spdxIdentifier' => 'MIT',
        'url' => 'https://spdx.org/licenses/MIT.html'
      )
    end
  end

  context 'when user is not authenticated' do
    before do
      post_graphql(query)
    end

    it 'returns nil' do
      expect(graphql_data_at(:spdx_licenses)).to be_nil
    end
  end
end
