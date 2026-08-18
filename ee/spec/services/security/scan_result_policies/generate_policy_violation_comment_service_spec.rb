# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::GeneratePolicyViolationCommentService, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be_with_reload(:merge_request) { create(:merge_request, source_project: project) }
  let(:report_type) { 'scan_finding' }
  let(:requires_approval) { true }

  describe '#execute' do
    subject(:execute) { service.execute }

    let_it_be(:bot_user) { Users::Internal.in_organization(project.organization).security_bot }

    let(:service) { described_class.new(merge_request) }
    let(:expected_optional_approvals_note) { 'Consider including optional reviewers' }
    let(:expected_violation_note) { 'ask eligible approvers of each policy to approve this merge request' }
    let(:expected_fixed_note) { 'Security policy violations have been resolved' }
    let_it_be(:policy) { create(:scan_result_policy_read, :with_approval_policy_rule, project: project) }

    shared_examples 'successful service response' do
      it 'returns a successful service response' do
        result = execute

        expect(result).to be_kind_of(ServiceResponse)
        expect(result.success?).to eq(true)
      end
    end

    def create_violation(requires_approval: true, report_type: :scan_finding, policy_read: policy)
      create(:report_approver_rule, report_type, merge_request: merge_request, scan_result_policy_read: policy_read,
        approval_policy_rule: policy_read.approval_policy_rule,
        approvals_required: requires_approval ? 1 : 0)
      create(:scan_result_policy_violation, merge_request: merge_request, project: project,
        scan_result_policy_read: policy_read, approval_policy_rule: policy_read.approval_policy_rule)
    end

    before do
      create_violation(requires_approval: requires_approval) if violated_policy
    end

    context 'when error occurs while saving the note' do
      let(:violated_policy) { true }

      before do
        errors_double = instance_double(ActiveModel::Errors, empty?: false, full_messages: ['error message'])
        allow_next_instance_of(::Note) do |note|
          allow(note).to receive(:save).and_return(false)
          allow(note).to receive(:errors).and_return(errors_double)
        end
      end

      it 'returns error details in the result' do
        result = execute

        expect(result.success?).to eq(false)
        expect(result.message).to contain_exactly('error message')
      end
    end

    context 'when error occurs while trying to obtain the lock' do
      let(:violated_policy) { true }

      before do
        allow(service).to receive(:in_lock).and_raise(Gitlab::ExclusiveLeaseHelpers::FailedToObtainLockError)
      end

      it 'returns error details in the result' do
        result = execute

        expect(result.success?).to eq(false)
        expect(result.message).to contain_exactly('Failed to obtain an exclusive lock')
      end
    end

    context 'when there is no bot comment yet' do
      let(:last_note) { merge_request.notes.last }

      context 'when policy has been violated' do
        let(:violated_policy) { true }

        it_behaves_like 'successful service response'

        it 'creates a comment' do
          execute

          expect(last_note.note).to include(expected_violation_note, report_type)
          expect(last_note.author).to eq(bot_user)
        end

        it 'does not touch merge request' do
          merge_request.update!(updated_at: 1.day.ago)

          expect { execute }.not_to change { merge_request.reload.updated_at }
        end
      end

      context 'with multiple violations' do
        let(:violated_policy) { true }
        let_it_be(:policy2) { create(:scan_result_policy_read, :with_approval_policy_rule, project: project) }

        before do
          create_violation(report_type: :license_scanning, policy_read: policy2)
          execute
        end

        it 'creates a comment and includes all relevant report types' do
          expect(last_note.note).to include('license_scanning,scan_finding')
        end
      end

      shared_examples 'bot message disabled policy behavior' do
        context 'when a violated policy has bot messages disabled' do
          let(:violated_policy) { true }

          before do
            create_violation(report_type: :license_scanning, policy_read: bot_message_disabled_policy)
            execute
          end

          it 'excludes the report type from the bot-message-disabled policy' do
            expect(last_note.note).to include('scan_finding')
            expect(last_note.note).not_to include('license_scanning')
          end
        end

        context 'when the only violated policy has bot messages disabled' do
          let(:violated_policy) { false }

          before do
            create_violation(policy_read: bot_message_disabled_policy)
            execute
          end

          it_behaves_like 'successful service response'

          it 'does not create a comment' do
            expect(merge_request.notes).to be_empty
          end
        end
      end

      context 'when security_policy_bot message is disabled in the policy' do
        let_it_be(:bot_message_disabled_approval_rule) do
          create(:approval_policy_rule, :scan_finding,
            security_policy: create(:security_policy, :with_disabled_bot_message))
        end

        let_it_be(:bot_message_disabled_policy) do
          create(:scan_result_policy_read, :with_approval_policy_rule, project: project,
            approval_policy_rule: bot_message_disabled_approval_rule)
        end

        it_behaves_like 'bot message disabled policy behavior'

        context 'when deprecate_scan_result_policies is disabled' do
          before do
            stub_feature_flags(deprecate_scan_result_policies: false)
          end

          let_it_be(:bot_message_disabled_policy) do
            create(:scan_result_policy_read, :with_approval_policy_rule, :with_send_bot_message,
              project: project, bot_message_enabled: false)
          end

          it_behaves_like 'bot message disabled policy behavior'
        end
      end

      context 'when policy has been violated with optional approvals' do
        let(:violated_policy) { true }
        let(:requires_approval) { false }

        before do
          execute
        end

        it_behaves_like 'successful service response'

        it 'creates a comment' do
          expect(last_note.note).to include(expected_optional_approvals_note, report_type)
          expect(last_note.author).to eq(bot_user)
        end
      end

      context 'when there was no policy violation' do
        let(:violated_policy) { false }

        before do
          execute
        end

        it_behaves_like 'successful service response'

        it 'does not create a comment' do
          expect(merge_request.notes).to be_empty
        end
      end
    end

    context 'when there is already a bot comment' do
      include Security::PolicyBotCommentHelpers

      let(:violated_reports) { report_type }
      let!(:bot_comment) do
        create_policy_bot_comment(merge_request, violated_reports: violated_reports)
      end

      describe 'note body' do
        before do
          execute
          bot_comment.reload
        end

        context 'when policy has been violated' do
          let(:violated_policy) { true }

          it_behaves_like 'successful service response'

          it 'updates the comment with a violated note' do
            expect(bot_comment.note).to include(expected_violation_note)
          end

          context 'when the existing violation was from another report_type' do
            let(:violated_reports) { 'license_scanning' }
            let(:report_type) { 'scan_finding' }

            it 'updates the comment with a violated note and overwrites existing violated reports' do
              expect(bot_comment.note).to include(expected_violation_note)
              expect(bot_comment.note).to include('scan_finding')
            end
          end

          context 'when the existing comment was violated with optional approvals' do
            let!(:bot_comment) do
              create_policy_bot_comment(merge_request, violated_reports: violated_reports)
            end

            it 'updates the comment and removes the optional approvals section' do
              expect(bot_comment.note).to include(expected_violation_note)
              expect(bot_comment.note).not_to include('<!-- optional_approvals')
            end
          end
        end

        context 'when policy has been violated with optional approvals' do
          let(:violated_policy) { true }
          let(:requires_approval) { false }

          it_behaves_like 'successful service response'

          it 'updates the comment with a violated note' do
            expect(bot_comment.note).to include(expected_optional_approvals_note)
          end

          context 'when the existing violation required approvals and was from another report_type' do
            let(:violated_reports) { 'license_scanning' }
            let(:report_type) { 'scan_finding' }

            it 'updates the comment with a violated note and overwrites existing violated reports' do
              expect(bot_comment.note).to include(expected_optional_approvals_note)
              expect(bot_comment.note).to include('scan_finding')
            end
          end
        end

        context 'when there was no policy violation' do
          let(:violated_policy) { false }

          it_behaves_like 'successful service response'

          it 'updates the comment with fixed note' do
            expect(bot_comment.note).to include(expected_fixed_note)
          end

          context 'when the existing violation was from another report_type' do
            let(:violated_reports) { 'license_scanning' }
            let(:report_type) { 'scan_finding' }

            it 'updates the comment with an fixed note and overwrites violated reports' do
              expect(bot_comment.note).to include(expected_fixed_note)
            end
          end
        end
      end

      describe 'merge request' do
        let(:violated_policy) { true }

        before do
          merge_request.update!(updated_at: 1.day.ago)
        end

        it 'does not touch merge request' do
          expect { execute }.not_to change { merge_request.reload.updated_at }
        end
      end
    end

    context 'when there is another comment by security_bot' do
      let(:violated_policy) { true }
      let_it_be_with_reload(:other_bot_comment) do
        create(:note, project: project, noteable: merge_request, author: bot_user, note: 'Previous comment')
      end

      it_behaves_like 'successful service response'

      it 'creates a new comment with a violated note' do
        expect { execute }.to change { merge_request.notes.count }.by(1)

        bot_comment = merge_request.notes.last

        expect(other_bot_comment.note).to eq('Previous comment')
        expect(bot_comment.note).to include(expected_violation_note)
      end
    end

    context 'when there is a comment from another user and there is a violation' do
      let(:violated_policy) { true }

      before do
        create(:note, project: project, noteable: merge_request, note: 'Other comment')

        execute
      end

      it_behaves_like 'successful service response'

      it 'creates a bot comment' do
        bot_comment = merge_request.notes.last

        expect(merge_request.notes.count).to eq(2)
        expect(bot_comment.note).to include(expected_violation_note)
      end
    end
  end
end
