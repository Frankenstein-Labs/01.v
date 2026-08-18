# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::GroupLinks::DestroyService, feature_category: :groups_and_projects do
  let!(:user) { create(:user) }
  let!(:group) { create(:group) }
  let!(:project) { create(:project) }
  let!(:group_link) { create(:project_group_link, project: project, group: group) }

  subject(:service) { described_class.new(project, user, {}) }

  before do
    project.add_owner(user)
  end

  context 'audit events' do
    include_examples 'audit event logging' do
      let(:operation) { subject.execute(group_link) }
      let(:fail_condition!) do
        expect_any_instance_of(ProjectGroupLink)
          .to receive(:destroy).and_return(group_link)
      end

      let(:attributes) do
        {
          author_id: user.id,
          entity_id: group.id,
          entity_type: 'Group',
          details: {
            remove: 'project_access',
            author_name: user.name,
            author_class: 'User',
            event_name: "project_group_link_deleted",
            target_id: project.id,
            target_type: 'Project',
            target_details: project.full_path,
            custom_message: 'Removed project group link'
          }
        }
      end
    end

    it 'sends the audit streaming event' do
      audit_context = {
        name: 'project_group_link_deleted',
        author: user,
        scope: group,
        target: project,
        target_details: project.full_path,
        message: 'Removed project group link',
        additional_details: {
          remove: 'project_access'
        }
      }
      expect(::Gitlab::Audit::Auditor).to receive(:audit).with(audit_context)

      subject.execute(group_link)
    end
  end

  context 'when destroyed by an automated process (no current_user)' do
    subject(:service) { described_class.new(project, nil, {}) }

    it 'creates an audit event with a system author' do
      subject.execute(group_link, skip_authorization: true)

      event = AuditEventReader.last
      expect(AuditEventReader.count).to eq(1)
      expect(event.author.name).to eq('(System)')
      expect(event.details[:event_name]).to eq('project_group_link_deleted')
    end
  end

  context 'for refresh user addon assignments' do
    let(:worker) { GitlabSubscriptions::AddOnPurchases::RefreshUserAssignmentsWorker }

    context 'when on self managed' do
      it 'does not enqueue CleanupUserAddOnAssignmentWorker' do
        expect(worker).not_to receive(:perform_async)

        subject.execute(group_link)
      end
    end

    context 'when on SaaS', :saas do
      it 'enqueues RefreshUserAssignmentsWorker with correct arguments' do
        expect(worker).to receive(:perform_async).with(project.root_ancestor.id)

        subject.execute(group_link)
      end
    end
  end

  describe "link.group members' ::Authz::UserProjectMemberRole records" do
    it 'enqueues a ::Authz::UserProjectMemberRoles::DestroyForSharedProjectWorker job' do
      expect(::Authz::UserProjectMemberRoles::DestroyForSharedProjectWorker)
        .to receive(:perform_async).with(group_link.project_id, group_link.group_id)

      service.execute(group_link)
    end

    context 'when cache_user_project_member_roles feature flag is disabled' do
      before do
        stub_feature_flags(cache_user_project_member_roles: false)
      end

      it 'does not enqueue an ::Authz::UserProjectMemberRoles::DestroyForSharedProjectWorker job' do
        expect(::Authz::UserProjectMemberRoles::DestroyForSharedProjectWorker)
          .not_to receive(:perform_async)

        service.execute(group_link)
      end
    end
  end
end
