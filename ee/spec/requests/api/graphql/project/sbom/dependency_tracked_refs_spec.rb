# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.project(fullPath).dependencyTrackedRefs', feature_category: :dependency_management do
  include ApiHelpers
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:current_user) { create(:user, developer_of: project) }
  let_it_be(:component_version) { create(:sbom_component_version) }

  let_it_be(:main_ref) { create(:security_project_tracked_context, :default, project: project) }
  let_it_be(:tag_ref) do
    create(:security_project_tracked_context, :tag, project: project, context_name: 'v1.0.0')
  end

  let_it_be(:occurrence_main) do
    create(:sbom_occurrence, project: project, component_version: component_version)
  end

  let_it_be(:occurrence_tag) do
    create(:sbom_occurrence, project: project, component_version: component_version)
  end

  let(:fields) do
    <<~FIELDS
      id
      name
      refType
      isDefault
    FIELDS
  end

  let(:args) { { component_version_id: component_version.to_global_id.to_s } }
  let(:query) do
    nodes = query_nodes(:dependencyTrackedRefs, fields, args: args)
    graphql_query_for(:project, { fullPath: project.full_path }, nodes)
  end

  before_all do
    create(:sbom_occurrence_ref, project: project, occurrence: occurrence_main, tracked_context: main_ref)
    create(:sbom_occurrence_ref, project: project, occurrence: occurrence_tag, tracked_context: tag_ref)
  end

  before do
    stub_licensed_features(dependency_scanning: true, security_dashboard: true)
  end

  it 'returns the refs where the dependency appears' do
    post_graphql(query, current_user: current_user)

    refs = graphql_data_at(:project, :dependency_tracked_refs, :nodes)

    expect(refs).to contain_exactly(
      a_hash_including(
        'id' => main_ref.to_global_id.to_s,
        'name' => 'main',
        'refType' => 'BRANCH',
        'isDefault' => true
      ),
      a_hash_including(
        'id' => tag_ref.to_global_id.to_s,
        'name' => 'v1.0.0',
        'refType' => 'TAG',
        'isDefault' => false
      )
    )
  end

  context 'with search argument' do
    let(:args) { { component_version_id: component_version.to_global_id.to_s, search: 'v1' } }

    it 'filters refs by name' do
      post_graphql(query, current_user: current_user)

      refs = graphql_data_at(:project, :dependency_tracked_refs, :nodes)

      expect(refs).to contain_exactly(
        a_hash_including('name' => 'v1.0.0')
      )
    end
  end

  context 'when the feature flag is disabled' do
    before do
      stub_feature_flags(vulnerabilities_across_contexts: false)
    end

    it 'returns nil' do
      post_graphql(query, current_user: current_user)

      expect(graphql_data_at(:project, :dependency_tracked_refs)).to be_nil
    end
  end

  context 'when the user is not authorized' do
    let_it_be(:unauthorized_user) { create(:user) }

    it 'returns nil' do
      post_graphql(query, current_user: unauthorized_user)

      expect(graphql_data_at(:project, :dependency_tracked_refs)).to be_nil
    end
  end

  it 'avoids N+1 database queries', :request_store do
    post_graphql(query, current_user: current_user)

    control = ActiveRecord::QueryRecorder.new do
      post_graphql(query, current_user: create(:user, developer_of: project))
    end

    another_ref = create(:security_project_tracked_context, project: project, context_name: 'feature-y')
    occurrence = create(:sbom_occurrence, project: project, component_version: component_version)
    create(:sbom_occurrence_ref, project: project, occurrence: occurrence, tracked_context: another_ref)

    expect do
      post_graphql(query, current_user: create(:user, developer_of: project))
    end.not_to exceed_query_limit(control)
  end

  it_behaves_like 'authorizing granular token permissions for GraphQL', [:read_project, :read_dependency] do
    let(:user) { current_user }
    let(:boundary_object) { project }
    let(:request) { post_graphql(query, token: { personal_access_token: pat }) }
  end
end
