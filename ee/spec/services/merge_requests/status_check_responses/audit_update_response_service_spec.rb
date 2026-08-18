# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::StatusCheckResponses::AuditUpdateResponseService, feature_category: :compliance_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }
  let_it_be(:external_status_check) { create(:external_status_check, project: project) }
  let_it_be(:status_check_response) do
    create(
      :status_check_response,
      merge_request: merge_request,
      external_status_check: external_status_check,
      sha: merge_request.diff_head_sha,
      status: 'passed'
    )
  end

  subject(:service) { described_class.new(status_check_response, user) }

  describe '#execute' do
    let(:audit_context) do
      {
        name: 'status_check_response_update',
        author: user,
        scope: project,
        target: merge_request,
        message: "Updated response for status check #{external_status_check.name} to #{status_check_response.status}",
        additional_details: {
          external_status_check_id: external_status_check.id,
          external_status_check_name: external_status_check.name,
          status: status_check_response.status,
          sha: status_check_response.sha,
          merge_request_id: merge_request.id,
          merge_request_iid: merge_request.iid
        }
      }
    end

    it 'logs an audit event' do
      expect(::Gitlab::Audit::Auditor).to receive(:audit).with(audit_context)

      service.execute
    end

    context 'when current_user is nil' do
      let(:user) { nil }

      it 'logs an audit event with an unauthenticated author' do
        expected_context = audit_context.merge(author: have_attributes(class: ::Gitlab::Audit::UnauthenticatedAuthor,
          name: '(System)'))
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(expected_context)

        service.execute
      end
    end
  end
end
