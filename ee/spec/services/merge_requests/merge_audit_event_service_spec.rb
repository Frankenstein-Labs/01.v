# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::MergeAuditEventService, feature_category: :compliance_management do
  let(:merger) { create :user }
  let(:approver) { create :user, username: 'approver one' }
  let(:mr_author) { create :user, username: 'author one' }
  let(:project) { create :project, :repository }
  let!(:merge_time) { Time.now.utc }
  let(:merge_request) do
    create :merge_request,
      :with_productivity_metrics,
      :with_merged_metrics,
      :merged,
      title: 'MR One',
      description: 'This was a triumph',
      author: mr_author,
      source_project: project
  end

  let!(:approval) do
    create :approval,
      merge_request: merge_request,
      user: approver,
      patch_id_sha: merge_request.current_patch_id_sha
  end

  subject(:audit_service) { described_class.new merge_request: merge_request }

  before do
    merge_request.metrics.update_columns merged_by_id: merger.id, merged_at: merge_time
  end

  describe '#execute' do
    it 'audits the event' do
      audit_context = {
        name: 'merge_request_merged',
        author: merger,
        scope: merge_request.project,
        target: merge_request,
        message: 'Merge request merged',
        additional_details: hash_including({
          title: 'MR One',
          approvers: ['approver one'],
          approving_committers: [],
          approving_author: false,
          merged_at: merge_time,
          commit_shas: merge_request.commits.commits.map(&:sha),
          required_approvals: 0,
          approval_count: 1,
          description: 'This was a triumph',
          target_project_id: project.id
        })
      }
      expect(::Gitlab::Audit::Auditor).to receive(:audit).with(audit_context).and_call_original

      audit_service.execute
    end

    context 'when author approves' do
      let!(:approval) do
        create :approval,
          merge_request: merge_request,
          user: mr_author,
          patch_id_sha: merge_request.current_patch_id_sha
      end

      it 'audits with approving author' do
        audit_context = hash_including({
          name: 'merge_request_merged',
          additional_details: hash_including({
            approvers: ['author one'],
            approving_committers: [],
            approving_author: true
          })
        })
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(audit_context).and_call_original

        audit_service.execute
      end
    end

    context 'with approving committers' do
      it 'audits with approving committer' do
        allow(merge_request).to receive(:committers).and_return(User.where(id: approver.id))

        audit_context = hash_including({
          name: 'merge_request_merged',
          additional_details: hash_including({
            approvers: ['approver one'],
            approving_committers: ['approver one']
          })
        })

        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(audit_context).and_call_original

        audit_service.execute
      end
    end

    context 'with required approvals' do
      it 'audits with required approvals' do
        allow(merge_request).to receive(:approvals_required).and_return(2)

        audit_context = hash_including({
          name: 'merge_request_merged',
          additional_details: hash_including({
            approvers: ['approver one'],
            required_approvals: 2,
            approval_count: 1
          })
        })

        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(audit_context).and_call_original

        audit_service.execute
      end
    end
  end
end
