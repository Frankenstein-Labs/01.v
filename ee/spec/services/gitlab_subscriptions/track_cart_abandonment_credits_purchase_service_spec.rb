# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::TrackCartAbandonmentCreditsPurchaseService, feature_category: :subscription_management do
  let_it_be(:user) { create(:user, onboarding_status_email_opt_in: true) }
  let_it_be(:namespace) { create(:namespace) }

  let(:monthly_commitment_credits) { 100 }

  subject(:service) do
    described_class.new(
      user: user,
      namespace: namespace,
      monthly_commitment_credits: monthly_commitment_credits
    )
  end

  describe '#execute' do
    context 'when user has opted in' do
      it 'enqueues the credits purchase worker' do
        expect(GitlabSubscriptions::CartAbandonmentCreditsPurchaseWorker)
          .to receive(:perform_in)
          .with(
            3.hours,
            user.id,
            namespace.id,
            monthly_commitment_credits
          )

        result = service.execute

        expect(result).to be_success
      end
    end

    context 'when user has not opted in' do
      let(:user) { create(:user, onboarding_status_email_opt_in: false) }

      it 'does not enqueue the worker and returns error' do
        expect(GitlabSubscriptions::CartAbandonmentCreditsPurchaseWorker).not_to receive(:perform_in)

        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq('User opt-in required to track credits purchase')
      end
    end
  end
end
