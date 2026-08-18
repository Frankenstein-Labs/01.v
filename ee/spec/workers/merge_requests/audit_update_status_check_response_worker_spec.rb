# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::AuditUpdateStatusCheckResponseWorker, feature_category: :compliance_management do
  let_it_be(:response_1) { create(:status_check_response) }
  let_it_be(:response_2) { create(:status_check_response) }
  let_it_be(:non_existent_id) { non_existing_record_id }

  let(:response_ids) { [response_1.id, response_2.id] }

  subject(:perform_worker) { described_class.new.perform(response_ids) }

  it_behaves_like 'an idempotent worker' do
    let(:job_args) { [[response_1.id, response_2.id]] }
  end

  describe '#perform' do
    it 'calls the AuditUpdateResponseService for each status check response' do
      [response_1, response_2].each do |response|
        expect_next_instance_of(::MergeRequests::StatusCheckResponses::AuditUpdateResponseService,
          response) do |service|
          expect(service).to receive(:execute)
        end
      end

      perform_worker
    end

    context 'when some response IDs do not exist' do
      let(:response_ids) { [response_1.id, non_existent_id] }

      it 'only calls the service for existing responses' do
        expect_next_instance_of(::MergeRequests::StatusCheckResponses::AuditUpdateResponseService,
          response_1) do |service|
          expect(service).to receive(:execute).once
        end

        perform_worker
      end
    end

    context 'when an empty array of IDs is provided' do
      let(:response_ids) { [] }

      it 'does not call the service' do
        allow(::MergeRequests::StatusCheckResponses::AuditUpdateResponseService).to receive(:new)
        expect(::MergeRequests::StatusCheckResponses::AuditUpdateResponseService).not_to have_received(:new)

        perform_worker
      end
    end
  end
end
