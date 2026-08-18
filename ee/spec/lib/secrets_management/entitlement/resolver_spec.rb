# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::Entitlement::Resolver, feature_category: :secrets_management do
  # Refind so the has_one gitlab_subscription association cache does not
  # leak between examples (the resolver reads it via the shared instance).
  let_it_be_with_refind(:root_group) { create(:group) }

  let(:resolver_user) { nil }

  subject(:resolved) { described_class.new(namespace, user: resolver_user).resolve }

  describe '#resolve' do
    context 'on self-managed with an offline cloud license' do
      let(:namespace) { nil }

      before do
        stub_saas_features(gitlab_com_subscriptions: false)
        allow(::License).to receive(:current).and_return(
          instance_double(License, online_cloud_license?: false, trial?: false)
        )
      end

      context 'with an active self-managed secrets manager add-on purchase' do
        before do
          create(:gitlab_subscription_add_on_purchase, :active, :secrets_manager, :self_managed)
        end

        it 'returns :offline_paid' do
          expect(resolved.state).to eq(:offline_paid)
        end

        it 'permits writes' do
          expect(resolved.permits_writes?).to be true
        end

        it 'leaves on_demand_enabled unresolved (nil) -- N/A on offline installs' do
          expect(resolved.on_demand_enabled).to be_nil
        end
      end

      context 'without an active self-managed secrets manager add-on purchase' do
        it 'returns :blocked + :subscription_grace_period_expired', :aggregate_failures do
          expect(resolved.state).to eq(:blocked)
          expect(resolved.blocked_reason).to eq(:subscription_grace_period_expired)
        end

        it 'does not permit writes' do
          expect(resolved.permits_writes?).to be false
        end
      end

      context 'with an expired self-managed secrets manager add-on purchase' do
        before do
          create(:gitlab_subscription_add_on_purchase, :expired, :secrets_manager, :self_managed)
        end

        it 'returns :blocked + :subscription_grace_period_expired', :aggregate_failures do
          expect(resolved.state).to eq(:blocked)
          expect(resolved.blocked_reason).to eq(:subscription_grace_period_expired)
        end
      end

      context 'with an active add-on tied to a namespace (not instance-wide)' do
        before do
          create(:gitlab_subscription_add_on_purchase, :active, :secrets_manager, namespace: root_group)
        end

        it 'is ignored -- offline branch only looks at instance-level purchases', :aggregate_failures do
          expect(resolved.state).to eq(:blocked)
          expect(resolved.blocked_reason).to eq(:subscription_grace_period_expired)
        end
      end
    end

    context 'on self-managed with no license installed' do
      let(:namespace) { nil }

      before do
        stub_saas_features(gitlab_com_subscriptions: false)
        allow(::License).to receive(:current).and_return(nil)
      end

      it 'returns :ineligible -- no license == no entitlement' do
        expect(resolved.state).to eq(:ineligible)
      end

      it 'does not consult AddOnPurchase (short-circuits before routing)' do
        expect(::GitlabSubscriptions::AddOnPurchase).not_to receive(:for_secrets_manager)

        resolved
      end

      it 'is unaffected by stray AddOnPurchase rows from an earlier license', :aggregate_failures do
        create(:gitlab_subscription_add_on_purchase, :active, :secrets_manager, :self_managed)

        expect(resolved.state).to eq(:ineligible)
        expect(resolved.blocked_reason).to be_nil
      end
    end

    context 'on SaaS with no license installed', :saas do
      let(:namespace) { root_group }

      before do
        stub_saas_features(gitlab_com_subscriptions: true)
        allow(::License).to receive(:current).and_return(nil)
      end

      it 'returns :ineligible without asking CDot', :aggregate_failures do
        expect(::Gitlab::SubscriptionPortal::Client).not_to receive(:secrets_manager_trial)
        expect(::Gitlab::SubscriptionPortal::Client).not_to receive(:secrets_manager_consumer_resolve)

        expect(resolved.state).to eq(:ineligible)
      end
    end

    shared_examples 'cloud branch precedence table' do
      let(:cdot_trial) do
        ::Gitlab::SubscriptionPortal::SecretsManagerTrialResponse.new(
          state: trial_state,
          trial_started_at: trial_started_at,
          trial_expires_at: trial_expires_at,
          credits_remaining: credits_remaining,
          credits_total: credits_total,
          on_demand_enabled: on_demand_enabled
        )
      end

      let(:cdot_resolve) do
        ::Gitlab::SubscriptionPortal::SecretsManagerConsumerResolveResponse.new(
          blocked: blocked,
          blocked_reason: blocked_reason
        )
      end

      let(:trial_started_at)  { 5.days.ago }
      let(:trial_expires_at)  { 25.days.from_now }
      let(:blocked)           { false }
      let(:blocked_reason)    { nil }
      let(:credits_remaining) { 100 }
      let(:credits_total)     { 500 }
      let(:on_demand_enabled) { true }

      before do
        allow(::Gitlab::SubscriptionPortal::Client)
          .to receive(:secrets_manager_trial).with(expected_client_kwargs).and_return(cdot_trial)
        allow(::Gitlab::SubscriptionPortal::Client)
          .to receive(:secrets_manager_consumer_resolve)
          .with(expected_client_kwargs.merge(user_id: resolver_user&.id)).and_return(cdot_resolve)
      end

      context 'with CDot state :trial_eligible (no trial yet)' do
        let(:trial_state)       { :trial_eligible }
        let(:trial_started_at)  { nil }
        let(:credits_remaining) { nil }
        let(:credits_total)     { nil }
        let(:on_demand_enabled) { nil }

        it 'returns :trial_eligible without quota fields', :aggregate_failures do
          expect(resolved.state).to eq(:trial_eligible)
          expect(resolved.blocked_reason).to be_nil
          expect(resolved.credits_total).to be_nil
          expect(resolved.on_demand_enabled).to be_nil
          expect(resolved.permits_writes?).to be false
        end

        it 'denies direct reads once the beta cutoff is active (flag on)', :aggregate_failures do
          expect(resolved.beta_program_ended).to be true
          expect(resolved.permits_direct_read?).to be false
        end

        context 'when the beta cutoff is not active yet' do
          before do
            stub_feature_flags(end_secrets_manager_beta_program: false)
          end

          it 'keeps permitting direct reads', :aggregate_failures do
            expect(resolved.beta_program_ended).to be false
            expect(resolved.permits_direct_read?).to be true
          end
        end

        context 'when the customer has already opted in to on-demand billing' do
          let(:on_demand_enabled) { true }

          it 'propagates on_demand_enabled from /trials' do
            expect(resolved.on_demand_enabled).to be true
          end
        end
      end

      context 'with CDot state :trial_eligible blocked on on_demand_disabled' do
        let(:trial_state)       { :trial_eligible }
        let(:trial_started_at)  { nil }
        let(:blocked)           { true }
        let(:blocked_reason)    { :on_demand_disabled }
        let(:credits_remaining) { nil }
        let(:credits_total)     { nil }
        let(:on_demand_enabled) { false }

        it 'keeps :trial_eligible so the trial stays reachable', :aggregate_failures do
          expect(resolved.state).to eq(:trial_eligible)
          expect(resolved.blocked_reason).to be_nil
          expect(resolved.permits_writes?).to be false
          expect(resolved.write_action_denial_reason).to eq(:trial_required)
        end

        it 'carries the beta cutoff through the un-blocked path', :aggregate_failures do
          expect(resolved.beta_program_ended).to be true
          expect(resolved.permits_direct_read?).to be false
        end

        context 'when the beta cutoff is not active yet' do
          before do
            stub_feature_flags(end_secrets_manager_beta_program: false)
          end

          it 'keeps permitting direct reads', :aggregate_failures do
            expect(resolved.beta_program_ended).to be false
            expect(resolved.permits_direct_read?).to be true
          end
        end
      end

      context 'with CDot state :trial_eligible blocked on an enforcing reason' do
        let(:trial_state)    { :trial_eligible }
        let(:blocked)        { true }
        let(:blocked_reason) { :credits_exhausted }

        it 'stays :blocked (only on_demand_disabled is a pre-trial default)', :aggregate_failures do
          expect(resolved.state).to eq(:blocked)
          expect(resolved.blocked_reason).to eq(:credits_exhausted)
        end
      end

      context 'with CDot state :trial_eligible blocked with no reason given' do
        let(:trial_state)    { :trial_eligible }
        let(:blocked)        { true }
        let(:blocked_reason) { nil }

        it 'fails closed to :ineligible rather than offering a trial' do
          expect(resolved.state).to eq(:ineligible)
        end
      end

      context 'with an active trial, not blocked' do
        let(:trial_state) { :trial }

        it 'returns :trial with quota fields from /trials', :aggregate_failures do
          expect(resolved.state).to eq(:trial)
          expect(resolved.credits_remaining).to eq(100)
          expect(resolved.credits_total).to eq(500)
          expect(resolved.on_demand_enabled).to be true
          expect(resolved.permits_writes?).to be true
        end
      end

      context 'with an active trial blocked on on_demand_disabled (CDot combined state)' do
        let(:trial_state)       { :trial }
        let(:blocked)           { true }
        let(:blocked_reason)    { :on_demand_disabled }
        let(:on_demand_enabled) { false }
        let(:credits_remaining) { 0 }

        it 'translates to :credits_exhausted and preserves credits_total', :aggregate_failures do
          expect(resolved.state).to eq(:blocked)
          expect(resolved.blocked_reason).to eq(:credits_exhausted)
          expect(resolved.credits_remaining).to eq(0)
          expect(resolved.credits_total).to eq(500)
          expect(resolved.permits_writes?).to be false
        end
      end

      context 'with an expired trial, not blocked (paid)' do
        let(:trial_state) { :expired }

        it 'returns :paid with on_demand_enabled but no credit fields', :aggregate_failures do
          expect(resolved.state).to eq(:paid)
          expect(resolved.on_demand_enabled).to be true
          expect(resolved.credits_remaining).to be_nil
          expect(resolved.credits_total).to be_nil
          expect(resolved.permits_writes?).to be true
        end
      end

      context 'with an expired trial blocked on on_demand_disabled' do
        let(:trial_state)       { :expired }
        let(:blocked)           { true }
        let(:blocked_reason)    { :on_demand_disabled }
        let(:on_demand_enabled) { false }

        it 'relabels to :trial_expired (never-bought trial under an active paid source)', :aggregate_failures do
          expect(resolved.state).to eq(:blocked)
          expect(resolved.blocked_reason).to eq(:trial_expired)
          expect(resolved.permits_writes?).to be false
        end
      end

      context 'with CDot state :ineligible' do
        let(:trial_state) { :ineligible }

        it 'returns :ineligible' do
          expect(resolved.state).to eq(:ineligible)
        end
      end

      context 'when resolve.blocked=true overrides lifecycle for any trial state' do
        let(:trial_state)    { :trial }
        let(:blocked)        { true }
        let(:blocked_reason) { :subscription_grace_period_expired }

        it 'returns :blocked + the resolve.blocked_reason regardless of trial.state' do
          expect(resolved.state).to eq(:blocked)
          expect(resolved.blocked_reason).to eq(:subscription_grace_period_expired)
        end
      end
    end

    context 'on SaaS', :saas do
      let(:namespace) { root_group }
      let(:expected_client_kwargs) { { namespace_id: root_group.id } }

      before do
        stub_saas_features(gitlab_com_subscriptions: true)
        # gitlab.com prod is itself an online cloud license -- mirror that
        # here so the cloud-vs-offline routing matches production reality.
        allow(::License).to receive(:current).and_return(
          instance_double(License, online_cloud_license?: true)
        )
      end

      it 'does not look at AddOnPurchase records' do
        expect(::GitlabSubscriptions::AddOnPurchase).not_to receive(:for_secrets_manager)

        allow(::Gitlab::SubscriptionPortal::Client).to receive_messages(
          secrets_manager_trial: nil,
          secrets_manager_consumer_resolve: nil
        )

        resolved
      end

      context 'when the secrets_manager_paid_experience feature flag is disabled' do
        before do
          stub_feature_flags(secrets_manager_paid_experience: false)
        end

        it 'returns :ineligible without calling CDot', :aggregate_failures do
          expect(::Gitlab::SubscriptionPortal::Client).not_to receive(:secrets_manager_trial)
          expect(::Gitlab::SubscriptionPortal::Client).not_to receive(:secrets_manager_consumer_resolve)

          expect(resolved.state).to eq(:ineligible)
        end
      end

      context 'with a nil namespace (personal namespace on SaaS has no instance-level entitlement)' do
        let(:namespace) { nil }

        it 'returns :ineligible without calling CDot', :aggregate_failures do
          expect(::Gitlab::SubscriptionPortal::Client).not_to receive(:secrets_manager_trial)
          expect(::Gitlab::SubscriptionPortal::Client).not_to receive(:secrets_manager_consumer_resolve)

          expect(resolved.state).to eq(:ineligible)
        end
      end

      context 'when either CDot call returns nil (requests disabled)' do
        before do
          allow(::Gitlab::SubscriptionPortal::Client).to receive_messages(
            secrets_manager_trial: nil,
            secrets_manager_consumer_resolve: nil
          )
        end

        it 'fails closed and returns :ineligible' do
          expect(resolved.state).to eq(:ineligible)
        end
      end

      describe 'precedence table' do
        include_examples 'cloud branch precedence table'
      end

      context 'when blocked with no_billable_source_error (grace computed locally from end_date)' do
        let(:grace_days) { SecretsManagement::Entitlement::GRACE_DAYS }

        before do
          # Grace derives solely from the subscription end_date; the trial
          # response's state and on-demand opt-in play no part here.
          allow(::Gitlab::SubscriptionPortal::Client).to receive_messages(
            secrets_manager_trial: ::Gitlab::SubscriptionPortal::SecretsManagerTrialResponse.new(
              state: :expired, on_demand_enabled: true
            ),
            secrets_manager_consumer_resolve:
              ::Gitlab::SubscriptionPortal::SecretsManagerConsumerResolveResponse.new(
                blocked: true, blocked_reason: :no_billable_source_error
              )
          )
        end

        context 'with a subscription end_date inside the grace window' do
          before do
            create(:gitlab_subscription, namespace: root_group, end_date: Date.current - 5.days)
          end

          it 'returns :blocked + :grace (read-only window)', :aggregate_failures do
            expect(resolved.state).to eq(:blocked)
            expect(resolved.blocked_reason).to eq(:grace)
            expect(resolved.in_grace?).to be true
            expect(resolved.permits_direct_read?).to be true
            expect(resolved.permits_writes?).to be false
          end
        end

        context 'on the last day of the grace window (end_date + GRACE_DAYS == today)', :freeze_time do
          before do
            create(:gitlab_subscription, namespace: root_group, end_date: Date.current - grace_days.days)
          end

          it 'still returns :grace' do
            expect(resolved.blocked_reason).to eq(:grace)
          end
        end

        context 'with the grace window elapsed' do
          before do
            create(:gitlab_subscription, namespace: root_group, end_date: Date.current - (grace_days + 1).days)
          end

          it 'returns :blocked + :subscription_grace_period_expired (full lockout)', :aggregate_failures do
            expect(resolved.state).to eq(:blocked)
            expect(resolved.blocked_reason).to eq(:subscription_grace_period_expired)
            expect(resolved.in_grace?).to be false
            expect(resolved.permits_direct_read?).to be false
          end
        end

        context 'with a mid-term-cancelled subscription (end_date still in the future)' do
          before do
            # Cancelled paid customer with on-demand off: trialled first, so
            # the trial record reads :expired -- must not become :trial_expired.
            allow(::Gitlab::SubscriptionPortal::Client).to receive(:secrets_manager_trial).and_return(
              ::Gitlab::SubscriptionPortal::SecretsManagerTrialResponse.new(state: :expired)
            )
            create(:gitlab_subscription, namespace: root_group, end_date: Date.current + 6.months)
          end

          it 'returns :grace (read-only through the paid term plus the window)', :aggregate_failures do
            expect(resolved.state).to eq(:blocked)
            expect(resolved.blocked_reason).to eq(:grace)
            expect(resolved.in_grace?).to be true
            expect(resolved.permits_direct_read?).to be true
            expect(resolved.permits_writes?).to be false
          end
        end

        context 'with a plan-trial subscription row (trial: true, future end_date)' do
          before do
            create(:gitlab_subscription, :active_trial, namespace: root_group, end_date: Date.current + 20.days)
          end

          it 'does not open the grace window: fails closed to :subscription_grace_period_expired',
            :aggregate_failures do
            expect(resolved.state).to eq(:blocked)
            expect(resolved.blocked_reason).to eq(:subscription_grace_period_expired)
          end

          context 'without any SM trial history' do
            before do
              allow(::Gitlab::SubscriptionPortal::Client).to receive(:secrets_manager_trial).and_return(
                ::Gitlab::SubscriptionPortal::SecretsManagerTrialResponse.new(state: :trial_eligible)
              )
            end

            it 'fails closed to :subscription_grace_period_expired' do
              expect(resolved.blocked_reason).to eq(:subscription_grace_period_expired)
            end
          end
        end
      end

      context 'when blocked with no_billable_source_error and no subscription evidence' do
        before do
          allow(::Gitlab::SubscriptionPortal::Client).to receive_messages(
            secrets_manager_trial: ::Gitlab::SubscriptionPortal::SecretsManagerTrialResponse.new(state: :expired),
            secrets_manager_consumer_resolve:
              ::Gitlab::SubscriptionPortal::SecretsManagerConsumerResolveResponse.new(
                blocked: true, blocked_reason: :no_billable_source_error
              )
          )
        end

        context 'with an expired trial and no gitlab_subscription' do
          it 'fails closed to :subscription_grace_period_expired (no grace window)', :aggregate_failures do
            expect(resolved.state).to eq(:blocked)
            expect(resolved.blocked_reason).to eq(:subscription_grace_period_expired)
            expect(resolved.in_grace?).to be false
            expect(resolved.permits_direct_read?).to be false
            expect(resolved.permits_read?).to be true
            expect(resolved.permits_writes?).to be false
          end
        end

        context 'with an expired trial and a subscription that has no end_date' do
          before do
            create(:gitlab_subscription, namespace: root_group, end_date: nil)
          end

          it 'fails closed to :subscription_grace_period_expired' do
            expect(resolved.blocked_reason).to eq(:subscription_grace_period_expired)
          end
        end

        context 'without any trial history (trial state is not :expired)' do
          before do
            allow(::Gitlab::SubscriptionPortal::Client).to receive(:secrets_manager_trial).and_return(
              ::Gitlab::SubscriptionPortal::SecretsManagerTrialResponse.new(state: :trial_eligible)
            )
          end

          it 'fails closed to :subscription_grace_period_expired', :aggregate_failures do
            expect(resolved.state).to eq(:blocked)
            expect(resolved.blocked_reason).to eq(:subscription_grace_period_expired)
          end
        end
      end

      context 'with the beta cutoff flag scoped per namespace' do
        before do
          allow(::Gitlab::SubscriptionPortal::Client)
            .to receive(:secrets_manager_trial).with(namespace_id: root_group.id)
            .and_return(::Gitlab::SubscriptionPortal::SecretsManagerTrialResponse.new(state: :trial_eligible))
          allow(::Gitlab::SubscriptionPortal::Client)
            .to receive(:secrets_manager_consumer_resolve)
            .with(namespace_id: root_group.id, user_id: nil)
            .and_return(::Gitlab::SubscriptionPortal::SecretsManagerConsumerResolveResponse.new(blocked: false))
        end

        context 'when the flag is enabled for the resolved namespace' do
          before do
            stub_feature_flags(end_secrets_manager_beta_program: root_group)
          end

          it 'ends the beta program for it' do
            expect(resolved.beta_program_ended).to be true
          end
        end

        context 'when the flag is enabled only for an unrelated group' do
          before do
            stub_feature_flags(end_secrets_manager_beta_program: create(:group))
          end

          it 'keeps the beta program active' do
            expect(resolved.beta_program_ended).to be false
          end
        end
      end

      context 'when a requesting user is provided' do
        let(:resolver_user) { instance_double(User, id: 4242) }

        it 'forwards the user_id to /consumers/resolve (the per-actor check), not to /trials' do
          expect(::Gitlab::SubscriptionPortal::Client)
            .to receive(:secrets_manager_trial).with(namespace_id: root_group.id)
            .and_return(::Gitlab::SubscriptionPortal::SecretsManagerTrialResponse.new(state: :trial_eligible))
          expect(::Gitlab::SubscriptionPortal::Client)
            .to receive(:secrets_manager_consumer_resolve)
            .with(namespace_id: root_group.id, user_id: resolver_user.id)
            .and_return(::Gitlab::SubscriptionPortal::SecretsManagerConsumerResolveResponse.new(blocked: false))

          expect(resolved.state).to eq(:trial_eligible)
        end
      end

      context 'when /trials raises an error' do
        before do
          allow(::Gitlab::SubscriptionPortal::Client)
            .to receive(:secrets_manager_trial)
            .and_raise(::Gitlab::SubscriptionPortal::SecretsManagerTrialResponse::Error, 'boom')
          allow(::Gitlab::SubscriptionPortal::Client)
            .to receive(:secrets_manager_consumer_resolve)
            .and_return(::Gitlab::SubscriptionPortal::SecretsManagerConsumerResolveResponse.new(blocked: false))
        end

        it 'fails closed and returns :ineligible' do
          expect(resolved.state).to eq(:ineligible)
        end

        it 'logs the failure via Gitlab::ErrorTracking.log_exception' do
          expect(::Gitlab::ErrorTracking).to receive(:log_exception).with(
            an_instance_of(::Gitlab::SubscriptionPortal::SecretsManagerTrialResponse::Error),
            hash_including(
              issue_type: 'secrets_management_entitlement_fail_closed',
              gl_namespace_id: root_group.id
            )
          )

          resolved
        end
      end

      context 'when /consumers/resolve raises an error' do
        before do
          allow(::Gitlab::SubscriptionPortal::Client)
            .to receive(:secrets_manager_trial)
            .and_return(::Gitlab::SubscriptionPortal::SecretsManagerTrialResponse.new(state: :trial))
          allow(::Gitlab::SubscriptionPortal::Client)
            .to receive(:secrets_manager_consumer_resolve)
            .and_raise(::Gitlab::SubscriptionPortal::SecretsManagerConsumerResolveResponse::Error, 'boom')
        end

        it 'fails closed and returns :ineligible' do
          expect(resolved.state).to eq(:ineligible)
        end
      end

      context 'when /trials returns a state the resolver does not handle' do
        before do
          allow(::Gitlab::SubscriptionPortal::Client).to receive_messages(
            secrets_manager_trial: instance_double(
              ::Gitlab::SubscriptionPortal::SecretsManagerTrialResponse, state: :brand_new_state
            ),
            secrets_manager_consumer_resolve: ::Gitlab::SubscriptionPortal::SecretsManagerConsumerResolveResponse.new(
              blocked: false
            )
          )
        end

        it 'fails closed and returns :ineligible' do
          expect(resolved.state).to eq(:ineligible)
        end

        it 'logs the failure via Gitlab::ErrorTracking.log_exception' do
          expect(::Gitlab::ErrorTracking).to receive(:log_exception).with(
            an_instance_of(::Gitlab::SubscriptionPortal::SecretsManagerTrialResponse::Error),
            hash_including(
              issue_type: 'secrets_management_entitlement_fail_closed',
              gl_namespace_id: root_group.id
            )
          )

          resolved
        end
      end
    end

    context 'on self-managed with an online cloud license' do
      let(:namespace) { nil }
      let(:instance_uuid) { 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee' }
      let(:expected_client_kwargs) { { instance_id: instance_uuid } }

      before do
        stub_saas_features(gitlab_com_subscriptions: false)
        allow(::Gitlab).to receive(:com?).and_return(false)
        allow(::License).to receive(:current).and_return(
          instance_double(License, online_cloud_license?: true, trial?: false)
        )
        allow(::Gitlab::CurrentSettings).to receive(:uuid).and_return(instance_uuid)
      end

      it 'routes through the cloud branch and passes instance_id (not namespace_id)', :aggregate_failures do
        expect(::Gitlab::SubscriptionPortal::Client)
          .to receive(:secrets_manager_trial).with(instance_id: instance_uuid)
          .and_return(::Gitlab::SubscriptionPortal::SecretsManagerTrialResponse.new(state: :trial_eligible))
        expect(::Gitlab::SubscriptionPortal::Client)
          .to receive(:secrets_manager_consumer_resolve).with(instance_id: instance_uuid, user_id: nil)
          .and_return(::Gitlab::SubscriptionPortal::SecretsManagerConsumerResolveResponse.new(blocked: false))

        expect(resolved.state).to eq(:trial_eligible)
      end

      describe 'precedence table (mirror of SaaS)' do
        include_examples 'cloud branch precedence table'
      end

      context 'when blocked with no_billable_source_error' do
        before do
          allow(::Gitlab::SubscriptionPortal::Client).to receive_messages(
            secrets_manager_trial: ::Gitlab::SubscriptionPortal::SecretsManagerTrialResponse.new(
              state: :expired, on_demand_enabled: true
            ),
            secrets_manager_consumer_resolve:
              ::Gitlab::SubscriptionPortal::SecretsManagerConsumerResolveResponse.new(
                blocked: true, blocked_reason: :no_billable_source_error
              )
          )
        end

        it 'fails closed to :subscription_grace_period_expired (instance-level check, nil namespace)',
          :aggregate_failures do
          expect(resolved.state).to eq(:blocked)
          expect(resolved.blocked_reason).to eq(:subscription_grace_period_expired)
        end

        context 'without any trial history (trial state is not :expired)' do
          before do
            allow(::Gitlab::SubscriptionPortal::Client).to receive(:secrets_manager_trial).and_return(
              ::Gitlab::SubscriptionPortal::SecretsManagerTrialResponse.new(state: :trial_eligible)
            )
          end

          it 'fails closed to :subscription_grace_period_expired' do
            expect(resolved.blocked_reason).to eq(:subscription_grace_period_expired)
          end
        end

        # Group-scoped permission checks pass the root group even on
        # self-managed -- the nil-namespace early return is .com-only.
        context 'with a top-level group namespace' do
          let(:namespace) { root_group }

          it 'fails closed to :subscription_grace_period_expired (group without a gitlab_subscription row)' do
            expect(resolved.blocked_reason).to eq(:subscription_grace_period_expired)
          end

          context 'without any trial history (trial state is not :expired)' do
            before do
              allow(::Gitlab::SubscriptionPortal::Client).to receive(:secrets_manager_trial).and_return(
                ::Gitlab::SubscriptionPortal::SecretsManagerTrialResponse.new(state: :trial_eligible)
              )
            end

            it 'fails closed to :subscription_grace_period_expired' do
              expect(resolved.blocked_reason).to eq(:subscription_grace_period_expired)
            end
          end
        end
      end
    end

    context 'on self-managed with a trial license' do
      let(:namespace) { nil }

      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      context 'when the trial license is online cloud licensed' do
        before do
          allow(::License).to receive(:current).and_return(
            instance_double(License, online_cloud_license?: true, trial?: true)
          )
        end

        it 'returns :ineligible without asking CDot', :aggregate_failures do
          expect(::Gitlab::SubscriptionPortal::Client).not_to receive(:secrets_manager_trial)
          expect(::Gitlab::SubscriptionPortal::Client).not_to receive(:secrets_manager_consumer_resolve)

          expect(resolved.state).to eq(:ineligible)
        end
      end

      context 'when the trial license is offline cloud licensed' do
        before do
          allow(::License).to receive(:current).and_return(
            instance_double(License, online_cloud_license?: false, trial?: true)
          )
        end

        it 'returns :ineligible without consulting AddOnPurchase', :aggregate_failures do
          create(:gitlab_subscription_add_on_purchase, :active, :secrets_manager, :self_managed)

          expect(::GitlabSubscriptions::AddOnPurchase).not_to receive(:for_secrets_manager)

          expect(resolved.state).to eq(:ineligible)
        end
      end
    end

    context 'when the underlying lookup raises' do
      let(:namespace) { nil }

      before do
        stub_saas_features(gitlab_com_subscriptions: false)
        allow(::GitlabSubscriptions::AddOnPurchase).to receive(:for_secrets_manager)
          .and_raise(ActiveRecord::StatementInvalid.new('connection lost'))
      end

      it 'fails closed and returns :ineligible' do
        expect(resolved.state).to eq(:ineligible)
      end

      it 'logs the rescued exception via Gitlab::ErrorTracking.log_exception with namespace context' do
        expect(::Gitlab::ErrorTracking).to receive(:log_exception).with(
          an_instance_of(ActiveRecord::StatementInvalid),
          hash_including(
            issue_type: 'secrets_management_entitlement_fail_closed',
            gl_namespace_id: nil
          )
        )

        resolved
      end

      it 'does not send the exception to Sentry (fail-closed is expected during transient outages)' do
        expect(::Gitlab::ErrorTracking).not_to receive(:track_exception)
        expect(::Gitlab::ErrorTracking).not_to receive(:track_and_raise_for_dev_exception)

        resolved
      end
    end
  end

  describe '#resolve!' do
    subject(:resolved!) { described_class.new(namespace, user: resolver_user, http_timeout: http_timeout).resolve! }

    let(:namespace) { root_group }
    let(:http_timeout) { nil }

    context 'on SaaS', :saas do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
        allow(::License).to receive(:current).and_return(
          instance_double(License, online_cloud_license?: true)
        )
      end

      context 'when resolution succeeds' do
        before do
          allow(::Gitlab::SubscriptionPortal::Client).to receive_messages(
            secrets_manager_trial: ::Gitlab::SubscriptionPortal::SecretsManagerTrialResponse.new(state: :trial),
            secrets_manager_consumer_resolve:
              ::Gitlab::SubscriptionPortal::SecretsManagerConsumerResolveResponse.new(blocked: false)
          )
        end

        it 'resolves like #resolve' do
          expect(resolved!.state).to eq(:trial)
        end

        it 'does not forward a timeout to the client by default' do
          resolved!

          expect(::Gitlab::SubscriptionPortal::Client)
            .to have_received(:secrets_manager_trial).with(namespace_id: root_group.id)
          expect(::Gitlab::SubscriptionPortal::Client)
            .to have_received(:secrets_manager_consumer_resolve).with(namespace_id: root_group.id, user_id: nil)
        end

        context 'with an http_timeout' do
          let(:http_timeout) { 0.25 }

          it 'forwards the timeout to both CDot calls' do
            resolved!

            expect(::Gitlab::SubscriptionPortal::Client)
              .to have_received(:secrets_manager_trial).with(namespace_id: root_group.id, timeout: 0.25)
            expect(::Gitlab::SubscriptionPortal::Client)
              .to have_received(:secrets_manager_consumer_resolve)
              .with(namespace_id: root_group.id, timeout: 0.25, user_id: nil)
          end
        end

        context 'with a cache_ttl', :use_clean_rails_memory_store_caching do
          def resolve_with_ttl
            described_class.new(namespace, cache_ttl: 1.minute).resolve!
          end

          it 'serves later resolutions from the cache without asking CDot again' do
            first = resolve_with_ttl
            second = resolve_with_ttl

            expect(second).to eq(first)
            expect(::Gitlab::SubscriptionPortal::Client).to have_received(:secrets_manager_trial).once
          end

          it 'resolves again once the TTL elapses' do
            resolve_with_ttl
            travel_to(2.minutes.from_now) { resolve_with_ttl }

            expect(::Gitlab::SubscriptionPortal::Client).to have_received(:secrets_manager_trial).twice
          end

          it 'resolves per call when cache_ttl is not given' do
            described_class.new(namespace).resolve!
            described_class.new(namespace).resolve!

            expect(::Gitlab::SubscriptionPortal::Client).to have_received(:secrets_manager_trial).twice
          end
        end
      end

      context 'when a CDot call raises' do
        before do
          allow(::Gitlab::SubscriptionPortal::Client)
            .to receive(:secrets_manager_trial)
            .and_raise(::Gitlab::SubscriptionPortal::SecretsManagerTrialResponse::Error, 'boom')
        end

        it 'propagates the error instead of failing closed to :ineligible' do
          expect { resolved! }.to raise_error(
            ::Gitlab::SubscriptionPortal::SecretsManagerTrialResponse::Error, 'boom'
          )
        end

        it 'does not log the fail-closed exception (the caller owns failure handling)' do
          expect(::Gitlab::ErrorTracking).not_to receive(:log_exception)

          expect { resolved! }.to raise_error(::Gitlab::SubscriptionPortal::SecretsManagerTrialResponse::Error)
        end

        it 'does not cache failures, so the next call retries', :use_clean_rails_memory_store_caching do
          2.times do
            expect { described_class.new(namespace, cache_ttl: 1.minute).resolve! }
              .to raise_error(::Gitlab::SubscriptionPortal::SecretsManagerTrialResponse::Error)
          end

          expect(::Gitlab::SubscriptionPortal::Client).to have_received(:secrets_manager_trial).twice
        end
      end
    end
  end

  describe 'argument validation' do
    it 'raises ArgumentError for a subgroup' do
      subgroup = create(:group, parent: root_group)

      expect { described_class.new(subgroup) }
        .to raise_error(ArgumentError, /top-level Group or nil/)
    end

    it 'raises ArgumentError for a project' do
      project = create(:project, group: root_group)

      expect { described_class.new(project) }
        .to raise_error(ArgumentError, /top-level Group or nil/)
    end

    it 'accepts nil' do
      expect { described_class.new(nil) }.not_to raise_error
    end

    it 'accepts a top-level Group' do
      expect { described_class.new(root_group) }.not_to raise_error
    end

    it 'accepts an optional user: kwarg (default nil)', :aggregate_failures do
      user = build_stubbed(:user)

      expect { described_class.new(root_group) }.not_to raise_error
      expect { described_class.new(root_group, user: nil) }.not_to raise_error
      expect { described_class.new(root_group, user: user) }.not_to raise_error
    end
  end
end
