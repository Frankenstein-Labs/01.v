# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.project.securityTrackedRefs', feature_category: :vulnerability_management do
  include GraphqlHelpers
  include ApiHelpers
  using RSpec::Parameterized::TableSyntax

  let_it_be(:project, freeze: false) { create(:project, :repository) }
  let_it_be(:user) { create(:user) }

  let_it_be(:tracked_branch) do
    create(:security_project_tracked_context, :tracked, :default,
      project: project, context_name: 'main', context_type: :branch)
  end

  let_it_be(:tracked_tag) do
    create(:security_project_tracked_context, :tracked,
      project: project, context_name: 'v1.1.0', context_type: :tag)
  end

  let_it_be(:untracked_branch) do
    create(:security_project_tracked_context, :untracked,
      project: project, context_name: 'untracked-branch', context_type: :branch)
  end

  let(:tracked_refs_data) { graphql_data&.dig('project', 'securityTrackedRefs') }
  let(:tracked_refs_nodes) { tracked_refs_data&.[]('nodes') || [] }

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
      query_graphql_field(:securityTrackedRefs, args, fields_selection)
    )
  end

  def fields_selection
    <<~FIELDS
      count
      nodes {
        id
        name
        refType
        state
        isDefault
        isProtected
        commit {
          id
          sha
          title
        }
        vulnerabilitiesCount
        trackedAt
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
    it 'returns all refs for the project' do
      execute_query

      expect(graphql_errors).to be_blank
      expect(tracked_refs_data['count']).to eq(3)
      expect(tracked_refs_nodes).to contain_exactly(
        a_hash_including('name' => 'main', 'refType' => 'BRANCH', 'state' => 'TRACKED'),
        a_hash_including('name' => 'v1.1.0', 'refType' => 'TAG', 'state' => 'TRACKED'),
        a_hash_including('name' => 'untracked-branch', 'refType' => 'BRANCH', 'state' => 'UNTRACKED')
      )
      expect(tracked_refs_data['pageInfo']).to include(
        'hasNextPage' => false,
        'hasPreviousPage' => false
      )
    end
  end

  describe 'state filtering' do
    where(:state, :expected_names, :expected_count) do
      :TRACKED   | ['main', 'v1.1.0']      | 2
      :UNTRACKED | ['untracked-branch']    | 1
    end

    with_them do
      it "returns only #{params[:state].downcase} refs" do
        execute_query(query_args: { state: state })

        expect(graphql_errors).to be_blank
        expect(tracked_refs_data['count']).to eq(expected_count)
        actual_names = tracked_refs_nodes.pluck('name')
        expect(actual_names).to match_array(expected_names)
        expect(tracked_refs_data['pageInfo']).to include(
          'hasNextPage' => false,
          'hasPreviousPage' => false
        )
      end
    end

    it 'returns validation error for invalid enum value' do
      execute_query(query_args: { state: :INVALID })

      expect(graphql_errors).to be_present
      expect(graphql_errors.first['message']).to match(/invalid value.*INVALID/i)
    end
  end

  describe 'pagination' do
    where(:pagination_args, :expected_size, :expected_page_info) do
      { first: 1 } | 1 | { 'hasNextPage' => true, 'hasPreviousPage' => false }
      { last: 1 }  | 1 | { 'hasPreviousPage' => true }
    end

    with_them do
      it "handles pagination correctly" do
        execute_query(query_args: pagination_args)

        expect(graphql_errors).to be_blank
        expect(tracked_refs_data['count']).to eq(3)
        expect(tracked_refs_nodes.size).to eq(expected_size)
        expect(tracked_refs_data['pageInfo']).to include(expected_page_info)
      end
    end
  end

  describe 'authorization' do
    let_it_be(:guest_user) { create(:user) }
    let_it_be(:reporter_user) { create(:user) }
    let_it_be(:maintainer_user) { create(:user) }

    before_all do
      project.add_guest(guest_user)
      project.add_reporter(reporter_user)
      project.add_maintainer(maintainer_user)
    end

    where(:role, :should_have_access) do
      :guest      | false
      :reporter   | false
      :developer  | true
      :maintainer | true
    end

    with_them do
      it "#{params[:should_have_access] ? 'allows' : 'denies'} access for #{params[:role]} users" do
        test_user = role == :developer ? user : send(:"#{role}_user")
        execute_query(current_user: test_user)

        if should_have_access
          expect(tracked_refs_data['count']).to eq(3)
          expect(tracked_refs_nodes).not_to be_empty
        else
          expect(tracked_refs_data['count']).to eq(0)
          expect(tracked_refs_nodes).to be_empty
        end
      end
    end

    it 'denies access for nil users' do
      execute_query(current_user: nil)

      expect(tracked_refs_data).to be_nil
    end
  end

  describe 'licensing' do
    context 'when security dashboard is not licensed' do
      before do
        stub_licensed_features(security_dashboard: false)
      end

      it 'returns empty result' do
        execute_query

        expect(graphql_errors).to be_blank
        expect(tracked_refs_data['count']).to eq(0)
        expect(tracked_refs_nodes).to be_empty
      end
    end
  end

  describe 'edge cases' do
    it 'returns empty result for project with no refs' do
      empty_project = create(:project, :repository)
      empty_project.add_developer(user)

      execute_query(project_path: empty_project.full_path)

      expect(graphql_errors).to be_blank
      expect(tracked_refs_data['count']).to eq(0)
      expect(tracked_refs_nodes).to be_empty
      expect(tracked_refs_data['pageInfo']).to include(
        'hasNextPage' => false,
        'hasPreviousPage' => false
      )
    end

    it 'returns null for non-existent project' do
      execute_query(project_path: 'non-existent/project')
      expect(graphql_data['project']).to be_nil
    end
  end

  describe 'comprehensive field implementations' do
    let_it_be(:vulnerability_reads) do
      create_list(:vulnerability_read, 2, project: project, tracked_context: tracked_branch)
    end

    before_all do
      unless project.repository.branch_exists?('main')
        project.repository.create_branch('main', project.default_branch)
        project.repository.expire_branches_cache
      end

      create(:protected_branch, project: project, name: 'main')
    end

    where(:ref_name, :ref_type, :is_default, :is_protected, :vuln_count) do
      'main'   | 'BRANCH' | true  | true  | 2
      'v1.1.0' | 'TAG'    | false | false | 0
    end

    with_them do
      it 'returns correct field implementations' do
        execute_query(query_args: { state: :TRACKED })

        expect(graphql_errors).to be_blank
        expect(tracked_refs_data['count']).to eq(2)

        ref_node = tracked_refs_nodes.find { |ref| ref['name'] == ref_name }

        expect(ref_node).to include(
          'name' => ref_name,
          'refType' => ref_type,
          'state' => 'TRACKED',
          'isDefault' => is_default,
          'isProtected' => is_protected,
          'vulnerabilitiesCount' => vuln_count
        )

        expect(ref_node['commit']).to include('sha' => be_present) if ref_name == 'main'
      end
    end
  end

  describe 'performance' do
    it 'avoids N+1 queries when loading multiple refs' do
      stub_const("#{Security::ProjectTrackedContext}::MAX_TRACKED_REFS_PER_PROJECT", 10)

      refs = create_list(:security_project_tracked_context, 3, :tracked, project: project)
      refs.each { |ref| create_list(:vulnerability_read, 2, project: project, tracked_context: ref) }

      control = ActiveRecord::QueryRecorder.new do
        execute_query(query_args: { first: 3 })
      end

      additional_refs = create_list(:security_project_tracked_context, 3, :tracked, project: project)
      additional_refs.each { |ref| create_list(:vulnerability_read, 2, project: project, tracked_context: ref) }

      expect do
        execute_query(query_args: { first: 6 })
      end.not_to exceed_query_limit(control.count)
    end
  end
end
