# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::UserProjectMemberRoles::DestroyForSharedProjectService, feature_category: :permissions do
  let_it_be(:shared_project) { create(:project) }
  let_it_be(:shared_with_group) { create(:group) }
  let_it_be(:other_shared_project) { create(:project) }
  let_it_be(:other_group) { create(:group) }

  # Records that should not be deleted by the service
  let_it_be(:other1) do
    create(:user_project_member_role, project: other_shared_project, shared_with_group: shared_with_group)
  end

  let_it_be(:other2) { create(:user_project_member_role, project: shared_project, shared_with_group: other_group) }

  subject(:execute) do
    described_class.new(shared_project, shared_with_group).execute
  end

  before do
    create(:user_project_member_role, project: shared_project, shared_with_group: shared_with_group)
    create(:user_project_member_role, project: shared_project, shared_with_group: shared_with_group)
  end

  it 'destroys UserProjectMemberRole records in shared_project through shared_with_group in batches' do
    stub_const("#{described_class}::BATCH_SIZE", 1)

    target1, target2 = Authz::UserProjectMemberRole.where(project: shared_project, shared_with_group: shared_with_group)

    expected_queries = [
      %r{^DELETE FROM "user_project_member_roles" WHERE .*#{target1.id}},
      %r{^DELETE FROM "user_project_member_roles" WHERE .*#{target2.id}}
    ].flatten

    expect(
      Authz::UserProjectMemberRole.where(project: shared_project, shared_with_group: shared_with_group).count
    ).to eq 2

    query_recorder = ActiveRecord::QueryRecorder.new { execute }

    expect(
      Authz::UserProjectMemberRole.where(project: shared_project, shared_with_group: shared_with_group).count
    ).to eq 0

    expect(Authz::UserProjectMemberRole.where(id: [other1.id, other2.id]).count).to be 2

    expect(query_recorder.log).to include(*expected_queries)
  end

  it 'logs event data' do
    expect(Gitlab::AppJsonLogger).to receive(:info).with(
      hash_including(
        class: described_class.name,
        shared_project_id: shared_project.id,
        shared_with_group_id: shared_with_group.id,
        'update_user_project_member_roles.event': 'project_group_link deleted',
        'update_user_project_member_roles.upserted_count': 0,
        'update_user_project_member_roles.deleted_count': 2
      )
    )

    execute
  end
end
