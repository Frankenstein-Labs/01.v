# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::StatusCheckResponse, type: :model, feature_category: :compliance_management do
  subject { build(:status_check_response) }

  it { is_expected.to belong_to(:merge_request) }
  it { is_expected.to belong_to(:external_status_check).class_name('MergeRequests::ExternalStatusCheck') }

  it { is_expected.to define_enum_for(:status).with_values([:passed, :failed, :pending]) }

  it { is_expected.to validate_presence_of(:merge_request) }
  it { is_expected.to validate_presence_of(:external_status_check) }
  it { is_expected.to validate_presence_of(:sha) }

  describe 'scopes' do
    let_it_be(:old_pending_status_check_response) { create(:old_pending_status_check_response) }
    let_it_be(:old_retried_pending_status_check_response) do
      create(:old_retried_pending_status_check_response)
    end

    let_it_be(:recent_pending_status_check_response) { create(:status_check_response, :pending) }
    let_it_be(:recent_retried_pending_status_check_response) do
      create(:recent_retried_pending_status_check_response)
    end

    describe '.timeout_new' do
      it 'returns the correct status check responses' do
        expect(described_class.timeout_new).to match_array([old_pending_status_check_response])
      end
    end

    describe '.timeout_retried' do
      it 'returns the correct status check responses' do
        expect(described_class.timeout_retried).to match_array([old_retried_pending_status_check_response])
      end
    end

    describe '.timeout_eligible' do
      it 'returns the correct status check responses' do
        expect(described_class.timeout_eligible).to match_array([
          old_pending_status_check_response,
          old_retried_pending_status_check_response
        ])
      end
    end
  end

  describe 'callbacks' do
    subject(:response) { create(:status_check_response, status: status, merge_request: merge_request) }

    let_it_be(:merge_request) { create(:merge_request) }

    describe '#after_save' do
      let(:status) { described_class.statuses[:passed] }

      describe '.publish_new_passing_event' do
        context 'when the check is passed' do
          it 'sends an status passed event' do
            expect { response }.to publish_event(::MergeRequests::ExternalStatusCheckPassedEvent).with({
              merge_request_id: merge_request.id
            })
          end
        end

        context 'when the check is failed' do
          let(:status) { described_class.statuses[:failed] }

          it 'does not sends a status passed event' do
            expect(::Gitlab::EventStore).not_to receive(:publish)

            response
          end
        end

        context 'when the check is pending' do
          let(:status) { described_class.statuses[:pending] }

          it 'does not send a status passed event' do
            expect(::Gitlab::EventStore).not_to receive(:publish)

            response
          end
        end
      end
    end
  end
end
