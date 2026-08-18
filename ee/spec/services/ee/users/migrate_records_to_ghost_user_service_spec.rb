# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::MigrateRecordsToGhostUserService, feature_category: :user_management do
  let!(:user) { create(:user) }
  let(:service) { described_class.new(user, admin, execution_tracker) }
  let(:execution_tracker) { instance_double(::Gitlab::Utils::ExecutionTracker, over_limit?: false) }

  let_it_be(:admin) { create(:admin) }
  let_it_be(:ghost_user) { create(:user, :ghost) }

  before do
    allow(Users::Internal).to receive(:ghost).and_return(ghost_user)
  end

  context "when migrating a user's associated records to the ghost user" do
    context 'for epics' do
      context 'when deleted user is present as both author and edited_user' do
        include_examples 'migrating records to the ghost user', Epic, [:author, :last_edited_by] do
          let(:created_record) do
            create(:epic, group: create(:group), author: user, last_edited_by: user, last_edited_at: Time.current)
          end
        end
      end

      context 'when deleted user is present only as edited_user' do
        include_examples 'migrating records to the ghost user', Epic, [:last_edited_by] do
          let(:created_record) do
            create(:epic, group: create(:group),
              author: create(:user), last_edited_by: user, last_edited_at: Time.current)
          end
        end
      end
    end

    context 'for vulnerability_feedback author' do
      include_examples 'migrating records to the ghost user', Vulnerabilities::Feedback, [:author] do
        let(:created_record) { create(:vulnerability_feedback, author: user) }
      end
    end

    context 'for vulnerability_feedback comment author' do
      include_examples 'migrating records to the ghost user', Vulnerabilities::Feedback, [:comment_author] do
        let(:created_record) { create(:vulnerability_feedback, comment_author: user) }
      end
    end

    context 'for vulnerability author' do
      include_examples 'migrating records to the ghost user', Vulnerability, [:author] do
        let(:created_record) { create(:vulnerability, author: user) }
      end
    end

    context 'for vulnerability_external_issue_link author' do
      include_examples 'migrating records to the ghost user', Vulnerabilities::ExternalIssueLink, [:author] do
        let(:created_record) { create(:vulnerabilities_external_issue_link, author: user) }
      end
    end

    context 'for resource_iteration_events' do
      let(:always_ghost) { true }

      include_examples 'migrating records to the ghost user', ResourceIterationEvent, [:user] do
        let(:created_record) do
          create(
            :resource_iteration_event,
            issue: create(:issue),
            user: user,
            iteration: create(:iteration)
          )
        end
      end
    end

    context 'for resource_link_events' do
      let(:always_ghost) { true }

      include_examples 'migrating records to the ghost user', ::WorkItems::ResourceLinkEvent, [:user] do
        let(:created_record) do
          create(
            :resource_link_event,
            issue: create(:issue),
            child_work_item: create(:work_item),
            user: user
          )
        end
      end
    end
  end

  context 'on post-migrate cleanups' do
    subject(:operation) { service.execute }

    describe 'audit events' do
      it 'sends the audit event for user migration to ghost' do
        audit_context = {
          name: 'user_records_migrated_to_ghost',
          author: admin,
          scope: user,
          target: user,
          target_details: user.full_path,
          message: 'User records migrated to ghost user',
          additional_details: {
            action: 'migrate_to_ghost',
            author_name: admin.name,
            target_id: user.id,
            target_type: 'User'
          }
        }

        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(audit_context)

        operation
      end

      it 'does not send audit event when user is not destroyed' do
        expect(user).to receive(:destroy).and_return(user)
        expect(user).to receive(:destroyed?).and_return(false)

        expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

        operation
      end
    end
  end
end
