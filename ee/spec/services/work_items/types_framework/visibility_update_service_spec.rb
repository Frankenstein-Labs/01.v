# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::TypesFramework::VisibilityUpdateService, feature_category: :team_planning do
  let_it_be(:root) { create(:group) }
  let_it_be(:child) { create(:group, parent: root) }
  let_it_be(:grandchild) { create(:group, parent: child) }
  let_it_be(:project) { create(:project, group: child) }
  let_it_be(:nested_project) { create(:project, group: grandchild) }

  let_it_be(:issue_type_id) { create(:work_item_system_defined_type, :issue).id }
  let_it_be(:task_type_id) { create(:work_item_system_defined_type, :task).id }

  let(:enabled) { false }
  let(:propagate) { false }

  subject(:result) do
    described_class.new(
      namespace: root,
      work_item_type_id: issue_type_id,
      enabled: enabled,
      propagate: propagate
    ).execute
  end

  shared_examples 'deletes conflicting project-level visibility overrides on propagation' do
    it 'deletes conflicting project namespace overrides' do
      create(:work_item_type_visibility, namespace: project.project_namespace,
        work_item_type_id: issue_type_id, enabled: false, propagate: false)

      result

      expect(WorkItems::TypesFramework::Visibility.where(
        namespace_id: project.project_namespace.id
      )).to be_empty
    end

    it 'deletes project overrides at every level of the hierarchy', :aggregate_failures do
      create(:work_item_type_visibility, namespace: project.project_namespace,
        work_item_type_id: issue_type_id, enabled: false, propagate: false)
      create(:work_item_type_visibility, namespace: nested_project.project_namespace,
        work_item_type_id: issue_type_id, enabled: false, propagate: false)

      result

      expect(WorkItems::TypesFramework::Visibility.where(
        namespace_id: project.project_namespace.id
      )).to be_empty
      expect(WorkItems::TypesFramework::Visibility.where(
        namespace_id: nested_project.project_namespace.id
      )).to be_empty
    end
  end

  it 'creates a visibility row and returns success' do
    expect { result }.to change { WorkItems::TypesFramework::Visibility.count }.by(1)
    expect(result).to be_success
  end

  it 'updates the existing row rather than creating a duplicate' do
    create(:work_item_type_visibility, namespace: root,
      work_item_type_id: issue_type_id, enabled: true, propagate: false)

    expect { result }.not_to change { WorkItems::TypesFramework::Visibility.count }
    expect(WorkItems::TypesFramework::Visibility.find_by(namespace: root,
      work_item_type_id: issue_type_id).enabled).to be false
  end

  context 'when propagate: false' do
    it 'does not touch descendant rows' do
      create(:work_item_type_visibility, namespace: child,
        work_item_type_id: issue_type_id, enabled: true, propagate: false)

      expect { result }.not_to change { WorkItems::TypesFramework::Visibility.where(namespace_id: child.id).count }
    end
  end

  context 'when propagate: true' do
    let(:propagate) { true }

    it 'deletes conflicting descendant self-records' do
      create(:work_item_type_visibility, namespace: child,
        work_item_type_id: issue_type_id, enabled: true, propagate: false)

      expect { result }.to change { WorkItems::TypesFramework::Visibility.where(namespace_id: child.id).count }.by(-1)
    end

    it 'cleans up conflicting self-records at every level of the hierarchy' do
      create(:work_item_type_visibility, namespace: child,
        work_item_type_id: issue_type_id, enabled: true, propagate: false)
      create(:work_item_type_visibility, namespace: grandchild,
        work_item_type_id: issue_type_id, enabled: true, propagate: false)

      result

      expect(WorkItems::TypesFramework::Visibility.where(namespace_id: child.id)).to be_empty
      expect(WorkItems::TypesFramework::Visibility.where(namespace_id: grandchild.id)).to be_empty
    end

    it 'does not touch records in an unrelated namespace' do
      unrelated = create(:group)
      create(:work_item_type_visibility, namespace: unrelated,
        work_item_type_id: issue_type_id, enabled: true, propagate: false)

      expect { result }.not_to change { WorkItems::TypesFramework::Visibility.where(namespace_id: unrelated.id).count }
    end

    it 'deletes conflicting descendant propagating rows' do
      create(:work_item_type_visibility, namespace: child,
        work_item_type_id: issue_type_id, enabled: true, propagate: true)

      expect { result }.to change { WorkItems::TypesFramework::Visibility.where(namespace_id: child.id).count }.by(-1)
    end

    it 'does not delete rows for other types' do
      create(:work_item_type_visibility, namespace: child,
        work_item_type_id: task_type_id, enabled: true, propagate: false)

      expect { result }.not_to change { WorkItems::TypesFramework::Visibility.where(work_item_type_id: task_type_id).count }
    end

    it_behaves_like 'deletes conflicting project-level visibility overrides on propagation'

    context 'on GitLab Self-Managed' do
      before do
        stub_saas_features(namespace_scoped_work_item_types: false)
      end

      it_behaves_like 'deletes conflicting project-level visibility overrides on propagation'
    end
  end

  context 'when the visibility record fails to save' do
    before do
      allow_next_instance_of(WorkItems::TypesFramework::Visibility) do |visibility|
        visibility.errors.add(:base, 'something went wrong')
        allow(visibility).to receive(:save).and_return(false)
      end
    end

    it 'returns an error ServiceResponse' do
      expect(result).to be_error
      expect(result.message).to eq('something went wrong')
    end

    it 'does not delete any descendant records' do
      create(:work_item_type_visibility, namespace: child,
        work_item_type_id: issue_type_id, enabled: true, propagate: false)

      expect { result }.not_to change { WorkItems::TypesFramework::Visibility.count }
    end
  end
end
