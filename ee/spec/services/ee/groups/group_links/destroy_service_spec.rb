# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::GroupLinks::DestroyService, '#execute', feature_category: :groups_and_projects do
  subject(:service) { described_class.new(shared_group, owner) }

  let_it_be(:group) { create(:group, :private) }
  let_it_be(:shared_group) { create(:group, :private) }
  let_it_be(:owner) { create(:user, developer_of: group, owner_of: shared_group) }

  context 'with a single link' do
    let!(:link) { create(:group_group_link, shared_group: shared_group, shared_with_group: group) }
    let(:audit_context) do
      {
        name: 'group_share_with_group_link_removed',
        stream_only: false,
        author: owner,
        scope: shared_group,
        target: group,
        message: "Removed #{group.name} from the group #{shared_group.name}"
      }
    end

    it 'sends an audit event' do
      expect(::Gitlab::Audit::Auditor).to receive(:audit).with(hash_including(audit_context)).once

      subject.execute(link)
    end

    context 'when destroyed by an automated process (no current_user)' do
      subject(:service) { described_class.new(shared_group, nil) }

      it 'creates an audit event with a system author' do
        subject.execute(link, skip_authorization: true)

        event = AuditEventReader.last
        expect(AuditEventReader.count).to eq(1)
        expect(event.author.name).to eq('(System)')
        expect(event.details[:event_name]).to eq('group_share_with_group_link_removed')
      end
    end

    context 'for refresh user addon assignments' do
      let(:sub_group_shared) { create(:group, :private, parent: shared_group) }
      let!(:link) { create(:group_group_link, shared_group: sub_group_shared, shared_with_group: group) }
      let(:worker) { GitlabSubscriptions::AddOnPurchases::RefreshUserAssignmentsWorker }

      context 'when on self managed' do
        before do
          stub_saas_features(gitlab_com_subscriptions: false)
        end

        it 'does not enqueue RefreshUserAssignmentsWorker' do
          expect(worker).not_to receive(:perform_async)

          subject.execute(link)
        end
      end

      context 'when on SaaS', :saas do
        it 'enqueues RefreshUserAssignmentsWorker with correct arguments' do
          expect(worker).to receive(:perform_async).with(sub_group_shared.root_ancestor.id)

          subject.execute(link)
        end
      end
    end

    describe "shared_with_group's members' ::Authz::UserGroupMemberRole records" do
      it 'does not enqueue a DestroyForSharedGroupWorker job' do
        expect(::Authz::UserGroupMemberRoles::DestroyForSharedGroupWorker).not_to receive(:perform_async)

        service.execute(link)
      end

      context 'when ::Authz::UserGroupMemberRole records exist matching the link' do
        before do
          create(:user_group_member_role, group: link.shared_group, shared_with_group: link.shared_with_group)
        end

        it 'enqueues a ::Authz::UserGroupMemberRoles::DestroyForSharedGroupWorker job' do
          expect(::Authz::UserGroupMemberRoles::DestroyForSharedGroupWorker)
            .to receive(:perform_async).with(link.shared_group_id, link.shared_with_group_id)

          service.execute(link)
        end
      end
    end
  end

  context 'with multiple links' do
    let_it_be(:another_group) { create(:group, :private) }
    let_it_be(:another_shared_group) { create(:group, :private) }

    let!(:links) do
      [
        create(:group_group_link, shared_group: shared_group, shared_with_group: group),
        create(:group_group_link, shared_group: shared_group, shared_with_group: another_group),
        create(:group_group_link, shared_group: another_shared_group, shared_with_group: group),
        create(:group_group_link, shared_group: another_shared_group, shared_with_group: another_group)
      ]
    end

    it 'sends multiple audit events' do
      expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
        hash_including({ name: 'group_share_with_group_link_removed' })
      ).exactly(links.size).times

      subject.execute(links)
    end

    context 'with add-on seat assignments' do
      context 'when on Saas', :saas do
        it 'enqueues multiple RefreshUserAssignmentsWorker' do
          expect(GitlabSubscriptions::AddOnPurchases::RefreshUserAssignmentsWorker).to receive(:perform_async)
            .exactly(links.size).times do |arg|
              expect(arg).to eq(shared_group.id).or eq(another_shared_group.id)
            end

          subject.execute(links)
        end
      end

      context 'when on self managed' do
        it 'does not enqueue RefreshUserAssignmentsWorker' do
          expect(GitlabSubscriptions::AddOnPurchases::RefreshUserAssignmentsWorker).not_to receive(:perform_async)

          subject.execute(links)
        end
      end
    end

    context 'for links with matching ::Authz::UserGroupMemberRole records' do
      let(:link) { links.first }

      before do
        create(:user_group_member_role, group: link.shared_group, shared_with_group: link.shared_with_group)
      end

      it 'enqueues a ::Authz::UserGroupMemberRoles::DestroyForSharedGroupWorker job' do
        expect(::Authz::UserGroupMemberRoles::DestroyForSharedGroupWorker)
          .to receive(:perform_async).once.with(link.shared_group_id, link.shared_with_group_id)

        service.execute(links)
      end
    end
  end
end
