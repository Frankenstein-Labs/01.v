# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::StatusCheckResponses::CreateService, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be_with_reload(:merge_request) { create(:merge_request, source_project: project, target_project: project) }
  let_it_be(:external_status_check) { create(:external_status_check, project: project) }
  let_it_be(:user) { create(:user) }
  let_it_be(:sha) { SecureRandom.hex(20) }
  let_it_be(:status) { 'passed' }

  let(:service) do
    described_class.new(
      project: project,
      current_user: user,
      params: {
        external_status_check: external_status_check,
        status: status,
        sha: sha
      })
  end

  describe '#execute' do
    subject(:service_response) { service.execute(merge_request) }

    context 'when external status checks feature is disabled' do
      before do
        stub_licensed_features(external_status_checks: false)
      end

      it 'returns error response with not_found status' do
        expect(service_response).to be_error
        expect(service_response.reason).to eq(:not_found)
      end
    end

    context 'when external status checks feature is enabled' do
      before do
        stub_licensed_features(external_status_checks: true)
      end

      context 'when user does not have permission to provide status check response' do
        it 'returns error response with not_found status' do
          expect(service_response).to be_error
          expect(service_response.reason).to eq(:not_found)
        end
      end

      context 'when user has permission to provide status check response' do
        before_all do
          project.add_developer(user)
        end

        context 'when status check response is saved successfully' do
          it 'creates a new status check response, triggers the subscription and logs an audit event',
            :aggregate_failures do
            expect(GraphqlTriggers).to receive(:merge_request_merge_status_updated).with(merge_request).once

            expect(::MergeRequests::StatusCheckResponses::AuditUpdateResponseService).to receive(:new).with(
              an_instance_of(MergeRequests::StatusCheckResponse), user
            ).and_call_original

            expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
              name: 'status_check_response_update',
              author: user,
              scope: project,
              target: merge_request,
              message: "Updated response for status check #{external_status_check.name} to passed",
              additional_details: {
                external_status_check_id: external_status_check.id,
                external_status_check_name: external_status_check.name,
                status: 'passed',
                sha: sha,
                merge_request_id: merge_request.id,
                merge_request_iid: merge_request.iid
              }
            )

            expect { service_response }.to change { merge_request.status_check_responses.count }.by(1)

            created_response = merge_request.status_check_responses.order(:id).last

            expect(created_response.external_status_check).to eq(external_status_check)
            expect(created_response.status).to eq('passed')
            expect(created_response.sha).to eq(sha)

            result = service_response

            expect(result).to be_success
          end
        end

        context 'when status check response fails to save' do
          let(:sha) { nil }

          it 'returns error response with validation errors and does not log audit event or trigger subscription' do
            expect(::Gitlab::Audit::Auditor).not_to receive(:audit)
            expect(GraphqlTriggers).not_to receive(:merge_request_merge_status_updated)

            result = service_response

            expect(result).to be_error
            expect(result.message).to eq('Failed to create status check response')
            expect(result.payload[:errors]).to match_array(["Sha can't be blank"])
            expect(result.reason).to eq(:bad_request)
          end
        end
      end
    end
  end
end
