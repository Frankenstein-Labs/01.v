# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::TrackCartAbandonmentService, feature_category: :subscription_management do
  let_it_be(:user) { create(:user, onboarding_status_email_opt_in: true) }
  let_it_be(:namespace) { create(:namespace) }
  let(:plan) { 'premium' }

  subject(:service) do
    described_class.new(
      user: user,
      namespace: namespace,
      plan: plan
    )
  end

  describe '#execute' do
    context 'when user has opted in and plan is valid' do
      it 'enqueues the cart abandonment worker with Premium plan' do
        expect(GitlabSubscriptions::CartAbandonmentWorker)
          .to receive(:perform_in)
          .with(
            3.hours,
            user.id,
            namespace.id,
            'cart abandonment - SaaS Premium',
            namespace.actual_plan_name
          )

        result = service.execute

        expect(result).to be_success
      end

      context 'with ultimate plan' do
        let(:plan) { 'ultimate' }

        it 'enqueues the cart abandonment worker with Ultimate plan' do
          expect(GitlabSubscriptions::CartAbandonmentWorker)
            .to receive(:perform_in)
            .with(
              3.hours,
              user.id,
              namespace.id,
              'cart abandonment - SaaS Ultimate',
              namespace.actual_plan_name
            )

          result = service.execute

          expect(result).to be_success
        end
      end

      context 'with uppercase plan name' do
        let(:plan) { 'PREMIUM' }

        it 'normalizes the plan name correctly' do
          expect(GitlabSubscriptions::CartAbandonmentWorker)
            .to receive(:perform_in)
            .with(
              3.hours,
              user.id,
              namespace.id,
              'cart abandonment - SaaS Premium',
              namespace.actual_plan_name
            )

          result = service.execute

          expect(result).to be_success
        end
      end
    end

    context 'when plan is invalid' do
      let(:plan) { 'invalid_plan' }

      it 'does not enqueue the worker and returns error' do
        expect(GitlabSubscriptions::CartAbandonmentWorker).not_to receive(:perform_in)

        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq('Invalid plan')
      end
    end

    context 'when plan is nil' do
      let(:plan) { nil }

      it 'does not enqueue the worker and returns error' do
        expect(GitlabSubscriptions::CartAbandonmentWorker).not_to receive(:perform_in)

        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq('Invalid plan')
      end
    end

    context 'when user has not opted in' do
      let(:user) { create(:user, onboarding_status_email_opt_in: false) }

      it 'does not enqueue the worker and returns error' do
        expect(GitlabSubscriptions::CartAbandonmentWorker).not_to receive(:perform_in)

        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq('User opt-in required')
      end
    end

    context 'when user opt-in is nil' do
      let(:user) { create(:user, onboarding_status_email_opt_in: nil) }

      it 'does not enqueue the worker and returns error' do
        expect(GitlabSubscriptions::CartAbandonmentWorker).not_to receive(:perform_in)

        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq('User opt-in required')
      end
    end
  end
end
