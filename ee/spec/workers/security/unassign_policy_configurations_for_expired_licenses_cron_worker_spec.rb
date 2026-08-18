# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::UnassignPolicyConfigurationsForExpiredLicensesCronWorker, feature_category: :security_policy_management do
  subject(:worker) { described_class.new }

  let(:namespace_unassign_worker) { Security::UnassignPolicyConfigurationsForExpiredNamespaceWorker }

  it_behaves_like 'an idempotent worker'

  describe '#perform' do
    shared_examples 'does not schedule unassign workers' do
      it 'does not schedule any unassign workers' do
        expect(namespace_unassign_worker).not_to receive(:perform_async)

        worker.perform
      end
    end

    shared_examples 'schedules unassign workers for all top-level namespaces' do
      it 'schedules unassign workers for all top-level namespaces' do
        [User.first.namespace_id, namespace.id].each do |namespace_id|
          expect(namespace_unassign_worker).to receive(:perform_async).with(namespace_id)
        end

        worker.perform
      end
    end

    context 'when on SaaS', :saas do
      let_it_be(:ultimate_plan) { create(:ultimate_plan) }
      let_it_be(:premium_plan) { create(:premium_plan) }

      let_it_be_with_reload(:expired_ultimate_history) do
        create(:gitlab_subscription_history, hosted_plan: ultimate_plan, end_date: 17.days.ago.to_date)
      end

      let_it_be(:expired_premium_history) do
        create(:gitlab_subscription_history, hosted_plan: premium_plan, end_date: 17.days.ago.to_date)
      end

      let_it_be(:active_ultimate_history) do
        create(:gitlab_subscription_history, hosted_plan: ultimate_plan, end_date: nil)
      end

      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      it 'only schedules worker for expired ultimate subscriptions' do
        expect(namespace_unassign_worker).to receive(:perform_async).with(expired_ultimate_history.namespace_id)

        [expired_premium_history, active_ultimate_history].each do |history|
          expect(namespace_unassign_worker).not_to receive(:perform_async).with(history.namespace_id)
        end

        worker.perform
      end

      it 'avoids N+1 queries' do
        control = ActiveRecord::QueryRecorder.new { worker.perform }

        create(:gitlab_subscription_history, hosted_plan: ultimate_plan, end_date: 17.days.ago.to_date)
        create(:gitlab_subscription_history, hosted_plan: ultimate_plan, end_date: 17.days.ago.to_date)

        # +2 for using with_context(namespace: namespace) when scheduling worker
        # SELECT "routes".* FROM "routes" WHERE "routes"."source_id" = ? AND "routes"."source_type" = 'Namespace'
        # SELECT "routes".* FROM "routes" WHERE "routes"."source_id" = ? AND "routes"."source_type" = 'Namespace'
        expect { worker.perform }.not_to exceed_query_limit(control).with_threshold(7)
      end

      context 'when the namespace has a current subscription' do
        it 'skips expired ultimate plans if currently active under ultimate' do
          expired_but_downgraded_history = create(:gitlab_subscription_history,
            hosted_plan: ultimate_plan, end_date: 17.days.ago.to_date)
          expired_but_downgraded_history.namespace.gitlab_subscription.update!(hosted_plan: premium_plan)
          expired_ultimate_history.namespace.gitlab_subscription.update!(hosted_plan: ultimate_plan)

          expect(namespace_unassign_worker).to receive(:perform_async).with(expired_but_downgraded_history.namespace_id)
          expect(namespace_unassign_worker).not_to receive(:perform_async).with(expired_premium_history.namespace_id)
          expect(namespace_unassign_worker).not_to receive(:perform_async).with(expired_ultimate_history.namespace_id)

          worker.perform
        end
      end
    end

    context 'when on self-managed', :without_license do
      let_it_be(:namespace) { create(:group) }

      before do
        stub_saas_features(gitlab_com_subscriptions: false)
        create(:security_orchestration_policy_configuration, :namespace, namespace: namespace)
      end

      context 'when current license plan is ultimate' do
        before do
          create(:license, plan: License::ULTIMATE_PLAN)
        end

        include_examples 'does not schedule unassign workers'
      end

      context 'when current license plan is not ultimate' do
        before do
          create(:license, plan: License::PREMIUM_PLAN, data: create(:gitlab_license, starts_at: starts_at).export)
        end

        context 'when start date is before the buffer date' do
          let(:starts_at) { 17.days.ago.to_date }

          include_examples 'schedules unassign workers for all top-level namespaces'
        end

        context 'when start date is after the buffer date' do
          let(:starts_at) { 16.days.ago.to_date }

          include_examples 'does not schedule unassign workers'
        end
      end

      context 'with latest license is expired' do
        before do
          create(:license, plan: License::ULTIMATE_PLAN, data: create(:gitlab_license, expires_at: expires_at).export)
        end

        context 'when expired before buffer date' do
          let(:expires_at) { 18.days.ago.to_date }

          include_examples 'schedules unassign workers for all top-level namespaces'
        end

        context 'when expired after buffer date' do
          let(:expires_at) { 16.days.ago.to_date }

          include_examples 'does not schedule unassign workers'
        end
      end

      context 'without any license' do
        include_examples 'schedules unassign workers for all top-level namespaces'
      end

      context 'without any policy configurations' do
        before do
          create(:license, plan: License::ULTIMATE_PLAN)
          Security::OrchestrationPolicyConfiguration.delete_all
        end

        include_examples 'does not schedule unassign workers'
      end

      context 'when runtime limit is reached' do
        let_it_be(:namespace2) { create(:group) }
        let_it_be(:namespace3) { create(:group) }

        before do
          stub_const("#{described_class}::BATCH_SIZE", 2)
          create(:license, plan: License::PREMIUM_PLAN,
            data: create(:gitlab_license, starts_at: 17.days.ago.to_date).export)

          allow_next_instance_of(Gitlab::Metrics::RuntimeLimiter) do |limiter|
            allow(limiter).to receive(:over_time?).and_return(true)
          end
        end

        it 'reschedules the worker with the correct cursor' do
          expect(described_class).to receive(:perform_in).with(described_class::REQUEUE_DELAY, namespace2.id)

          worker.perform
        end

        it 'stops processing when limit is reached' do
          expect(namespace_unassign_worker).to receive(:perform_async).with(namespace.id)
          expect(namespace_unassign_worker).to receive(:perform_async).with(namespace2.id)
          expect(namespace_unassign_worker).not_to receive(:perform_async).with(namespace3.id)
          expect(namespace_unassign_worker).not_to receive(:perform_async).with(User.first.namespace_id)

          worker.perform
        end
      end

      context 'when cursor is present' do
        let_it_be(:namespace2) { create(:group) }

        before do
          create(:license,
            plan: License::PREMIUM_PLAN,
            data: create(:gitlab_license, starts_at: 17.days.ago.to_date).export
          )
        end

        it 'schedules unassign workers for namespaces after the cursor' do
          expect(namespace_unassign_worker).not_to receive(:perform_async).with(namespace.id)
          expect(namespace_unassign_worker).to receive(:perform_async).with(namespace2.id)
          expect(namespace_unassign_worker).to receive(:perform_async).with(User.first.namespace_id)

          worker.perform(namespace.id)
        end
      end
    end
  end
end
