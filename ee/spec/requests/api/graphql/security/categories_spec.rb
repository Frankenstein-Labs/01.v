# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Group Security Categories', feature_category: :security_asset_inventories do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }

  before do
    stub_licensed_features(security_attributes: true)
  end

  describe 'Query security categories' do
    let(:query) do
      <<~QUERY
        query($fullPath: ID!) {
          group(fullPath: $fullPath) {
            id
            securityCategories {
              name
              description
              editableState
              id
              multipleSelection
              templateType
              securityAttributes {
                name
                color
                description
                editableState
                id
              }
            }
          }
        }
      QUERY
    end

    let(:variables) { { fullPath: group.full_path } }

    subject(:execute_query) do
      post_graphql(query, current_user: current_user, variables: variables)
    end

    context 'when user does not have permission' do
      it 'returns null security categories' do
        execute_query

        expect(graphql_data['group']).not_to be_nil
        expect(graphql_data['group']['securityCategories']).to be_nil
      end
    end

    context 'when user has permission' do
      before_all do
        group.add_owner(current_user)
      end

      context 'when no custom categories exist' do
        it 'returns default categories with namespace_id populated' do
          execute_query
          expect(graphql_errors).to be_nil

          categories = graphql_data_at(:group, :securityCategories)
          expect(categories).not_to be_empty

          expect(categories).to include(
            hash_including(
              'name' => be_present,
              'description' => be_present,
              'editableState' => be_present,
              'id' => be_present,
              'multipleSelection' => be_in([true, false]),
              'templateType' => be_present
            )
          )

          categories.each do |category|
            expect(category['securityAttributes']).to be_an(Array)
            next unless category['securityAttributes'].any?

            expect(category['securityAttributes'].first).to include(
              'name' => be_present,
              'color' => be_present,
              'description' => be_present,
              'editableState' => be_present,
              'id' => be_present
            )
          end
        end
      end

      context 'when custom categories exist' do
        let_it_be(:custom_category) do
          create(:security_category,
            namespace: group,
            name: 'Custom Security Category',
            description: 'A custom category for testing',
            multiple_selection: true)
        end

        let_it_be(:security_attribute) do
          create(:security_attribute,
            security_category: custom_category,
            namespace: group,
            name: 'Critical',
            color: '#FF0000',
            description: 'Critical security attribute')
        end

        it 'returns custom categories' do
          execute_query
          expect(graphql_errors).to be_nil

          categories = graphql_data_at(:group, :securityCategories)
          custom = categories.first
          expect(custom).to include(
            'name' => 'Custom Security Category',
            'description' => 'A custom category for testing',
            'multipleSelection' => true,
            'id' => custom_category.to_gid.to_s
          )

          expect(custom['securityAttributes']).to include(
            hash_including(
              'name' => 'Critical',
              'color' => '#FF0000',
              'description' => 'Critical security attribute',
              'id' => security_attribute.to_gid.to_s
            )
          )
        end
      end
    end
  end
end
