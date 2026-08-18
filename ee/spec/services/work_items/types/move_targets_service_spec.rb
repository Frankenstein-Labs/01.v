# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Types::MoveTargetsService, feature_category: :team_planning do
  let_it_be(:current_user) { create(:user) }
  let_it_be(:source_group) { create(:group, developers: current_user) }
  let_it_be(:target_group) { create(:group, developers: current_user) }
  let_it_be(:source_project) { create(:project, group: source_group) }
  let_it_be(:target_project) { create(:project, group: target_group) }

  let(:source_provider) { WorkItems::TypesFramework::Provider.new(source_project.project_namespace) }
  let(:issue_type) { source_provider.find_by_base_type(:issue) }

  before do
    stub_licensed_features(epics: true)
  end

  describe '#execute' do
    context 'when the target namespace is a group where Epic would otherwise be reachable' do
      subject(:service) do
        described_class.new(
          current_user: current_user,
          source_namespace: source_project.project_namespace,
          target_namespace: target_group,
          source_type_ids: [issue_type.id]
        )
      end

      it 'excludes group-only types (e.g. Epic) from valid_target_types' do
        result = service.execute.first

        base_types = result.valid_target_types.map(&:base_type)

        expect(base_types).not_to include('epic')
      end

      it 'does not suggest a group-only type even if it would have been the only candidate' do
        result = service.execute.first

        expect(result.suggested_target_type&.base_type).not_to eq('epic')
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
      end

      subject(:service) do
        described_class.new(
          current_user: current_user,
          source_namespace: source_project.project_namespace,
          target_namespace: target_project.project_namespace,
          source_type_ids: [issue_type.id]
        )
      end

      it 'includes the converted custom type in valid_target_types' do
        result = service.execute.first

        valid_target_names = result.valid_target_types.map(&:name)

        expect(valid_target_names).to include(converted_issue_type.name)
      end

      it 'includes non-converted custom types matching a supported base_type in valid_target_types' do
        result = service.execute.first

        valid_target_names = result.valid_target_types.map(&:name)

        expect(valid_target_names).to include(custom_type.name)
      end

      it 'suggests the converted custom type that replaces the source system-defined type' do
        result = service.execute.first

        expect(result.suggested_target_type&.name).to eq(converted_issue_type.name)
      end

      it 'excludes archived custom types from valid_target_types' do
        create(:work_item_custom_type, :archived, namespace: target_group, name: 'Archived Custom')

        result = service.execute.first

        valid_target_names = result.valid_target_types.map(&:name)

        expect(valid_target_names).not_to include('Archived Custom')
      end

      it 'excludes types disabled via visibility settings from valid_target_types' do
        create(:work_item_settings, namespace: target_group, customizable_type_visibility: true)
        create(:work_item_type_visibility, namespace: target_project.project_namespace,
          work_item_type_id: custom_type.id, enabled: false, propagate: false)

        result = service.execute.first

        valid_target_names = result.valid_target_types.map(&:name)

        expect(valid_target_names).not_to include(custom_type.name)
      end
    end
  end
end
