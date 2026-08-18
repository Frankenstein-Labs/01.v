# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Provision::SyncComputeMinutesService, feature_category: :plan_provisioning do
  describe '#execute' do
    let_it_be_with_reload(:namespace) do
      create(
        :group,
        :with_ci_minutes,
        ci_minutes_used: 1000,
        extra_shared_runners_minutes_limit: 400,
        last_ci_minutes_notification_at: Date.current,
        last_ci_minutes_usage_notification_level: 50
      )
    end

    subject(:result) { described_class.new(namespace: namespace, params: params).execute }

    context 'when empty params is sent' do
      let(:params) { {} }

      it 'handles it gracefully' do
        expect(namespace).not_to receive(:update)

        expect(result).to be_success
      end
    end

    context 'when updating the extra shared runners minutes limit' do
      let(:params) { { extra_shared_runners_minutes_limit: 100 } }

      it 'updates the extra_shared_runners_minutes_limit value and resets the notification attributes' do
        expect { result }.to change { namespace.reload.extra_shared_runners_minutes_limit }.from(400).to(100)
          .and change { namespace.last_ci_minutes_notification_at }.to(nil)
          .and change { namespace.last_ci_minutes_usage_notification_level }.to(nil)
      end

      it 'ticks instance runners' do
        runner = create(:ci_runner, :instance)

        allow(Ci::Runner).to receive(:instance_type).and_return([runner])
        expect(runner).to receive(:tick_runner_queue)

        expect(result).to be_success
      end

      it 'resets compute minutes data' do
        usage = ::Ci::Minutes::NamespaceMonthlyUsage.current_month.find_by(namespace_id: namespace.id)
        usage.update!(notification_level: 30)

        expect(::Ci::Minutes::RefreshCachedDataService)
          .to receive(:new)
          .with(namespace)
          .and_call_original

        expect do
          expect(result).to be_success
        end.to change { usage.reload.notification_level }
          .to(Ci::Minutes::Notification::PERCENTAGES.fetch(:not_set))
      end
    end

    context 'when updating the shared runners minutes limit' do
      let(:params) { { shared_runners_minutes_limit: 200 } }

      it 'updates the shared_runners_minutes_limit value but does not reset notification attributes' do
        expect { result }.to change { namespace.reload.shared_runners_minutes_limit }.to(200)

        expect(namespace.last_ci_minutes_notification_at).not_to be_nil
        expect(namespace.last_ci_minutes_usage_notification_level).not_to be_nil
      end

      it 'does not tick instance runners' do
        expect(::Ci::Runner).not_to receive(:instance_type)

        expect(result).to be_success
      end

      it 'resets compute minutes data' do
        usage = ::Ci::Minutes::NamespaceMonthlyUsage.current_month.find_by(namespace_id: namespace.id)
        usage.update!(notification_level: 30)

        expect(::Ci::Minutes::RefreshCachedDataService)
          .to receive(:new)
          .with(namespace)
          .and_call_original

        expect do
          expect(result).to be_success
        end.to change { usage.reload.notification_level }
          .to(Ci::Minutes::Notification::PERCENTAGES.fetch(:not_set))
      end

      context 'when params is not set' do
        let(:params) { {} }

        it 'returns success response but does not reset compute minutes usage data' do
          expect(::Ci::Runner).not_to receive(:instance_type)
          expect(::Ci::Minutes::RefreshCachedDataService).not_to receive(:new)
          expect(::Ci::Minutes::NamespaceMonthlyUsage).not_to receive(:reset_current_notification_level)

          expect(result).to be_success
        end
      end

      context 'when update gives ActiveRecord::RecordInvalid' do
        it 'returns error response with message' do
          expect(namespace).to receive(:update!).and_raise(ActiveRecord::RecordInvalid, namespace)

          expect(result).to be_error
          expect(result.message).to match(/Validation failed/)
        end
      end
    end

    context 'when all compute minutes params are set' do
      let(:params) { { shared_runners_minutes_limit: 20, extra_shared_runners_minutes_limit: 90 } }

      it 'updates the compute minutes attributes' do
        expect { result }.to change { namespace.reload.extra_shared_runners_minutes_limit }.to(90)
          .and change { namespace.shared_runners_minutes_limit }.to(20)
          .and change { namespace.last_ci_minutes_notification_at }.to(nil)
          .and change { namespace.last_ci_minutes_usage_notification_level }.to(nil)
      end
    end
  end
end
