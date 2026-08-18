# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Reconciliations::CalculateSeatCountDataService, :saas,
  feature_category: :subscription_management do
  using RSpec::Parameterized::TableSyntax

  describe '#execute' do
    let_it_be(:user) { create(:user) }

    subject(:execute_service) do
      described_class.new(namespace: root_ancestor, subscription: subscription, user: user).execute
    end

    context 'with no subscription' do
      let_it_be(:root_ancestor) { create(:group, owners: user) }
      let(:subscription) { nil }

      it { is_expected.to be_nil }
    end

    context 'when the max_seats_used has not been updated on the subscription' do
      let_it_be(:root_ancestor) { create(:group) }
      let_it_be(:subscription) do
        create(:gitlab_subscription, namespace: root_ancestor, plan_code: Plan::ULTIMATE, seats: 10, max_seats_used: 9)
      end

      it { is_expected.to be_nil }
    end

    context 'when the subscription has expired' do
      let_it_be(:root_ancestor) { create(:group, owners: user) }
      let(:subscription) do
        create(
          :gitlab_subscription,
          :expired,
          namespace: root_ancestor,
          plan_code: Plan::ULTIMATE,
          seats: 10,
          max_seats_used: 9,
          max_seats_used_changed_at: 1.day.ago
        )
      end

      before do
        allow(GitlabSubscriptions::Reconciliations::CheckSeatUsageAlertsEligibilityService)
          .to receive(:new).and_return(
            instance_double(
              GitlabSubscriptions::Reconciliations::CheckSeatUsageAlertsEligibilityService,
              execute: false
            )
          )
      end

      it { is_expected.to be_nil }
    end

    context 'when the subscription is a trial' do
      let_it_be(:root_ancestor) { create(:group, owners: user) }
      let(:subscription) do
        create(
          :gitlab_subscription,
          :active_trial,
          namespace: root_ancestor,
          plan_code: Plan::ULTIMATE_TRIAL,
          seats: 10,
          max_seats_used: 9,
          max_seats_used_changed_at: 1.day.ago
        )
      end

      before do
        allow(GitlabSubscriptions::Reconciliations::CheckSeatUsageAlertsEligibilityService)
          .to receive(:new).and_return(
            instance_double(
              GitlabSubscriptions::Reconciliations::CheckSeatUsageAlertsEligibilityService,
              execute: false
            )
          )
      end

      it { is_expected.to be_nil }
    end

    context 'when conditions are not met' do
      let(:max_seats_used) { 9 }
      let_it_be(:root_ancestor) { create(:group, owners: user) }
      let(:subscription) do
        create(
          :gitlab_subscription,
          namespace: root_ancestor,
          plan_code: Plan::ULTIMATE,
          seats: 10,
          max_seats_used: max_seats_used,
          max_seats_used_changed_at: 1.day.ago
        )
      end

      before do
        allow_next_instance_of(
          GitlabSubscriptions::Reconciliations::CheckSeatUsageAlertsEligibilityService
        ) do |service|
          expect(service).to receive(:execute).and_return(true)
        end
      end

      context 'when the alert was dismissed' do
        before do
          allow(user).to receive(:dismissed_callout_for_group?).and_return(true)
        end

        it { is_expected.to be_nil }
      end

      context 'when the subscription is not eligible for usage alerts' do
        before do
          allow_next_instance_of(
            GitlabSubscriptions::Reconciliations::CheckSeatUsageAlertsEligibilityService
          ) do |service|
            expect(service).to receive(:execute).and_return(false)
          end
        end

        it { is_expected.to be_nil }
      end

      context 'when max seats used are more than the subscription seats' do
        let(:max_seats_used) { 11 }

        it { is_expected.to be_nil }
      end
    end

    context 'with threshold limits' do
      let_it_be(:root_ancestor) { create(:group, owners: user) }
      let(:subscription) do
        create(
          :gitlab_subscription,
          namespace: root_ancestor,
          plan_code: Plan::ULTIMATE,
          seats: seats,
          max_seats_used: max_seats_used,
          max_seats_used_changed_at: 1.day.ago
        )
      end

      before do
        allow_next_instance_of(GitlabSubscriptions::Reconciliations::CheckSeatUsageAlertsEligibilityService) do |svc|
          expect(svc).to receive(:execute).and_return(true)
        end
      end

      context 'when limits are not met' do
        where(:seats, :max_seats_used) do
          15    | 13
          24    | 20
          35    | 29
          100   | 90
          1000  | 949
        end

        with_them do
          it { is_expected.to be_nil }
        end
      end

      context 'when limits are met' do
        where(:seats, :max_seats_used) do
          15    | 14
          24    | 22
          35    | 32
          100   | 93
          1000  | 950
        end

        with_them do
          it do
            is_expected.to eq({
              namespace: root_ancestor,
              remaining_seat_count: [seats - max_seats_used, 0].max,
              seats_in_use: max_seats_used,
              total_seat_count: seats
            })
          end
        end
      end
    end
  end
end
