# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::UserGroupMemberRoles::DestroyForSharedGroupService, feature_category: :permissions do
  let_it_be(:shared_group) { create(:group) }
  let_it_be(:shared_with_group) { create(:group) }
  let_it_be(:other_shared_group) { create(:group) }

  # Records that should not be deleted by the service
  let_it_be(:other1) do
    create(:user_group_member_role, group: other_shared_group, shared_with_group: shared_with_group)
  end

  let_it_be(:other2) { create(:user_group_member_role, group: shared_group, shared_with_group: other_shared_group) }

  subject(:execute) do
    described_class.new(shared_group, shared_with_group).execute
  end

  before do
    create(:user_group_member_role, group: shared_group, shared_with_group: shared_with_group)
    create(:user_group_member_role, group: shared_group, shared_with_group: shared_with_group)
  end

  it 'destroys UserGroupMemberRole records for the shared_group through shared_with_group in batches' do
    stub_const("#{described_class}::BATCH_SIZE", 1)

    target1, target2 = Authz::UserGroupMemberRole.where(group: shared_group, shared_with_group: shared_with_group)

    expected_queries = [
      %r{^DELETE FROM "user_group_member_roles" WHERE .*#{target1.id}},
      %r{^DELETE FROM "user_group_member_roles" WHERE .*#{target2.id}}
    ].flatten

    expect(
      Authz::UserGroupMemberRole.where(group: shared_group, shared_with_group: shared_with_group).count
    ).to eq 2

    query_recorder = ActiveRecord::QueryRecorder.new { execute }

    expect(
      Authz::UserGroupMemberRole.where(group: shared_group, shared_with_group: shared_with_group).count
    ).to eq 0

    expect(Authz::UserGroupMemberRole.where(id: [other1.id, other2.id]).count).to be 2

    expect(query_recorder.log).to include(*expected_queries)
  end

  it 'logs event data' do
    expect(Gitlab::AppJsonLogger).to receive(:info).with(
      hash_including(
        shared_group_id: shared_group.id,
        shared_with_group_id: shared_with_group.id,
        'update_user_group_member_roles.event': 'group_group_link deleted',
        'update_user_group_member_roles.upserted_count': 0,
        'update_user_group_member_roles.deleted_count': 2
      )
    )

    execute
  end
end
