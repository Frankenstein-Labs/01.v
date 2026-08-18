# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::TimeoutPendingStatusCheckResponsesWorker, feature_category: :compliance_management do
  describe "#perform" do
    let_it_be(:worker) { described_class.new }
    let_it_be_with_reload(:old_pending_status_check_response) { create(:old_pending_status_check_response) }
    let_it_be_with_reload(:old_passed_status_check_response) { create(:old_passed_status_check_response) }
    let_it_be_with_reload(:old_failed_status_check_response) { create(:old_failed_status_check_response) }
    let_it_be_with_reload(:old_retried_pending_status_check_response) do
      create(:old_retried_pending_status_check_response)
    end

    let_it_be_with_reload(:recent_pending_status_check_response) { create(:status_check_response, :pending) }
    let_it_be_with_reload(:recent_retried_pending_status_check_response) do
      create(:recent_retried_pending_status_check_response)
    end

    it 'sets qualified `pending` status check responses to failed' do
      worker.perform

      expect(recent_pending_status_check_response.status).to eq('pending')
      expect(recent_retried_pending_status_check_response.status).to eq('pending')

      expect(old_pending_status_check_response.status).to eq('failed')
      expect(old_retried_pending_status_check_response.status).to eq('failed')
    end

    it 'enqueues a audit update status check response worker with the qualified IDs' do
      expect(::MergeRequests::AuditUpdateStatusCheckResponseWorker).to receive(:perform_async).with(
        match_array([old_pending_status_check_response.id, old_retried_pending_status_check_response.id])
      )

      worker.perform
    end

    it 'does not update existing `passed` or `failed` status check responses' do
      expect(old_passed_status_check_response.status).to eq('passed')
      expect(old_failed_status_check_response.status).to eq('failed')
    end

    it_behaves_like 'an idempotent worker'
  end
end
