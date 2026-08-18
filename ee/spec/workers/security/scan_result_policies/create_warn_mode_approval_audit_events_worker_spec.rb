# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::CreateWarnModeApprovalAuditEventsWorker, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { project.creator }
  let_it_be_with_reload(:merge_request) { create(:merge_request, source_project: project) }

  let(:merge_request_id) { merge_request.id }
  let(:current_user_id) { project.creator.id }
  let(:event) do
    MergeRequests::ApprovedEvent.new(data: { merge_request_id: merge_request_id, current_user_id: current_user_id })
  end

  subject(:handle_event) { described_class.new.handle_event(event) }

  before do
    stub_licensed_features(security_orchestration_policies: true)
  end

  describe '.dispatch?' do
    let(:event) do
      MergeRequests::ApprovedEvent.new(
        data: { current_user_id: user.id, merge_request_id: merge_request_id, approved_at: Time.zone.now.iso8601 }
      )
    end

    subject(:dispatch?) { described_class.dispatch?(event) }

    context 'with valid merge request ID' do
      let(:merge_request_id) { merge_request.id }

      it { is_expected.to be(true) }

      context 'without licensed feature' do
        before do
          stub_licensed_features(security_orchestration_policies: false)
        end

        it { is_expected.to be(false) }
      end
    end

    context 'with invalid merge request ID' do
      let(:merge_request_id) { non_existing_record_id }

      it { is_expected.to be(false) }
    end
  end

  describe '#handle_event' do
    shared_examples 'calls service' do
      specify do
        expect_next_instance_of(
          Security::ScanResultPolicies::CreateWarnModeApprovalAuditEventService, merge_request, user
        ) do |service|
          expect(service).to receive(:execute)
        end

        handle_event
      end
    end

    shared_examples 'does not call service' do
      specify do
        expect(Security::ScanResultPolicies::CreateWarnModeApprovalAuditEventService).not_to receive(:new)

        handle_event
      end
    end

    context 'with valid merge request and user ID' do
      include_examples 'calls service'

      context 'without licensed feature' do
        before do
          stub_licensed_features(security_orchestration_policies: false)
        end

        include_examples 'does not call service'
      end

      context 'when merge request is not open' do
        before do
          merge_request.close!
        end

        include_examples 'does not call service'
      end
    end

    context 'with invalid merge request ID' do
      let(:merge_request_id) { non_existing_record_id }

      include_examples 'does not call service'
    end

    context 'with invalid user ID' do
      let(:current_user_id) { non_existing_record_id }

      include_examples 'does not call service'
    end
  end
end
