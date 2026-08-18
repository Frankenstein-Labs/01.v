# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SystemNoteService, feature_category: :team_planning do
  include ProjectForksHelper
  include Gitlab::Routing
  include RepoHelpers

  let_it_be(:group)         { create(:group) }
  let_it_be(:project)       { create(:project, group: group) }
  let_it_be(:author)        { create(:user) }
  let_it_be(:noteable)      { create(:issue, project: project) }
  let_it_be(:issue)         { noteable }
  let_it_be(:epic)          { create(:epic, group: group) }
  let_it_be(:noteable_ref)  { create(:issue, project: project) }

  describe '.change_health_status_note' do
    it 'calls IssuableService' do
      expect_next_instance_of(::SystemNotes::IssuablesService) do |service|
        expect(service).to receive(:change_health_status_note)
      end

      described_class.change_health_status_note(noteable, project, author, nil)
    end
  end

  describe '.change_progress_note' do
    it 'calls IssuableService' do
      expect_next_instance_of(::SystemNotes::IssuablesService) do |service|
        expect(service).to receive(:change_progress_note)
      end

      described_class.change_progress_note(noteable, author)
    end
  end

  describe '.change_checkin_reminder_note' do
    it 'calls IssuableService' do
      expect_next_instance_of(::SystemNotes::IssuablesService) do |service|
        expect(service).to receive(:change_checkin_reminder_note)
      end

      described_class.change_checkin_reminder_note(noteable, author)
    end
  end

  describe '.change_epic_date_note' do
    let(:date_type) { double }
    let(:date) { double }

    it 'calls EpicsService' do
      expect_next_instance_of(SystemNotes::EpicsService) do |service|
        expect(service).to receive(:change_epic_date_note).with(date_type, date)
      end

      described_class.change_epic_date_note(noteable, author, date_type, date)
    end
  end

  describe '.merge_train' do
    let(:merge_train) { double }

    it 'calls MergeTrainService' do
      expect_next_instance_of(SystemNotes::MergeTrainService) do |service|
        expect(service).to receive(:enqueue).with(merge_train)
      end

      described_class.merge_train(noteable, project, author, merge_train)
    end
  end

  describe '.cancel_merge_train' do
    it 'calls MergeTrainService' do
      expect_next_instance_of(SystemNotes::MergeTrainService) do |service|
        expect(service).to receive(:cancel)
      end

      described_class.cancel_merge_train(noteable, project, author)
    end
  end

  describe '.abort_merge_train' do
    let(:message) { double }

    it 'calls MergeTrainService' do
      expect_next_instance_of(SystemNotes::MergeTrainService) do |service|
        expect(service).to receive(:abort).with(message)
      end

      described_class.abort_merge_train(noteable, project, author, message)
    end
  end

  describe '.add_to_merge_train_when_checks_pass' do
    let(:sha) { double }

    it 'calls MergeTrainService' do
      expect_next_instance_of(SystemNotes::MergeTrainService) do |service|
        expect(service).to receive(:add_when_checks_pass).with(sha)
      end

      described_class.add_to_merge_train_when_checks_pass(noteable, project, author, sha)
    end
  end

  describe '.cancel_add_to_merge_train_when_checks_pass' do
    it 'calls MergeTrainService' do
      expect_next_instance_of(SystemNotes::MergeTrainService) do |service|
        expect(service).to receive(:cancel_add_when_checks_pass)
      end

      described_class.cancel_add_to_merge_train_when_checks_pass(noteable, project, author)
    end
  end

  describe '.abort_add_to_merge_train_when_checks_pass' do
    let(:message) { double }

    it 'calls MergeTrainService' do
      expect_next_instance_of(SystemNotes::MergeTrainService) do |service|
        expect(service).to receive(:abort_add_when_checks_pass).with(message)
      end

      described_class.abort_add_to_merge_train_when_checks_pass(noteable, project, author, message)
    end
  end

  describe '.change_vulnerability_state' do
    it 'calls VulnerabilitiesService' do
      expect_next_instance_of(SystemNotes::VulnerabilitiesService) do |service|
        expect(service).to receive(:change_vulnerability_state)
      end

      described_class.change_vulnerability_state(noteable, author)
    end
  end

  describe '.publish_issue_to_status_page' do
    it 'calls IssuablesService' do
      expect_next_instance_of(::SystemNotes::IssuablesService) do |service|
        expect(service).to receive(:publish_issue_to_status_page)
      end

      described_class.publish_issue_to_status_page(noteable, project, author)
    end
  end

  describe '.start_escalation' do
    let(:policy) { double(project: project) }

    it 'calls EscalationsService' do
      expect_next_instance_of(::SystemNotes::EscalationsService) do |service|
        expect(service).to receive(:start_escalation).with(policy, author)
      end

      described_class.start_escalation(noteable, policy, author)
    end
  end

  describe '.block_issuable' do
    it 'calls IssuablesService' do
      expect_next_instance_of(::SystemNotes::IssuablesService) do |service|
        expect(service).to receive(:block_issuable).with(noteable_ref)
      end

      described_class.block_issuable(noteable, noteable_ref, author)
    end
  end

  describe '.blocked_by_issuable' do
    it 'calls IssuablesService' do
      expect_next_instance_of(::SystemNotes::IssuablesService) do |service|
        expect(service).to receive(:blocked_by_issuable).with(noteable_ref)
      end

      described_class.blocked_by_issuable(noteable, noteable_ref, author)
    end
  end

  describe '.issuable_resource_link_added' do
    it 'calls IssuableResourceLinksService' do
      expect_next_instance_of(::SystemNotes::IssuableResourceLinksService) do |service|
        expect(service).to receive(:issuable_resource_link_added).with('zoom')
      end

      described_class.issuable_resource_link_added(noteable, project, author, 'zoom')
    end
  end

  describe '.issuable_resource_link_removed' do
    it 'calls IssuableResourceLinksService' do
      expect_next_instance_of(::SystemNotes::IssuableResourceLinksService) do |service|
        expect(service).to receive(:issuable_resource_link_removed).with('zoom')
      end

      described_class.issuable_resource_link_removed(noteable, project, author, 'zoom')
    end
  end

  describe '.approvals_reset' do
    let(:cause) { :new_push }
    let(:approvers) { [] }

    it 'calls MergeRequestsService' do
      expect_next_instance_of(::SystemNotes::MergeRequestsService) do |service|
        expect(service).to receive(:approvals_reset).with(cause, approvers)
      end

      described_class.approvals_reset(noteable, author, cause, approvers)
    end
  end

  describe '.override_requested_changes' do
    it 'calls MergeRequestsService' do
      expect_next_instance_of(::SystemNotes::MergeRequestsService) do |service|
        expect(service).to receive(:override_requested_changes).with(true)
      end

      described_class.override_requested_changes(noteable, author, true)
    end
  end

  describe '.change_color_note' do
    it 'calls IssuableResourceLinksService' do
      expect_next_instance_of(::SystemNotes::IssuablesService) do |service|
        expect(service).to receive(:change_color_note).with('#0052cc')
      end

      described_class.change_color_note(noteable, author, '#0052cc')
    end
  end

  describe '.amazon_q_called' do
    it 'calls AmazonQ' do
      expect_next_instance_of(::SystemNotes::IssuablesService) do |service|
        expect(service).to receive(:amazon_q_called).with('test')
      end

      described_class.amazon_q_called(noteable, author, 'test')
    end
  end

  describe '.agent_session_started' do
    let(:session_id) { '123' }
    let(:trigger_source) { 'User' }
    let(:service_account_user) { instance_double(User) }

    it 'calls AgentsService' do
      expect_next_instance_of(::SystemNotes::AgentsService) do |service|
        expect(service).to receive(:agent_session_started).with(session_id, trigger_source, service_account_user)
      end

      described_class.agent_session_started(noteable, project, session_id, trigger_source, service_account_user)
    end
  end

  describe '.agent_session_completed' do
    let(:session_id) { '123' }
    let(:service_account_user) { instance_double(User) }

    it 'calls AgentsService' do
      expect_next_instance_of(::SystemNotes::AgentsService) do |service|
        expect(service).to receive(:agent_session_completed).with(session_id, service_account_user)
      end

      described_class.agent_session_completed(noteable, project, session_id, service_account_user)
    end
  end

  describe '.agent_session_failed' do
    let(:session_id) { '123' }
    let(:reason) { 'dropped' }
    let(:service_account_user) { instance_double(User) }

    it 'calls AgentsService' do
      expect_next_instance_of(::SystemNotes::AgentsService) do |service|
        expect(service).to receive(:agent_session_failed).with(session_id, service_account_user, reason)
      end

      described_class.agent_session_failed(noteable, project, session_id, service_account_user, reason)
    end
  end
end
