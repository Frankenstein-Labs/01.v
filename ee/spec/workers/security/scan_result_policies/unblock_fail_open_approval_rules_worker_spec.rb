# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::UnblockFailOpenApprovalRulesWorker, "#execute", feature_category: :security_policy_management do
  let(:unblock_service) { Security::ScanResultPolicies::UnblockFailOpenApprovalRulesService }

  subject(:perform) { described_class.new.perform(merge_request_id) }

  context "with merge request found" do
    let(:merge_request_id) { create(:merge_request).id }

    specify do
      expect_next_instance_of(unblock_service, merge_request: instance_of(MergeRequest)) do |service|
        expect(service).to receive(:execute)
      end

      perform
    end
  end

  context "without merge request found" do
    let(:merge_request_id) { non_existing_record_id }

    specify do
      expect(unblock_service).not_to receive(:new).and_call_original

      perform
    end
  end
end
