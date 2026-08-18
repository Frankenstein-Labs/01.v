# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'GraphQL AI Domain Settings', '(JavaScript fixtures)', :with_current_organization,
  feature_category: :duo_setting do
  include ApiHelpers
  include GraphqlHelpers
  include JavaScriptFixturesHelpers

  let_it_be(:admin, freeze: false) { create(:admin) }

  let(:query_path) { 'ai/settings/graphql/queries/get_ai_domain_settings.query.graphql' }
  let(:query) { get_graphql_query_as_string(query_path, ee: true) }

  after do
    ::Ai::Setting.for_organization(current_organization).update!(allowed_domains: [], denied_domains: [])
  end

  describe GraphQL::Query, type: :request do
    it 'graphql/ai/domain_settings/allowed_empty.json' do
      ::Ai::Setting.for_organization(current_organization).update!(allowed_domains: [])

      post_graphql(query, current_user: admin, variables: { type: 'ALLOWED' })

      expect_graphql_errors_to_be_empty
    end

    it 'graphql/ai/domain_settings/allowed_populated.json' do
      ::Ai::Setting.for_organization(current_organization).update!(allowed_domains: %w[example.com gitlab.com])

      post_graphql(query, current_user: admin, variables: { type: 'ALLOWED' })

      expect_graphql_errors_to_be_empty
    end

    it 'graphql/ai/domain_settings/denied_empty.json' do
      ::Ai::Setting.for_organization(current_organization).update!(denied_domains: [])

      post_graphql(query, current_user: admin, variables: { type: 'DENIED' })

      expect_graphql_errors_to_be_empty
    end

    it 'graphql/ai/domain_settings/denied_populated.json' do
      ::Ai::Setting.for_organization(current_organization).update!(denied_domains: %w[evil.com])

      post_graphql(query, current_user: admin, variables: { type: 'DENIED' })

      expect_graphql_errors_to_be_empty
    end

    it 'graphql/ai/domain_settings/allowed_searched.json' do
      ::Ai::Setting.for_organization(current_organization).update!(allowed_domains: %w[example.com gitlab.com
        gitlab.org other.net])

      post_graphql(query, current_user: admin, variables: { type: 'ALLOWED', search: 'gitlab' })

      expect_graphql_errors_to_be_empty
    end

    it 'graphql/ai/domain_settings/allowed_paginated.json' do
      domains = (1..25).map { |i| "domain#{i}.example.com" }
      ::Ai::Setting.for_organization(current_organization).update!(allowed_domains: domains)

      post_graphql(query, current_user: admin, variables: { type: 'ALLOWED', first: 20 })

      expect_graphql_errors_to_be_empty
    end
  end
end
