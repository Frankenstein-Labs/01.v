# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::MemberManagement::MinimalAccessProvisioningNotificationWorker, feature_category: :seat_cost_management do
  it_behaves_like 'an idempotent worker'

  describe '#perform' do
    it 'calls MinimalAccessProvisioningNotificationService' do
      expect(GitlabSubscriptions::MemberManagement::MinimalAccessProvisioningNotificationService)
        .to receive(:execute)

      described_class.new.perform
    end

    context 'when bso_minimal_access_fallback feature flag is disabled' do
      before do
        stub_feature_flags(bso_minimal_access_fallback: false)
      end

      it 'does not call MinimalAccessProvisioningNotificationService' do
        expect(GitlabSubscriptions::MemberManagement::MinimalAccessProvisioningNotificationService)
          .not_to receive(:execute)

        described_class.new.perform
      end
    end
  end
end
