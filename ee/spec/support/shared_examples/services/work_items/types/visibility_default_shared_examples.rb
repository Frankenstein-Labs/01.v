# frozen_string_literal: true

# Shared examples for testing upsert_default_visibility behavior in
# WorkItems::Types::CreateService and WorkItems::Types::UpdateService.
#
# Required lets:
#   - result: the service execution result (subject)
#   - expected_work_item_type: the work item type expected on the visibility default record
#   - expected_namespace_id: expected namespace_id on the visibility default (or nil)
#   - expected_organization_id: expected organization_id on the visibility default (or nil)

RSpec.shared_examples 'upserts visibility default' do
  it 'creates a visibility default record' do
    expect { result }
      .to change { WorkItems::TypesFramework::VisibilityDefault.count }.by(1)

    visibility_default = WorkItems::TypesFramework::VisibilityDefault.last

    expect(visibility_default.work_item_type_id).to eq(expected_work_item_type.persistable_id)
    expect(visibility_default.enabled).to be true
    expect(visibility_default.namespace_id).to eq(expected_namespace_id)
    expect(visibility_default.organization_id).to eq(expected_organization_id)
  end
end

RSpec.shared_examples 'upserts visibility default with enabled false' do
  it 'creates a visibility default record with enabled false' do
    expect { result }
      .to change { WorkItems::TypesFramework::VisibilityDefault.count }.by(1)

    visibility_default = WorkItems::TypesFramework::VisibilityDefault.last
    expect(visibility_default.enabled).to be false
  end
end

RSpec.shared_examples 'does not create a visibility default record' do
  it 'does not create a visibility default record' do
    expect { result }
      .not_to change { WorkItems::TypesFramework::VisibilityDefault.count }
  end
end
