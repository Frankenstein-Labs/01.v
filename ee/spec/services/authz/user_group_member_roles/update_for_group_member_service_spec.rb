# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::UserGroupMemberRoles::UpdateForGroupMemberService, feature_category: :permissions do
  let_it_be(:group) { create(:group) }
  let_it_be(:member_role) { create(:member_role, namespace: group) }

  shared_examples 'does not enqueue UpdateForGroupWorker job' do
    it 'does not enqueue a ::Authz::UserGroupMemberRoles::UpdateForGroupWorker job' do
      expect(::Authz::UserGroupMemberRoles::UpdateForGroupWorker).not_to receive(:perform_async)

      execute
    end
  end

  shared_examples 'enqueues an UpdateForGroupWorker job' do
    it 'enqueues an ::Authz::UserGroupMemberRoles::UpdateForGroupWorker job' do
      allow(::Authz::UserGroupMemberRoles::UpdateForGroupWorker).to receive(:perform_async)

      execute

      expect(::Authz::UserGroupMemberRoles::UpdateForGroupWorker).to have_received(:perform_async).with(member.id)
    end
  end

  shared_context 'with source invited to another group with a member role' do
    before do
      other_group = create(:group)

      create(:group_group_link,
        shared_group: other_group,
        shared_with_group: member.source,
        member_role: create(:member_role, namespace: other_group)
      )
    end
  end

  shared_context 'with source invited to a project with a member role' do
    before do
      project = create(:project)

      create(:project_group_link,
        project: project,
        group: member.source,
        member_role: create(:member_role, namespace: project.root_ancestor)
      )
    end
  end

  context 'when no old_values_map is passed (i.e. member has just been created)' do
    subject(:execute) { described_class.new(member).execute }

    context 'when no member role was assigned' do
      let_it_be(:member) { create(:group_member, source: group) }

      it_behaves_like 'does not enqueue UpdateForGroupWorker job'

      context 'when source has been invited to another group with a member role' do
        include_context 'with source invited to another group with a member role'

        it_behaves_like 'enqueues an UpdateForGroupWorker job'
      end

      context 'when source has been invited to a project with a member role' do
        include_context 'with source invited to a project with a member role'

        it_behaves_like 'enqueues an UpdateForGroupWorker job'

        context 'when cache_user_project_member_roles feature flag is disabled' do
          before do
            stub_feature_flags(cache_user_project_member_roles: false)
          end

          it_behaves_like 'does not enqueue UpdateForGroupWorker job'
        end
      end
    end

    context 'when a member role is assigned' do
      let_it_be(:member) { create(:group_member, source: group, member_role: member_role) }

      it_behaves_like 'enqueues an UpdateForGroupWorker job'
    end
  end

  context 'when member has been updated' do
    let_it_be_with_reload(:member) { create(:group_member, access_level: 10, source: group) }
    let_it_be(:old_values_map) { { member_role_id: member.member_role_id, access_level: member.access_level } }

    subject(:execute) { described_class.new(member, old_values_map: old_values_map).execute }

    context 'when member role and access_level did not change' do
      it_behaves_like 'does not enqueue UpdateForGroupWorker job'
    end

    context 'when member role changed' do
      before do
        member.member_role = member_role
      end

      it_behaves_like 'enqueues an UpdateForGroupWorker job'
    end

    context 'when access level changed' do
      before do
        member.access_level = 30
      end

      it_behaves_like 'does not enqueue UpdateForGroupWorker job'

      context 'when source has been invited to another group with a member role' do
        include_context 'with source invited to another group with a member role'

        it_behaves_like 'enqueues an UpdateForGroupWorker job'
      end

      context 'when source has been invited to a project with a member role' do
        include_context 'with source invited to a project with a member role'

        it_behaves_like 'enqueues an UpdateForGroupWorker job'

        context 'when cache_user_project_member_roles feature flag is disabled' do
          before do
            stub_feature_flags(cache_user_project_member_roles: false)
          end

          it_behaves_like 'does not enqueue UpdateForGroupWorker job'
        end
      end
    end
  end
end
