# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.projectComponentUsages', feature_category: :pipeline_composition do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project_1) { create(:project, group: group) }
  let_it_be(:project_2) { create(:project, group: group) }
  let_it_be(:project_3) { create(:project, group: group) }
  let_it_be(:component_1) { create(:ci_catalog_resource_component, name: 'component1') }
  let_it_be(:component_2) { create(:ci_catalog_resource_component, name: 'component2') }
  let_it_be(:component_3) { create(:ci_catalog_resource_component, name: 'component3') }

  let_it_be(:usage_1) do
    create(:catalog_resource_component_last_usage, component: component_1, used_by_project_id: project_1.id)
  end

  let_it_be(:usage_2) do
    create(:catalog_resource_component_last_usage, component: component_2, used_by_project_id: project_2.id)
  end

  let_it_be(:usage_3) do
    create(:catalog_resource_component_last_usage, component: component_3, used_by_project_id: project_3.id)
  end

  let(:query) do
    <<~GQL
      query {
        projects {
          nodes {
            componentUsages {
              nodes {
                name
                version
                lastUsedDate
              }
            }
          }
        }
      }
    GQL
  end

  shared_examples 'a list of projects and their component usage' do
    it 'returns list of projects using components' do
      post_graphql(query, current_user: current_user)

      project_data = graphql_data['projects']['nodes']
      projects_with_component_usages = project_data.select { |p| p['componentUsages']['nodes'].present? }
      expect(projects_with_component_usages.count).to eq(3)
      expect(projects_with_component_usages).to contain_exactly(
        {
          'componentUsages' => {
            'nodes' => [{
              'name' => component_3.name,
              'version' => component_3.version.name,
              'lastUsedDate' => usage_3.last_used_date.iso8601
            }]
          }
        },
        {
          'componentUsages' => {
            'nodes' => [{
              'name' => component_2.name,
              'version' => component_2.version.name,
              'lastUsedDate' => usage_2.last_used_date.iso8601
            }]
          }
        },
        {
          'componentUsages' => {
            'nodes' => [{
              'name' => component_1.name,
              'version' => component_1.version.name,
              'lastUsedDate' => usage_1.last_used_date.iso8601
            }]
          }
        }
      )
    end
  end

  context 'when there is neither license nor sass features' do
    before_all do
      group.add_maintainer(current_user)
    end

    before do
      stub_licensed_features(ci_component_usages_in_projects: false)
      stub_saas_features(ci_component_usages_in_projects: false)
    end

    it 'returns nil' do
      post_graphql(query, current_user: current_user)

      projects_data = graphql_data['projects']['nodes']
      expect(projects_data).to be_present
      expect(projects_data).to all(include('componentUsages' => nil))
    end
  end

  context 'when licensed' do
    before do
      stub_licensed_features(ci_component_usages_in_projects: true)
    end

    context 'when on Saas' do
      before do
        stub_saas_features(ci_component_usages_in_projects: true)
      end

      context 'when user is a maintainer of the group' do
        before_all do
          group.add_maintainer(current_user)
        end

        it_behaves_like 'a list of projects and their component usage'

        it 'does not produce N+1 queries' do
          first_user = create(:user)
          second_user = create(:user)

          group.add_maintainer(first_user)
          group.add_maintainer(second_user)

          control = ActiveRecord::QueryRecorder.new(skip_cached: true) do
            post_graphql(query, current_user: first_user)
          end

          project_data = graphql_data['projects']['nodes']
          projects_with_component_usages = project_data.select { |p| p['componentUsages']['nodes'].present? }

          expect(projects_with_component_usages.count).to eq(3)
          expect(projects_with_component_usages.first['componentUsages']['nodes'].count).to eq(1)

          create(:catalog_resource_component_last_usage, component: component_2, used_by_project_id: project_3.id)

          expect do
            post_graphql(query, current_user: second_user)
          end.not_to exceed_query_limit(control)

          project_data = graphql_data['projects']['nodes']
          projects_with_component_usages = project_data.select { |p| p['componentUsages']['nodes'].present? }

          expect(projects_with_component_usages.count).to eq(3)
          expect(projects_with_component_usages.first['componentUsages']['nodes'].count).to eq(2)
        end
      end

      context 'when user does not have a maintainer role in the group' do
        before_all do
          group.add_developer(current_user)
        end

        it 'returns an empty array' do
          post_graphql(query, current_user: current_user)

          projects_data = graphql_data['projects']['nodes']
          expect(projects_data).to be_present
          expect(projects_data).to all(satisfy { |project| project['componentUsages']['nodes'].empty? })
        end
      end
    end

    context 'when user is an admin', :enable_admin_mode do
      let_it_be(:current_user) { create(:admin) }

      it_behaves_like 'a list of projects and their component usage'
    end

    context 'when user does not have access to the group' do
      let_it_be(:unauthorized_user) { create(:user) }

      it 'returns an empty array' do
        post_graphql(query, current_user: unauthorized_user)

        projects_data = graphql_data['projects']['nodes']
        expect(projects_data).to be_empty
      end
    end
  end
end
