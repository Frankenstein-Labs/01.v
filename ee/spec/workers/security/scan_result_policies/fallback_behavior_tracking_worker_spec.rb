# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::FallbackBehaviorTrackingWorker, '#perform', feature_category: :security_policy_management do
  subject(:perform) { described_class.new.perform(merge_request_id) }

  context "with merge request" do
    let_it_be(:merge_request) { create(:merge_request) }
    let(:merge_request_id) { merge_request.id }

    specify do
      expect(Security::ScanResultPolicies::FallbackBehaviorTrackingService)
        .to receive(:new).with(merge_request).and_call_original

      perform
    end
  end

  context "without merge request" do
    let(:merge_request_id) { non_existing_record_id }

    specify do
      expect(Security::ScanResultPolicies::FallbackBehaviorTrackingService).not_to receive(:new)

      perform
    end
  end
end
