# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.project.ascpComponents', feature_category: :static_application_security_testing do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be(:scan) { create(:security_ascp_scan, project: project) }

  let_it_be(:component1) do
    create(:security_ascp_component, project: project, scan: scan, title: 'Auth Module', sub_directory: 'app/auth')
  end

  let_it_be(:component2) do
    create(:security_ascp_component, project: project, scan: scan, title: 'Payment Service',
      sub_directory: 'app/payment')
  end

  let(:components_data) { graphql_data.dig('project', 'ascpComponents') }
  let(:components_nodes) { components_data['nodes'] }

  before_all do
    project.add_developer(user)
  end

  before do
    stub_licensed_features(security_dashboard: true)
  end

  def build_query(project_path = project.full_path, **args)
    graphql_query_for(
      :project,
      { fullPath: project_path },
      query_graphql_field(:ascpComponents, args, fields_selection)
    )
  end

  def fields_selection
    <<~FIELDS
      nodes {
        id
        title
        description
        subDirectory
        expectedUserBehavior
        scan {
          id
        }
        createdAt
        updatedAt
      }
      pageInfo {
        hasNextPage
        hasPreviousPage
      }
    FIELDS
  end

  def execute_query(query_args: {}, current_user: user, project_path: project.full_path)
    query = build_query(project_path, **query_args)
    post_graphql(query, current_user: current_user)
  end

  describe 'basic functionality' do
    it 'returns components for the project' do
      execute_query

      expect(graphql_errors).to be_blank
      expect(components_nodes).to contain_exactly(
        a_hash_including('title' => 'Auth Module', 'subDirectory' => 'app/auth'),
        a_hash_including('title' => 'Payment Service', 'subDirectory' => 'app/payment')
      )
    end

    it 'returns expected fields' do
      execute_query

      node = components_nodes.find { |n| n['title'] == 'Auth Module' }

      expect(node).to include(
        'id' => component1.to_global_id.to_s,
        'title' => 'Auth Module',
        'subDirectory' => 'app/auth',
        'createdAt' => be_present,
        'updatedAt' => be_present
      )
      expect(node['scan']).to include('id' => scan.to_global_id.to_s)
    end

    it 'returns empty result for project with no components' do
      empty_project = create(:project)
      empty_project.add_developer(user)

      execute_query(project_path: empty_project.full_path)

      expect(graphql_errors).to be_blank
      expect(components_nodes).to be_empty
    end

    it 'returns null for non-existent project' do
      execute_query(project_path: 'non-existent/project')

      expect(graphql_data['project']).to be_nil
    end

    it 'does not return components from other projects' do
      other_project = create(:project)
      create(:security_ascp_component, project: other_project, title: 'Other Component')

      execute_query

      titles = components_nodes.pluck('title')
      expect(titles).not_to include('Other Component')
    end
  end

  describe 'N+1 queries' do
    it 'does not cause N+1 queries when fetching associations' do
      execute_query
      control = ActiveRecord::QueryRecorder.new { execute_query }

      create(:security_ascp_component, project: project, scan: scan,
        title: 'New Component', sub_directory: 'app/new')

      expect { execute_query }.not_to exceed_query_limit(control)
    end
  end

  describe 'filtering' do
    it 'filters by title (case-insensitive)' do
      execute_query(query_args: { title: 'auth' })

      expect(graphql_errors).to be_blank
      expect(components_nodes).to contain_exactly(
        a_hash_including('title' => component1.title)
      )
    end

    it 'filters by sub_directory' do
      execute_query(query_args: { subDirectory: component2.sub_directory })

      expect(graphql_errors).to be_blank
      expect(components_nodes).to contain_exactly(
        a_hash_including('title' => component2.title)
      )
    end
  end

  describe 'authorization' do
    let_it_be(:guest_user) { create(:user) }

    before_all do
      project.add_guest(guest_user)
    end

    it 'allows access for developer users' do
      execute_query

      expect(components_nodes).not_to be_empty
    end

    it 'denies access for guest users' do
      execute_query(current_user: guest_user)

      expect(components_data).to be_nil
    end

    it 'denies access for nil users' do
      execute_query(current_user: nil)

      expect(graphql_data['project']).to be_nil
    end
  end

  describe 'licensing' do
    context 'when security dashboard is not licensed' do
      before do
        stub_licensed_features(security_dashboard: false)
      end

      it 'returns no data' do
        execute_query

        expect(graphql_errors).to be_blank
        expect(components_data).to be_nil
      end
    end
  end
end
