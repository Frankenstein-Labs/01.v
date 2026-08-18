# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Namespace.workItemMoveTargets EE', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:source_group) { create(:group, developers: current_user) }
  let_it_be(:target_group) { create(:group, developers: current_user) }
  let_it_be(:source_project) { create(:project, group: source_group) }
  let_it_be(:target_project) { create(:project, group: target_group) }

  let(:source_provider) { WorkItems::TypesFramework::Provider.new(source_project.project_namespace) }
  let(:issue_type) { source_provider.find_by_base_type(:issue) }
  let(:issue_gid) { issue_type.to_gid.to_s }

  let(:target_path) { target_project.full_path }

  let(:query) do
    <<~GQL
      query($targetPath: ID!, $sourcePath: String!, $sourceIds: [WorkItemsTypeID!]!) {
        namespace(fullPath: $targetPath) {
          workItemMoveTargets(sourceFullPath: $sourcePath, sourceTypeIds: $sourceIds) {
            sourceType { id name }
            suggestedTargetType { id name }
            validTargetTypes { id name }
          }
        }
      }
    GQL
  end

  let(:variables) do
    {
      targetPath: target_path,
      sourcePath: source_project.full_path,
      sourceIds: [issue_gid]
    }
  end

  let(:result) { graphql_data.dig('namespace', 'workItemMoveTargets').first }
  let(:valid_target_names) { result['validTargetTypes'].pluck('name') }

  before do
    stub_licensed_features(epics: true)
    post_graphql(query, current_user: current_user, variables: variables)
  end

  context 'when the target namespace is a group where Epic would otherwise be reachable' do
    let(:target_path) { target_group.full_path }

    it 'excludes group-only types (e.g. Epic) from validTargetTypes' do
      expect(valid_target_names).not_to include('Epic')
    end

    it 'does not suggest a group-only type as the recommended target' do
      expect(result['suggestedTargetType']&.dig('name')).not_to eq('Epic')
    end
  end

  context 'when custom work item types are available in the target namespace' do
    let_it_be(:custom_type) do
      create(:work_item_custom_type, namespace: target_group, name: 'Feature')
    end

    let_it_be(:converted_issue_type) do
      create(:work_item_custom_type, :converted_from_issue, namespace: target_group, name: 'Issue')
    end

    before do
      stub_saas_features(namespace_scoped_work_item_types: true)
      post_graphql(query, current_user: current_user, variables: variables)
    end

    it 'includes the converted custom type in validTargetTypes' do
      expect(valid_target_names).to include(converted_issue_type.name)
    end

    it 'includes non-converted custom types matching a supported base_type in validTargetTypes' do
      expect(valid_target_names).to include(custom_type.name)
    end

    it 'suggests the converted custom type that replaces the source system-defined type' do
      expect(result['suggestedTargetType']&.dig('name')).to eq(converted_issue_type.name)
    end

    context 'when a custom type is archived' do
      let_it_be(:archived_type) do
        create(:work_item_custom_type, :archived, namespace: target_group, name: 'Archived Custom')
      end

      it 'excludes archived custom types from validTargetTypes' do
        expect(valid_target_names).not_to include(archived_type.name)
      end
    end

    context 'when a custom type is disabled via visibility settings' do
      before do
        create(:work_item_settings, namespace: target_group, customizable_type_visibility: true)
        create(:work_item_type_visibility, namespace: target_project.project_namespace,
          work_item_type_id: custom_type.id, enabled: false, propagate: false)

        post_graphql(query, current_user: current_user, variables: variables)
      end

      it 'excludes the disabled type from validTargetTypes' do
        expect(valid_target_names).not_to include(custom_type.name)
      end
    end
  end

  context 'when a non-converted custom type in the target shares the source custom type name' do
    let_it_be(:source_custom_type) do
      create(:work_item_custom_type, namespace: source_group, name: 'Bug')
    end

    let_it_be(:target_custom_type) do
      create(:work_item_custom_type, namespace: target_group, name: 'Bug')
    end

    let(:source_custom_gid) { source_custom_type.to_gid.to_s }

    let(:variables) do
      {
        targetPath: target_path,
        sourcePath: source_project.full_path,
        sourceIds: [source_custom_gid]
      }
    end

    before do
      stub_saas_features(namespace_scoped_work_item_types: true)
      post_graphql(query, current_user: current_user, variables: variables)
    end

    it 'suggests the target custom type via the name fallback' do
      expect(result['suggestedTargetType']&.dig('id')).to eq(target_custom_type.to_gid.to_s)
    end
  end
end
