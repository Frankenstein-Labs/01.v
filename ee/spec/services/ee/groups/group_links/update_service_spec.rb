# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::GroupLinks::UpdateService, '#execute', feature_category: :groups_and_projects do
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:shared_with_group) { create(:group, :private) }
  let_it_be(:user) { create(:user, developer_of: group) }

  let_it_be_with_reload(:link) { create(:group_group_link, shared_group: group, shared_with_group: shared_with_group) }

  let(:expiry_date) { 1.month.from_now.to_date }
  let(:group_link_params) { { group_access: Gitlab::Access::GUEST, expires_at: expiry_date } }

  let(:audit_context) do
    {
      name: 'group_share_with_group_link_updated',
      stream_only: false,
      author: user,
      scope: group,
      target: shared_with_group,
      message: "Updated #{shared_with_group.name}'s " \
               "access params for the group #{group.name}",
      additional_details: {
        changes: [
          { change: :group_access, from: 'Developer', to: 'Guest' },
          { change: :expires_at, from: '', to: expiry_date.to_s }
        ]
      }
    }
  end

  let(:service) { described_class.new(link, user) }

  subject(:update_service) { service.execute(group_link_params) }

  it 'sends an audit event' do
    expect(::Gitlab::Audit::Auditor).to receive(:audit).with(hash_including(audit_context)).once

    update_service
  end

  context 'when assigning a member role to group link' do
    let_it_be(:member_role) { create(:member_role, namespace: group) }

    let_it_be(:link_with_member_role, freeze: false) do
      create(:group_group_link, shared_group: group, member_role_id: member_role.id)
    end

    let(:group_link_params) { { member_role_id: member_role.id } }

    context 'when custom_roles feature is enabled' do
      before do
        stub_licensed_features(custom_roles: true)
      end

      it 'assigns member role to group link' do
        expect(update_service.member_role_id).to eq(member_role.id)
      end

      it 'sends an audit event' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(hash_including({
          additional_details: {
            changes: [
              { change: :member_role, from: '', to: member_role.id.to_s }
            ]
          }
        })).once

        update_service
      end

      context 'when the member role is in a different namespace' do
        let_it_be(:member_role) { create(:member_role, namespace: create(:group)) }

        it 'returns error' do
          expect { update_service }.to raise_error(ActiveRecord::RecordInvalid,
            "Validation failed: Group must be in same hierarchy as custom role's namespace")
        end
      end

      context 'when the member role is created on the instance-level' do
        let_it_be(:member_role) { create(:member_role, :instance) }

        before do
          stub_saas_features(gitlab_com_subscriptions: false)
        end

        it 'assigns member role to group link' do
          expect(update_service.member_role_id).to eq(member_role.id)
        end
      end

      context 'when un-assigning a member role to group link' do
        let(:link) { link_with_member_role }
        let(:group_link_params) { { group_access: Gitlab::Access::GUEST, member_role_id: nil } }

        it 'un-assigns member role to group link' do
          expect(update_service.member_role_id).to be_nil
          expect(update_service.group_access).to eq(Gitlab::Access::GUEST)
        end
      end

      describe "Authz::UserGroupMemberRole records of the shared_with_group's members" do
        shared_examples 'enqueues UpdateForSharedGroupWorker job' do
          it 'enqueues a ::Authz::UserGroupMemberRoles::UpdateForSharedGroupWorker job' do
            allow(::Authz::UserGroupMemberRoles::UpdateForSharedGroupWorker).to receive(:perform_async)

            updated_link = update_service

            expect(::Authz::UserGroupMemberRoles::UpdateForSharedGroupWorker)
              .to have_received(:perform_async).with(updated_link.id)
          end
        end

        context 'when neither member role nor access level was updated' do
          let(:link) { link_with_member_role }
          let(:group_link_params) { { expires_at: expiry_date } }

          it 'does not enqueue a ::Authz::UserGroupMemberRoles::UpdateForSharedGroupWorker job' do
            expect(::Authz::UserGroupMemberRoles::UpdateForSharedGroupWorker).not_to receive(:perform_async)

            update_service
          end
        end

        context 'when only access level was updated' do
          let(:group_link_params) { { group_access: Gitlab::Access::GUEST } }

          it_behaves_like 'enqueues UpdateForSharedGroupWorker job'
        end

        it_behaves_like 'enqueues UpdateForSharedGroupWorker job'
      end
    end

    context 'when custom_roles feature is disabled' do
      before do
        stub_licensed_features(custom_roles: false)
      end

      it 'does not assign member role to group link' do
        expect(update_service.member_role_id).to be_nil
      end
    end
  end
end
