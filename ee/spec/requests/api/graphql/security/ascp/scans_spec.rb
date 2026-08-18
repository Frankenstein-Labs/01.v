# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.project.ascpScans', feature_category: :static_application_security_testing do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }

  let_it_be(:full_scan) { create(:security_ascp_scan, :full, project: project) }
  let_it_be(:incremental_scan) do
    create(:security_ascp_scan, :incremental, project: project, base_scan: full_scan)
  end

  let(:scans_data) { graphql_data.dig('project', 'ascpScans') }
  let(:scans_nodes) { scans_data['nodes'] }

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
      query_graphql_field(:ascpScans, args, fields_selection)
    )
  end

  def fields_selection
    <<~FIELDS
      nodes {
        id
        scanSequence
        commitSha
        scanType
        createdAt
        updatedAt
        baseScan {
          id
        }
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
    it 'returns scans for the project' do
      execute_query

      expect(graphql_errors).to be_blank
      expect(scans_nodes).to contain_exactly(
        a_hash_including('scanSequence' => full_scan.scan_sequence, 'scanType' => 'FULL'),
        a_hash_including('scanSequence' => incremental_scan.scan_sequence, 'scanType' => 'INCREMENTAL')
      )
    end

    it 'returns expected fields' do
      execute_query

      scan_node = scans_nodes.find { |n| n['scanType'] == 'FULL' }

      expect(scan_node).to include(
        'id' => full_scan.to_global_id.to_s,
        'scanSequence' => full_scan.scan_sequence,
        'commitSha' => full_scan.commit_sha,
        'scanType' => 'FULL',
        'createdAt' => be_present,
        'updatedAt' => be_present
      )
    end

    it 'includes base_scan reference for incremental scans' do
      execute_query

      inc_node = scans_nodes.find { |n| n['scanType'] == 'INCREMENTAL' }

      expect(inc_node['baseScan']).to include('id' => full_scan.to_global_id.to_s)
    end

    it 'returns empty result for project with no scans' do
      empty_project = create(:project)
      empty_project.add_developer(user)

      execute_query(project_path: empty_project.full_path)

      expect(graphql_errors).to be_blank
      expect(scans_nodes).to be_empty
    end

    it 'returns null for non-existent project' do
      execute_query(project_path: 'non-existent/project')

      expect(graphql_data['project']).to be_nil
    end
  end

  describe 'filtering by scanType' do
    it 'returns only full scans when filtering by FULL' do
      execute_query(query_args: { scanType: :FULL })

      expect(graphql_errors).to be_blank
      expect(scans_nodes).to contain_exactly(
        a_hash_including('scanType' => 'FULL')
      )
    end

    it 'returns only incremental scans when filtering by INCREMENTAL' do
      execute_query(query_args: { scanType: :INCREMENTAL })

      expect(graphql_errors).to be_blank
      expect(scans_nodes).to contain_exactly(
        a_hash_including('scanType' => 'INCREMENTAL')
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

      expect(scans_nodes).not_to be_empty
    end

    it 'denies access for guest users' do
      execute_query(current_user: guest_user)

      expect(scans_data).to be_nil
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
        expect(scans_data).to be_nil
      end
    end
  end
end
