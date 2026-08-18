# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Container Virtual Registries (JavaScript fixtures)', feature_category: :virtual_registry do
  include GraphqlHelpers
  include JavaScriptFixturesHelpers

  let_it_be(:group, freeze: false) { create(:group) }
  let_it_be(:user, freeze: false) { create(:user) }
  let_it_be(:registry, freeze: false) { create(:virtual_registries_container_registry, group: group) }

  describe GraphQL::Query, type: :request do
    base_path = 'packages_and_registries/virtual_registries/graphql/queries'
    get_container_registries_query_path = "#{base_path}/get_container_virtual_registries.query.graphql"

    before_all do
      group.add_guest(user)
    end

    before do
      stub_config(dependency_proxy: { enabled: true })
      stub_licensed_features(container_virtual_registry: true)
    end

    context 'when user requests registries list' do
      let(:query) { get_graphql_query_as_string(get_container_registries_query_path, ee: true) }
      let(:variables) do
        {
          groupPath: group.full_path,
          first: 5
        }
      end

      it "ee/graphql/#{get_container_registries_query_path}.json" do
        post_graphql(query, current_user: user, variables: variables)

        expect_graphql_errors_to_be_empty
      end
    end
  end
end
