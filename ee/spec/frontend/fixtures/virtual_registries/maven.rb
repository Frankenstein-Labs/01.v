# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Maven Virtual Registries (JavaScript fixtures)', feature_category: :virtual_registry do
  include GraphqlHelpers
  include JavaScriptFixturesHelpers

  let_it_be(:group, freeze: false) { create(:group) }
  let_it_be(:user, freeze: false) { create(:user) }
  let_it_be(:registry, freeze: false) { create(:virtual_registries_packages_maven_registry, group: group) }
  let_it_be(:upstream, freeze: false) do
    create(:virtual_registries_packages_maven_upstream, registries: [registry], metadata_cache_validity_hours: 48)
  end

  let_it_be(:cache_entry, freeze: false) do
    create(:virtual_registries_packages_maven_cache_remote_entry, upstream:)
  end

  describe GraphQL::Query, type: :request do
    base_path = 'packages_and_registries/virtual_registries/graphql/queries'
    get_maven_upstream_summary_query_path = "#{base_path}/get_maven_upstream_summary.query.graphql"
    get_maven_virtual_registry_upstreams_path = "#{base_path}/get_maven_virtual_registry_upstreams.query.graphql"
    get_maven_registries_query_path = "#{base_path}/get_maven_virtual_registries.query.graphql"
    get_maven_upstream_cache_entries_count_query_path =
      "#{base_path}/get_maven_upstream_cache_entries_count.query.graphql"
    get_maven_upstream_cache_entries_query_path = "#{base_path}/get_maven_upstream_cache_entries.query.graphql"

    before_all do
      group.add_guest(user)
    end

    before do
      stub_config(dependency_proxy: { enabled: true })
      stub_licensed_features(packages_virtual_registry: true)
    end

    context 'when user requests registries list' do
      let(:query) { get_graphql_query_as_string(get_maven_registries_query_path, ee: true) }
      let(:variables) do
        {
          groupPath: group.full_path,
          first: 5
        }
      end

      it "ee/graphql/#{get_maven_registries_query_path}.json" do
        post_graphql(query, current_user: user, variables: variables)

        expect_graphql_errors_to_be_empty
      end
    end

    context 'when user requests upstream summary' do
      let(:query) { get_graphql_query_as_string(get_maven_upstream_summary_query_path, ee: true) }
      let(:variables) { { id: upstream.to_gid.to_s } }

      it "ee/graphql/#{get_maven_upstream_summary_query_path}.json" do
        post_graphql(query, current_user: user, variables: variables)

        expect_graphql_errors_to_be_empty
      end
    end

    context 'when user requests registry and registry_upstreams' do
      let(:query) { get_graphql_query_as_string(get_maven_virtual_registry_upstreams_path, ee: true) }
      let(:variables) { { id: registry.to_gid.to_s } }

      before do
        3.times do |i|
          create(:virtual_registries_packages_maven_upstream,
            name: "upstream#{i}",
            registries: [registry],
            metadata_cache_validity_hours: 48)
        end
      end

      it "ee/graphql/#{get_maven_virtual_registry_upstreams_path}.json" do
        post_graphql(query, current_user: user, variables: variables)

        expect_graphql_errors_to_be_empty
      end
    end

    context 'when user requests upstream cache entries count' do
      let(:query) { get_graphql_query_as_string(get_maven_upstream_cache_entries_count_query_path, ee: true) }
      let(:variables) { { id: upstream.to_gid.to_s } }

      it "ee/graphql/#{get_maven_upstream_cache_entries_count_query_path}.json" do
        post_graphql(query, current_user: user, variables: variables)

        expect_graphql_errors_to_be_empty
      end
    end

    context 'when user requests upstream cache entries' do
      let(:query) { get_graphql_query_as_string(get_maven_upstream_cache_entries_query_path, ee: true) }
      let(:variables) { { id: upstream.to_gid.to_s } }

      it "ee/graphql/#{get_maven_upstream_cache_entries_query_path}.json" do
        post_graphql(query, current_user: user, variables: variables)

        expect_graphql_errors_to_be_empty
      end
    end
  end
end
