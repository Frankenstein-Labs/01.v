# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscription, :saas, feature_category: :subscription_management do
  using RSpec::Parameterized::TableSyntax

  ['free', *Plan::PAID_HOSTED_PLANS].map { |name| "#{name}_plan" }.each do |plan| # rubocop:disable RSpec/UselessDynamicDefinition -- `plan` used in `let_it_be`
    let_it_be(plan) { create(plan) } # rubocop:disable Rails/SaveBang -- It is creating the factory record
  end

  it { is_expected.to delegate_method(:exclude_guests?).to(:namespace) }

  describe 'default values', :freeze_time do
    it 'defaults start_date to the current date' do
      expect(described_class.new.start_date).to eq(Time.zone.today)
    end
  end

  describe 'validations' do
    let_it_be(:namespace) { create(:namespace) }
    let(:trial) { false }
    let(:today) { Time.zone.now.to_date }

    subject(:subscription) { described_class.new(trial: trial, namespace: namespace) }

    it { is_expected.to validate_presence_of(:seats) }
    it { is_expected.to validate_presence_of(:start_date) }

    it { is_expected.to validate_uniqueness_of(:namespace_id) }

    it { is_expected.to validate_inclusion_of(:contract_overages_allowed).in_array([true, false]) }

    context 'without trial' do
      it { is_expected.not_to validate_presence_of(:trial_ends_on) }
      it { is_expected.not_to validate_presence_of(:trial_starts_on) }

      it 'does not validate trial date attributes' do
        subscription.trial_starts_on = today
        subscription.trial_ends_on = today

        expect(subscription).to be_valid
      end
    end

    context 'with trial' do
      let(:trial) { true }

      it { is_expected.to validate_presence_of(:trial_ends_on) }
      it { is_expected.to validate_presence_of(:trial_starts_on) }

      it 'does not allow trial date attributes to be equal' do
        subscription.trial_starts_on = today
        subscription.trial_ends_on = today

        expect(subscription).not_to be_valid
        expect(subscription.errors[:trial_ends_on]).to include("must be greater than #{today}")
      end
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:namespace) }
    it { is_expected.to belong_to(:hosted_plan) }
  end

  describe 'scopes' do
    describe '.with_hosted_plan' do
      let_it_be(:ultimate_subscription) { create(:gitlab_subscription, hosted_plan: ultimate_plan) }
      let_it_be(:premium_subscription) { create(:gitlab_subscription, hosted_plan: premium_plan) }
      let_it_be(:gold_subscription) { create(:gitlab_subscription, hosted_plan: gold_plan, trial: nil) }
      let_it_be_with_reload(:trial_subscription) do
        create(:gitlab_subscription, :active_trial, hosted_plan: ultimate_plan)
      end

      it 'scopes to the plan' do
        expect(described_class.with_hosted_plan('ultimate')).to contain_exactly(ultimate_subscription)
        expect(described_class.with_hosted_plan('premium')).to contain_exactly(premium_subscription)
        expect(described_class.with_hosted_plan('gold')).to contain_exactly(gold_subscription)
        expect(described_class.with_hosted_plan('bronze')).to be_empty
      end
    end

    describe '.by_hosted_plan_ids' do
      let_it_be(:ultimate_subscription) { create(:gitlab_subscription, hosted_plan: ultimate_plan) }
      let_it_be(:premium_subscription) { create(:gitlab_subscription, hosted_plan: premium_plan) }
      let_it_be_with_reload(:trial_subscription) do
        create(:gitlab_subscription, :active_trial, hosted_plan: ultimate_plan)
      end

      it 'returns subscriptions by their plan ids' do
        expect(described_class.by_hosted_plan_ids(ultimate_plan.id)).to match_array(
          [ultimate_subscription, trial_subscription]
        )
        expect(described_class.by_hosted_plan_ids([ultimate_plan.id, premium_plan.id])).to match_array(
          [ultimate_subscription, premium_subscription, trial_subscription]
        )
        expect(described_class.by_hosted_plan_ids(non_existing_record_id)).to be_empty
      end
    end

    describe '.max_seats_used_changed_between', :timecop do
      let(:from) { Time.current.beginning_of_day - 1.day }
      let(:to) { Time.current.beginning_of_day }

      let!(:in_bounds_subscription) do
        create(:gitlab_subscription, max_seats_used_changed_at: to - 1.hour)
      end

      let!(:out_of_bounds_subscription) do
        create(:gitlab_subscription, max_seats_used_changed_at: from - 1.hour)
      end

      it 'returns relevant subscriptions' do
        expect(described_class.max_seats_used_changed_between(from: from, to: to))
          .to contain_exactly(in_bounds_subscription)
      end
    end

    describe '.requiring_seat_refresh', :timecop do
      let_it_be(:ultimate_subscription) do
        create(:gitlab_subscription, hosted_plan: ultimate_plan, last_seat_refresh_at: nil)
      end

      let_it_be(:ultimate_subscription_12_hours) do
        create(:gitlab_subscription, hosted_plan: ultimate_plan, last_seat_refresh_at: 12.hours.ago)
      end

      let_it_be(:ultimate_subscription_2_days) do
        create(:gitlab_subscription, hosted_plan: ultimate_plan, last_seat_refresh_at: 2.days.ago)
      end

      let_it_be(:ultimate_subscription_24_hours) do
        create(:gitlab_subscription, hosted_plan: ultimate_plan, last_seat_refresh_at: 24.hours.ago)
      end

      let_it_be(:premium_subscription) do
        create(:gitlab_subscription, hosted_plan: premium_plan, last_seat_refresh_at: nil)
      end

      let_it_be(:premium_subscription_12_hours) do
        create(:gitlab_subscription, hosted_plan: premium_plan, last_seat_refresh_at: 12.hours.ago)
      end

      let_it_be(:premium_subscription_2_days) do
        create(:gitlab_subscription, hosted_plan: premium_plan, last_seat_refresh_at: 2.days.ago)
      end

      let_it_be(:premium_subscription_24_hours) do
        create(:gitlab_subscription, hosted_plan: premium_plan, last_seat_refresh_at: 24.hours.ago)
      end

      let_it_be(:free_subscription) { create(:gitlab_subscription, :free, last_seat_refresh_at: 2.days.ago) }
      let_it_be_with_reload(:trial_subscription) do
        create(:gitlab_subscription, :active_trial, hosted_plan: ultimate_plan, last_seat_refresh_at: 2.days.ago)
      end

      it 'returns relevant subscriptions' do
        matching_subscriptions = [
          ultimate_subscription,
          ultimate_subscription_2_days,
          ultimate_subscription_24_hours,
          premium_subscription,
          premium_subscription_2_days,
          premium_subscription_24_hours
        ]

        expect(described_class.requiring_seat_refresh(6))
          .to match_array(matching_subscriptions)
      end

      it 'limits results' do
        expect(described_class.requiring_seat_refresh(1).size).to eq 1
      end
    end

    describe '.not_expired' do
      let_it_be(:expired_ultimate_subscription) do
        create(:gitlab_subscription, hosted_plan: ultimate_plan, end_date: 1.week.ago)
      end

      let_it_be(:ultimate_subscription) { create(:gitlab_subscription, hosted_plan: ultimate_plan) }
      let_it_be(:free_subscription) { create(:gitlab_subscription, :free) }

      it 'returns subscriptions that are not expired' do
        expect(described_class.not_expired).to contain_exactly(ultimate_subscription, free_subscription)
      end
    end

    describe '.with_a_paid_or_trial_hosted_plan' do
      let_it_be(:ultimate_subscription) { create(:gitlab_subscription, hosted_plan: ultimate_plan) }
      let_it_be(:premium_subscription) { create(:gitlab_subscription, hosted_plan: premium_plan) }
      let_it_be(:gold_subscription) { create(:gitlab_subscription, hosted_plan: gold_plan, trial: nil) }
      let_it_be_with_reload(:trial_subscription) do
        create(:gitlab_subscription, :active_trial, hosted_plan: ultimate_plan)
      end

      let_it_be(:free_subscription) { create(:gitlab_subscription, :free) }

      it 'returns relevant subscriptions' do
        matching_subscriptions = [
          ultimate_subscription,
          premium_subscription,
          gold_subscription,
          trial_subscription
        ]

        expect(described_class.with_a_paid_or_trial_hosted_plan).to match_array(matching_subscriptions)
      end
    end

    describe '.with_active_paid_or_trial_hosted_plan' do
      let_it_be(:gold) { create(:gitlab_subscription, :gold) }
      let_it_be(:premium) { create(:gitlab_subscription, :premium) }
      let_it_be(:ultimate) { create(:gitlab_subscription, :ultimate) }
      let_it_be(:gold_expired) { create(:gitlab_subscription, :gold, :expired) }
      let_it_be(:premium_expired) { create(:gitlab_subscription, :premium, :expired) }
      let_it_be(:ultimate_expired) { create(:gitlab_subscription, :ultimate, :expired) }
      let_it_be(:trial) { create(:gitlab_subscription, :active_trial, :ultimate) }
      let_it_be(:trial_expired) { create(:gitlab_subscription, :expired_trial, :ultimate) }
      let_it_be(:_gold_expired_long) do
        create(:gitlab_subscription, :gold, start_date: 2.years.ago, end_date: 1.year.ago)
      end

      let_it_be(:_premium_expired_long) do
        create(:gitlab_subscription, :premium, start_date: 2.years.ago, end_date: 1.year.ago)
      end

      let_it_be(:_ultimate_expired_long) do
        create(:gitlab_subscription, :ultimate, start_date: 2.years.ago, end_date: 1.year.ago)
      end

      let_it_be(:_trial_expired_long) do
        create(:gitlab_subscription, :ultimate, trial: true, trial_starts_on: 2.years.ago, trial_ends_on: 1.year.ago)
      end

      let_it_be(:_free) { create(:gitlab_subscription, :free) }

      context 'without grace period' do
        subject(:result) { described_class.with_active_paid_or_trial_hosted_plan }

        it 'includes active paid or trial hosted plans' do
          expect(result).to match_array([gold, premium, ultimate, trial])
        end
      end

      context 'with grace period' do
        subject(:result) { described_class.with_active_paid_or_trial_hosted_plan(33.days) }

        it 'includes active paid or trial plans and expired paid or trial plans which are within the grace period' do
          expect(result).to match_array(
            [gold, premium, ultimate, gold_expired, premium_expired, ultimate_expired, trial, trial_expired]
          )
        end
      end
    end

    describe '.id_greater_than' do
      let_it_be(:subscription1) { create(:gitlab_subscription) }
      let_it_be(:subscription2) { create(:gitlab_subscription) }
      let_it_be(:subscription3) { create(:gitlab_subscription) }

      it 'returns subscriptions with id greater than the specified value' do
        expect(described_class.id_greater_than(subscription1.id)).to contain_exactly(subscription2, subscription3)
      end

      it 'returns empty when no records have greater id' do
        expect(described_class.id_greater_than(subscription3.id)).to be_empty
      end
    end
  end

  describe '#calculate_seats_in_use' do
    let_it_be(:user_1)         { create(:user) }
    let_it_be(:user_2)         { create(:user) }
    let_it_be(:blocked_user)   { create(:user, :blocked) }
    let!(:user_namespace) { create(:user).namespace }
    let!(:user_project)   { create(:project, namespace: user_namespace) }

    let_it_be_with_refind(:group) { create(:group) }
    let_it_be(:subgroup_1) { create(:group, parent: group) }
    let_it_be(:subgroup_2) { create(:group, parent: group) }
    let!(:gitlab_subscription) { create(:gitlab_subscription, namespace: group) }

    it 'returns count of members' do
      group.add_developer(user_1)

      expect(gitlab_subscription.calculate_seats_in_use).to eq(1)
    end

    it 'also counts users from subgroups' do
      group.add_developer(user_1)
      subgroup_1.add_developer(user_2)

      expect(gitlab_subscription.calculate_seats_in_use).to eq(2)
    end

    it 'does not count duplicated members' do
      group.add_developer(user_1)
      subgroup_1.add_developer(user_2)
      subgroup_2.add_developer(user_2)

      expect(gitlab_subscription.calculate_seats_in_use).to eq(2)
    end

    it 'does not count blocked members' do
      group.add_developer(user_1)
      group.add_developer(blocked_user)

      expect(group.member_count).to eq(2)
      expect(gitlab_subscription.calculate_seats_in_use).to eq(1)
    end

    context 'with free_user_cap' do
      let_it_be_with_refind(:group) { create(:group, developers: [user_1, user_2]) }

      before do
        create(:group_member, :awaiting, source: group)
        gitlab_subscription.update!(plan_code: 'free')
        stub_ee_application_setting(should_check_namespace_plan: true)
      end

      it 'does not count awaiting members' do
        expect(group.member_count).to eq(3)
        expect(gitlab_subscription.calculate_seats_in_use).to eq(2)
      end
    end

    context 'with guest members' do
      let_it_be_with_refind(:group) { create(:group, guests: user_1) }

      context 'with a ultimate plan' do
        it 'excludes these members' do
          gitlab_subscription.update!(plan_code: 'ultimate')

          expect(gitlab_subscription.calculate_seats_in_use).to eq(0)
        end
      end

      context 'with other plans' do
        %w[bronze premium].each do |plan|
          it 'excludes these members' do
            gitlab_subscription.update!(plan_code: plan)
            # plan has already memoized in ee/namespace.rb as `actual_plan`, so this then
            # is not known at this point since `actual_plan` has already been set when
            # `group.add_guest` in the before action, and was performed due to member set logic where we
            # go through that path already
            group.clear_memoization(:actual_plan)

            expect(gitlab_subscription.calculate_seats_in_use).to eq(1)
          end
        end
      end
    end

    context 'when subscription is for a User' do
      before do
        gitlab_subscription.update!(namespace: user_namespace)

        user_project.add_developer(user_1)
        user_project.add_developer(user_2)
      end

      it 'always returns 1 seat' do
        [bronze_plan, premium_plan, ultimate_plan].each do |plan|
          gitlab_subscription.update!(hosted_plan: plan)

          expect(gitlab_subscription.calculate_seats_in_use).to eq(1)
        end
      end
    end
  end

  describe '#calculate_seats_owed' do
    let!(:gitlab_subscription) do
      create(:gitlab_subscription, subscription_attrs.merge(max_seats_used: 10, seats: 5))
    end

    shared_examples 'always returns a total of 0' do
      it 'does not update max_seats_used' do
        expect(gitlab_subscription.calculate_seats_owed).to eq(0)
      end
    end

    context 'with a free plan' do
      let(:subscription_attrs) { { hosted_plan: nil } }

      include_examples 'always returns a total of 0'
    end

    context 'with a trial plan' do
      let(:subscription_attrs) do
        {
          hosted_plan: ultimate_trial_plan,
          trial: true,
          trial_starts_on: Time.zone.yesterday,
          trial_ends_on: Time.zone.tomorrow
        }
      end

      include_examples 'always returns a total of 0'
    end

    context 'with a paid plan' do
      let(:subscription_attrs) { { hosted_plan: bronze_plan } }

      it 'calculates the number of owed seats' do
        expect(gitlab_subscription.reload.calculate_seats_owed).to eq(5)
      end
    end
  end

  describe '#seats_remaining' do
    context 'when there are more seats used than available in the subscription' do
      it 'returns zero' do
        subscription = build(:gitlab_subscription, seats: 10, max_seats_used: 15)

        expect(subscription.seats_remaining).to eq 0
      end
    end

    context 'when seats used equals seats in subscription' do
      it 'returns zero' do
        subscription = build(:gitlab_subscription, seats: 10, max_seats_used: 10)

        expect(subscription.seats_remaining).to eq 0
      end
    end

    context 'when there are seats left in the subscription' do
      it 'returns the seat count remaining from the max seats used' do
        subscription = build(:gitlab_subscription, seats: 10, max_seats_used: 5)

        expect(subscription.seats_remaining).to eq 5
      end
    end

    context 'when max seat data has not yet been generated for the subscription' do
      it 'returns the seat count of the subscription' do
        subscription = build(:gitlab_subscription, seats: 10, max_seats_used: nil)

        expect(subscription.seats_remaining).to eq 10
      end
    end
  end

  describe '#refresh_seat_attributes' do
    subject(:gitlab_subscription) { create(:gitlab_subscription, seats: 3, max_seats_used: 2, seats_owed: 0) }

    before do
      allow(gitlab_subscription).to receive(:calculate_seats_in_use).and_return(calculate_seats_in_use)
    end

    context 'when current seats in use is lower than recorded max_seats_used' do
      let(:calculate_seats_in_use) { 1 }

      it 'does not increase max_seats_used' do
        expect do
          gitlab_subscription.refresh_seat_attributes
        end.to change { gitlab_subscription.seats_in_use }.from(0).to(1)
          .and not_change(gitlab_subscription, :max_seats_used)
          .and not_change(gitlab_subscription, :seats_owed)
      end
    end

    context 'when current seats in use is higher than seats and max_seats_used' do
      let(:calculate_seats_in_use) { 4 }

      it 'increases seats and max_seats_used' do
        expect do
          gitlab_subscription.refresh_seat_attributes
        end.to change { gitlab_subscription.seats_in_use }.from(0).to(4)
          .and change { gitlab_subscription.max_seats_used }.from(2).to(4)
          .and change { gitlab_subscription.seats_owed }.from(0).to(1)
      end
    end

    context 'when resetting the max seats' do
      let(:calculate_seats_in_use) { 1 }

      it 'sets max_seats_used to the current seats in use' do
        expect do
          gitlab_subscription.refresh_seat_attributes(reset_max: true)
        end.to change { gitlab_subscription.seats_in_use }.from(0).to(1)
          .and change { gitlab_subscription.max_seats_used }.from(2).to(1)
          .and not_change(gitlab_subscription, :seats_owed)
      end
    end
  end

  describe '#seats_in_use' do
    let_it_be_with_refind(:group) { create(:group) }
    let_it_be(:group_member) { create(:group_member, :developer, user: create(:user), group: group) }
    let(:hosted_plan) { nil }
    let(:seats_in_use) { 5 }
    let(:trial) { false }

    let(:gitlab_subscription) do
      create(:gitlab_subscription, namespace: group, trial: trial, hosted_plan: hosted_plan, seats_in_use: seats_in_use)
    end

    subject(:result) { gitlab_subscription.seats_in_use }

    context 'with a paid hosted plan' do
      Plan::PAID_HOSTED_PLANS.each do |plan_name| # rubocop:disable RSpec/UselessDynamicDefinition -- `plan_name` used in `let`
        let(:hosted_plan) { send(:"#{plan_name}_plan") }

        it "returns the previously calculated seats in use when plan is #{plan_name}" do
          expect(result).to eq(5)
        end

        context 'when seats in use is 0' do
          let(:seats_in_use) { 0 }

          it "returns 0 too when plan is #{plan_name}" do
            expect(result).to eq(0)
          end
        end
      end
    end

    context 'with a trial plan' do
      let(:gitlab_subscription) do
        create(
          :gitlab_subscription,
          :active_trial,
          namespace: group,
          hosted_plan: ultimate_trial_plan,
          seats_in_use: seats_in_use
        )
      end

      it 'returns the current seats in use' do
        expect(result).to eq(1)
      end
    end

    context 'with a free plan' do
      let(:hosted_plan) { free_plan }

      it 'returns the current seats in use' do
        expect(result).to eq(1)
      end
    end
  end

  describe '#expired?' do
    let(:gitlab_subscription) { create(:gitlab_subscription, end_date: end_date) }

    subject { gitlab_subscription.expired? }

    context 'when end_date is expired' do
      let(:end_date) { Date.current.advance(days: -1) }

      it { is_expected.to be(true) }
    end

    context 'when end_date is not expired' do
      let(:end_date) { 1.week.from_now }

      it { is_expected.to be(false) }
    end

    context 'when end_date is nil' do
      let(:end_date) { nil }

      it { is_expected.to be(false) }
    end
  end

  describe '#paid_and_expired?' do
    subject { subscription.paid_and_expired? }

    context 'when subscription has a paid hosted plan and is expired' do
      let(:subscription) { build(:gitlab_subscription, :premium, end_date: Date.current.advance(days: -1)) }

      it { is_expected.to be(true) }
    end

    context 'when subscription has a paid hosted plan and is not expired' do
      let(:subscription) { build(:gitlab_subscription, :premium, end_date: 1.week.from_now) }

      it { is_expected.to be(false) }
    end

    context 'when subscription is free' do
      let(:subscription) { build(:gitlab_subscription, :free, end_date: Date.current.advance(days: -1)) }

      it { is_expected.to be(false) }
    end

    context 'when subscription is a paid trial that is expired' do
      let(:subscription) do
        build(:gitlab_subscription, :premium_trial, trial: true, end_date: Date.current.advance(days: -1))
      end

      it { is_expected.to be(false) }
    end
  end

  describe '#has_a_paid_hosted_plan?' do
    using RSpec::Parameterized::TableSyntax

    let(:subscription) { build(:gitlab_subscription) }

    where(:plan_name, :seats, :result) do
      'bronze'        | 0 | false
      'bronze'        | 1 | true
      'premium'       | 1 | true
    end

    with_them do
      before do
        plan = build(:plan, name: plan_name)
        subscription.assign_attributes(hosted_plan: plan, seats: seats)
      end

      it 'returns true if subscription has a paid hosted plan' do
        expect(subscription.has_a_paid_hosted_plan?).to eq(result)
      end
    end
  end

  describe '#upgradable?' do
    using RSpec::Parameterized::TableSyntax

    let(:subscription) { build(:gitlab_subscription) }

    shared_examples 'upgradable lower plan' do |plan_name|
      where(:has_a_paid_hosted_plan, :expired, :result) do
        false | false | false
        true  | false | true
        true  | true  | false
        false | true  | false
      end

      with_them do
        before do
          plan = build(:plan, name: plan_name)
          allow(subscription).to receive(:expired?) { expired }
          allow(subscription).to receive(:has_a_paid_hosted_plan?) { has_a_paid_hosted_plan }
          subscription.assign_attributes(hosted_plan: plan)
        end

        it 'returns true if subscription is upgradable' do
          expect(subscription.upgradable?).to eq(result)
        end
      end
    end

    shared_examples 'top plan' do |plan_name|
      where(:has_a_paid_hosted_plan, :expired) do
        false | false
        true  | false
        true  | true
        false | true
      end

      with_them do
        before do
          plan = build(:plan, name: plan_name)
          allow(subscription).to receive(:expired?) { expired }
          allow(subscription).to receive(:has_a_paid_hosted_plan?) { has_a_paid_hosted_plan }
          subscription.assign_attributes(hosted_plan: plan)
        end

        it 'returns false' do
          expect(subscription.upgradable?).to be(false)
        end
      end
    end

    (::Plan.all_plans - ::Plan::TOP_PLANS).each do |plan_name|
      it_behaves_like 'upgradable lower plan', plan_name
    end

    ::Plan::TOP_PLANS.each do |plan_name|
      it_behaves_like 'top plan', plan_name
    end
  end

  describe 'callbacks' do
    context 'for after_commit', :saas do
      context 'for index_namespace' do
        let_it_be(:namespace) { create(:namespace) }

        let(:gitlab_subscription) { build(:gitlab_subscription, plan, namespace: namespace) }
        let(:expiration_date) { Time.zone.today + 10 }
        let(:plan) { :bronze }

        before do
          gitlab_subscription.end_date = expiration_date
        end

        it 'indexes the namespace' do
          expect(ElasticsearchIndexedNamespace).to receive(:safe_find_or_create_by!)
            .with(namespace_id: gitlab_subscription.namespace_id)

          gitlab_subscription.save!
        end

        context 'when seats is 0' do
          let(:gitlab_subscription) { build(:gitlab_subscription, namespace: namespace, seats: 0) }

          it 'indexes the namespace' do
            expect(ElasticsearchIndexedNamespace).to receive(:safe_find_or_create_by!)
              .with(namespace_id: gitlab_subscription.namespace_id)

            gitlab_subscription.save!
          end
        end

        context 'when it is a trial' do
          let(:seats) { 10 }
          let(:gitlab_subscription) { build(:gitlab_subscription, :active_trial, namespace: namespace, seats: seats) }

          it 'indexes the namespace' do
            expect(ElasticsearchIndexedNamespace).to receive(:safe_find_or_create_by!)
              .with(namespace_id: gitlab_subscription.namespace_id)

            gitlab_subscription.save!
          end

          context 'when seats is zero' do
            let(:seats) { 0 }

            it 'indexes the namespace' do
              expect(ElasticsearchIndexedNamespace).to receive(:safe_find_or_create_by!)
                .with(namespace_id: gitlab_subscription.namespace_id)

              gitlab_subscription.save!
            end
          end

          context 'when in free plan' do
            let(:gitlab_subscription) do
              build(:gitlab_subscription, :active_trial, namespace: namespace, seats: seats, hosted_plan_id: nil)
            end

            it 'does not index the namespace' do
              expect(ElasticsearchIndexedNamespace).not_to receive(:safe_find_or_create_by!)

              gitlab_subscription.save!
            end
          end
        end

        context 'when not ::Gitlab.com?' do
          before do
            allow(::Gitlab).to receive(:com?).and_return(false)
          end

          it 'does not index the namespace' do
            expect(ElasticsearchIndexedNamespace).not_to receive(:safe_find_or_create_by!)

            gitlab_subscription.save!
          end
        end

        context 'when the plan has expired' do
          let(:expiration_date) { Time.zone.today - 8.days }

          it 'does not index the namespace' do
            expect(ElasticsearchIndexedNamespace).not_to receive(:safe_find_or_create_by!)

            gitlab_subscription.save!
          end
        end

        context 'when it is a free plan' do
          let(:plan) { :free }

          it 'does not index the namespace' do
            expect(ElasticsearchIndexedNamespace).not_to receive(:safe_find_or_create_by!)

            gitlab_subscription.save!
          end
        end
      end

      context 'for reset_seats_usage_callouts' do
        let_it_be(:namespace) { create(:namespace) }

        let(:gitlab_subscription) { create(:gitlab_subscription, plan, namespace: namespace, seats: 10) }
        let(:plan) { :premium }

        context 'when changing seats' do
          it 'resets the callouts' do
            expect(Groups::ResetSeatCalloutsWorker).to receive(:perform_async).with(gitlab_subscription.namespace_id)

            gitlab_subscription.update!(seats: 11)
          end
        end
      end
    end

    it 'has all attributes listed in the subscription history table' do
      expect(described_class.attribute_names)
        .to match_array(
          GitlabSubscriptions::SubscriptionHistory::PREFIXED_ATTRIBUTES +
          GitlabSubscriptions::SubscriptionHistory::TRACKED_ATTRIBUTES +
          GitlabSubscriptions::SubscriptionHistory::OMITTED_ATTRIBUTES
        )
    end

    context 'for before_update', :freeze_time do
      let(:gitlab_subscription) do
        create(
          :gitlab_subscription,
          seats_in_use: 20,
          max_seats_used: 42,
          max_seats_used_changed_at: 1.month.ago,
          seats: 13,
          seats_owed: 29,
          start_date: Time.zone.today - 1.year
        )
      end

      context 'when a tracked attribute is updated' do
        it 'logs previous state to gitlab subscription history' do
          gitlab_subscription.update!(max_seats_used: 32)

          expect(GitlabSubscriptions::SubscriptionHistory.count).to eq(1)
          expect(GitlabSubscriptions::SubscriptionHistory.last.attributes).to include(
            'gitlab_subscription_id' => gitlab_subscription.id,
            'change_type' => 'gitlab_subscription_updated',
            'max_seats_used' => 42,
            'seats' => 13
          )
        end

        context 'when a namespace changes their plan' do
          let(:gitlab_subscription) do
            create(:gitlab_subscription, hosted_plan: free_plan)
          end

          it 'logs history with the free plan' do
            expect do
              gitlab_subscription.update!(hosted_plan: premium_plan)
            end.to change { GitlabSubscriptions::SubscriptionHistory.count }.by(1)

            expect(GitlabSubscriptions::SubscriptionHistory.last.attributes)
              .to include('hosted_plan_id' => free_plan.id)
          end
        end
      end

      context 'when tracked attributes are not updated' do
        it 'does not log previous state to gitlab subscription history' do
          expect do
            gitlab_subscription.update!(last_seat_refresh_at: Time.current)
          end.to not_change(GitlabSubscriptions::SubscriptionHistory, :count)
        end
      end

      context 'when max_seats_used has changed' do
        it 'updates the max_seats_used_changed_at' do
          expect { gitlab_subscription.update!(max_seats_used: 52) }
            .to change { gitlab_subscription.max_seats_used_changed_at }
            .to(be_like_time(Time.current))
        end
      end

      context 'when max_seats_used has not changed' do
        it 'does not change the max_seats_used_changed_at' do
          expect { gitlab_subscription.update!(max_seats_used: 42, seats_in_use: 25) }
            .to not_change(gitlab_subscription, :max_seats_used_changed_at)
        end
      end

      shared_examples 'resets seats' do
        it 'resets seats attributes' do
          expect do
            gitlab_subscription.update!(start_date: new_start, end_date: new_end)
          end.to change { gitlab_subscription.max_seats_used }.from(42).to(1)
            .and change { gitlab_subscription.seats_owed }.from(29).to(0)
            .and change { gitlab_subscription.seats_in_use }.from(20).to(1)

          expect(gitlab_subscription.max_seats_used_changed_at).to be_like_time(Time.current)
        end
      end

      context 'when starting a new term' do
        let(:new_start) { Time.zone.today + 1.year }
        let(:new_end) { new_start + 1.year }

        context 'when start_date is after the old end_date' do
          let(:new_start) { gitlab_subscription.end_date + 1.year }
          let(:new_end) { new_start + 1.year }

          it_behaves_like 'resets seats'

          it 'triggers subscription started event' do
            expect { gitlab_subscription.update!(start_date: new_start, end_date: new_end) }
              .to publish_event(GitlabSubscriptions::RenewedEvent)
              .with(namespace_id: gitlab_subscription.namespace_id)
          end
        end

        context 'when the end_date was nil' do
          before do
            gitlab_subscription.update!(end_date: nil)
          end

          it_behaves_like 'resets seats'
        end

        context 'when the start_date is before the old end_date' do
          let(:new_start) { gitlab_subscription.end_date - 1.month }

          it_behaves_like 'resets seats'
        end

        context 'when max_seats_used_changed_at is not set' do
          before do
            gitlab_subscription.update!(max_seats_used_changed_at: nil)
          end

          it_behaves_like 'resets seats'
        end
      end

      context 'when dates are changed but not for a new term' do
        it 'does not reset seats attributes' do
          new_start_date = (gitlab_subscription.max_seats_used_changed_at - 1.day).to_date

          expect do
            gitlab_subscription.update!(start_date: new_start_date)
          end.to change { gitlab_subscription.start_date }.to(new_start_date)
            .and not_change(gitlab_subscription, :max_seats_used)
            .and not_change(gitlab_subscription, :max_seats_used_changed_at)
            .and not_change(gitlab_subscription, :seats_owed)
        end

        it 'does not trigger subscription started event' do
          expect(Gitlab::EventStore).not_to receive(:publish)

          gitlab_subscription.update!(start_date: Time.zone.today)
        end
      end

      context 'when no dates are changed' do
        it 'does not reset seats attributes' do
          expect do
            gitlab_subscription.update!(seats_in_use: 99)
          end.to not_change(gitlab_subscription, :max_seats_used)
            .and not_change(gitlab_subscription, :max_seats_used_changed_at)
            .and not_change(gitlab_subscription, :seats_owed)
        end
      end

      context 'when max_seats_used_changed_at is not set' do
        it 'does not reset seats attributes' do
          gitlab_subscription.update!(max_seats_used_changed_at: nil)

          expect do
            gitlab_subscription.update!(seats_in_use: 99)
          end.to not_change(gitlab_subscription, :max_seats_used)
            .and not_change(gitlab_subscription, :max_seats_used_changed_at)
            .and not_change(gitlab_subscription, :seats_owed)
        end
      end

      context 'when max_seats_used_changed_at is on the start_date' do
        let(:new_start) { Time.zone.today }
        let(:new_end) { new_start + 1.year }

        before do
          gitlab_subscription.update!(max_seats_used_changed_at: Time.current)
        end

        it 'does not reset seats attributes' do
          expect do
            gitlab_subscription.update!(seats_in_use: 99)
          end.to not_change(gitlab_subscription, :max_seats_used)
            .and not_change(gitlab_subscription, :max_seats_used_changed_at)
            .and not_change(gitlab_subscription, :seats_owed)
        end
      end

      context 'when max_seats_used_changed_at is before the start_date' do
        let(:new_start) { Time.zone.today }
        let(:new_end) { new_start + 1.year }

        before do
          gitlab_subscription.update!(max_seats_used_changed_at: Time.current - 1.day)
        end

        it_behaves_like 'resets seats'
      end

      context 'with an active trial' do
        let_it_be_with_reload(:trial_subscription) do
          create(
            :gitlab_subscription,
            :active_trial,
            hosted_plan: ultimate_plan,
            max_seats_used: 10,
            seats_owed: 0,
            seats_in_use: 5
          )
        end

        it 'resets seats when upgrading to a paid plan' do
          expect do
            trial_subscription.update!(trial: false)
          end.to change { trial_subscription.max_seats_used }.from(10).to(1)
            .and not_change(trial_subscription, :seats_owed)
            .and not_change(trial_subscription, :seats_in_use)

          expect(trial_subscription.max_seats_used_changed_at).to be_like_time(Time.current)
        end

        it 'does not reset seats when downgrading to a free plan' do
          expect do
            trial_subscription.update!(trial: false, hosted_plan: free_plan)
          end.to not_change(trial_subscription, :max_seats_used)
            .and not_change(trial_subscription, :max_seats_used_changed_at)
        end
      end

      context 'when starting a trial with an expired subscription' do
        let(:new_start) { Date.current }
        let(:new_end) { 1.year.from_now }
        let(:max_seats_used_changed_at) { nil }
        let(:gitlab_subscription) do
          create(
            :gitlab_subscription,
            hosted_plan: ultimate_plan,
            start_date: Date.current - 2.years,
            end_date: Date.current - 1.year,
            max_seats_used_changed_at: max_seats_used_changed_at
          )
        end

        shared_examples 'does not reset seat statistics' do
          it 'does not reset seat statistics' do
            expect do
              gitlab_subscription.update!(
                start_date: new_start,
                end_date: new_end,
                trial: true,
                trial_starts_on: new_start,
                trial_ends_on: new_end
              )
            end.to not_change(gitlab_subscription, :max_seats_used)
              .and not_change(gitlab_subscription, :max_seats_used_changed_at)
              .and not_change(gitlab_subscription, :seats_owed)
          end
        end

        context 'when max_seats_used_changed_at has never been set' do
          it_behaves_like 'does not reset seat statistics'
        end

        context 'when max_seats_used_changed_at has been set' do
          let(:max_seats_used_changed_at) { Time.current - 1.year }

          it_behaves_like 'does not reset seat statistics'
        end
      end

      context 'when starts ultimate_trial_paid_customer plan' do
        before do
          gitlab_subscription.update!(hosted_plan: premium_plan)
        end

        it 'does not reset seat statistics' do
          expect do
            gitlab_subscription.update!(hosted_plan: ultimate_trial_paid_customer_plan)
          end.to not_change(gitlab_subscription, :max_seats_used)
            .and not_change(gitlab_subscription, :max_seats_used_changed_at)
            .and not_change(gitlab_subscription, :seats_owed)
        end
      end

      context 'when updates max_seats_used_changed_at during ultimate_trial_paid_customer plan' do
        before do
          gitlab_subscription.update!(hosted_plan: ultimate_trial_paid_customer_plan)
        end

        it 'does not reset seat statistics' do
          expect do
            gitlab_subscription.update!(max_seats_used_changed_at: Date.current)
          end.to not_change(gitlab_subscription, :max_seats_used)
            .and not_change(gitlab_subscription, :seats_owed)
        end
      end

      context 'when switches back to premium plan from ultimate_trial_paid_customer plan' do
        before do
          gitlab_subscription.update!(hosted_plan: premium_plan)
          gitlab_subscription.update!(hosted_plan: ultimate_trial_paid_customer_plan)
        end

        it 'does not reset seat statistics' do
          expect do
            gitlab_subscription.update!(hosted_plan: premium_plan)
          end.to not_change(gitlab_subscription, :max_seats_used)
            .and not_change(gitlab_subscription, :max_seats_used_changed_at)
            .and not_change(gitlab_subscription, :seats_owed)
        end

        context 'when the premium_plan was renewed during the ultimate_trial_paid_customer trial' do
          before do
            gitlab_subscription.update!(start_date: Time.zone.today + 2.years, end_date: Time.zone.today + 3.years)
          end

          it 'resets seat statistics' do
            expect do
              gitlab_subscription.update!(hosted_plan: premium_plan)
            end.to change { gitlab_subscription.max_seats_used }.from(42).to(1)
              .and change { gitlab_subscription.seats_owed }.from(29).to(0)
              .and change { gitlab_subscription.seats_in_use }.from(20).to(1)
          end
        end
      end

      context 'when upgrade to ultimate plan from ultimate_trial_paid_customer plan' do
        before do
          gitlab_subscription.update!(hosted_plan: ultimate_trial_paid_customer_plan)
        end

        it 'does not reset seat statistics' do
          expect do
            gitlab_subscription.update!(hosted_plan: ultimate_plan)
          end.to change { gitlab_subscription.max_seats_used }.from(42).to(1)
              .and change { gitlab_subscription.seats_owed }.from(29).to(0)
              .and change { gitlab_subscription.seats_in_use }.from(20).to(1)
        end
      end
    end

    context 'for after_destroy_commit' do
      subject(:instance) { build(:gitlab_subscription) }

      it 'logs previous state to gitlab subscription history' do
        group = create(:group)
        instance.update! max_seats_used: 37, seats: 11, namespace: group, hosted_plan: bronze_plan
        db_created_at = described_class.last.created_at

        instance.destroy!

        expect(GitlabSubscriptions::SubscriptionHistory.count).to eq(1)
        expect(GitlabSubscriptions::SubscriptionHistory.last.attributes).to include(
          'gitlab_subscription_id' => instance.id,
          'change_type' => 'gitlab_subscription_destroyed',
          'max_seats_used' => 37,
          'seats' => 11,
          'namespace_id' => group.id,
          'hosted_plan_id' => bronze_plan.id,
          'gitlab_subscription_created_at' => db_created_at
        )
      end
    end
  end

  describe '#trial_extended_or_reactivated?' do
    let_it_be_with_reload(:gitlab_subscription) { create(:gitlab_subscription, :active_trial) }

    before do
      gitlab_subscription.trial_extension_type = trial_extension_type
    end

    subject { gitlab_subscription.trial_extended_or_reactivated? }

    where(:trial_extension_type, :extended_or_reactivated) do
      nil | false
      1 | true
      2 | true
    end

    with_them do
      it { is_expected.to be(extended_or_reactivated) }
    end
  end

  describe '#set_hosted_plan_name_uid' do
    let_it_be(:namespace) { create(:namespace) }

    context 'on create' do
      it 'sets hosted_plan_name_uid from the associated hosted_plan' do
        subscription = build(:gitlab_subscription, namespace: namespace, hosted_plan: premium_plan)

        expect { subscription.save! }
          .to change { subscription.hosted_plan_name_uid }
          .from(nil).to(Plan::PLAN_NAME_UID_LIST[:premium])
      end

      it 'leaves hosted_plan_name_uid as nil when hosted_plan is nil' do
        subscription = create(:gitlab_subscription, namespace: namespace, hosted_plan: nil)

        expect(subscription.hosted_plan_name_uid).to be_nil
      end
    end

    context 'on update' do
      it 'updates hosted_plan_name_uid when hosted_plan changes' do
        subscription = create(:gitlab_subscription, namespace: namespace, hosted_plan: premium_plan)

        expect { subscription.update!(hosted_plan: ultimate_plan) }
          .to change { subscription.reload.hosted_plan_name_uid }
          .from(Plan::PLAN_NAME_UID_LIST[:premium])
          .to(Plan::PLAN_NAME_UID_LIST[:ultimate])
      end

      it 'does not change hosted_plan_name_uid when hosted_plan stays the same' do
        subscription = create(:gitlab_subscription, namespace: namespace, hosted_plan: premium_plan)
        original_uid = subscription.hosted_plan_name_uid

        subscription.update!(seats: 50)

        expect(subscription.reload.hosted_plan_name_uid).to eq(original_uid)
        expect(original_uid).to eq(Plan::PLAN_NAME_UID_LIST[:premium])
      end
    end

    context 'when using plan_code= setter' do
      it 'sets hosted_plan_name_uid via the setter' do
        subscription = build(:gitlab_subscription, namespace: namespace)
        subscription.plan_code = 'premium'

        expect { subscription.save! }
          .to change { subscription.hosted_plan_name_uid }
          .from(nil).to(Plan::PLAN_NAME_UID_LIST[:premium])
      end
    end

    context 'when hosted_plan is set to nil' do
      it 'clears hosted_plan_name_uid' do
        subscription = create(:gitlab_subscription, namespace: namespace, hosted_plan: premium_plan)

        expect { subscription.update!(hosted_plan: nil) }
          .to change { subscription.reload.hosted_plan_name_uid }
          .from(Plan::PLAN_NAME_UID_LIST[:premium])
          .to(nil)
      end
    end

    context 'when hosted_plan_name_uid is missing' do
      it 'populates hosted_plan_name_uid on save' do
        subscription = create(:gitlab_subscription, namespace: namespace, hosted_plan: premium_plan)
        subscription.update_column(:hosted_plan_name_uid, nil)

        subscription.reload.update!(seats: 100)

        expect(subscription.reload.hosted_plan_name_uid).to eq(Plan::PLAN_NAME_UID_LIST[:premium])
      end
    end
  end
end
