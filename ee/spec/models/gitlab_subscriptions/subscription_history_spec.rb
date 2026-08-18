# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::SubscriptionHistory, :saas, feature_category: :seat_cost_management do
  let_it_be(:group1) { create(:group_with_plan, plan: :premium_plan) }
  let_it_be(:group2) { create(:group_with_plan, plan: :premium_plan) }
  let_it_be(:free_plan) { create(:free_plan) }

  it { is_expected.to belong_to(:hosted_plan).class_name('Plan').inverse_of(:gitlab_subscription_histories) }

  describe 'relation to a namespace' do
    let_it_be(:history1) { create(:gitlab_subscription_history, namespace: group1) }
    let_it_be(:history2) { create(:gitlab_subscription_history, namespace: group2) }

    it { is_expected.to belong_to(:namespace).required }

    it 'returns histories for the given namespace' do
      expect(described_class.all).to match_array([history1, history2])
      expect(group1.gitlab_subscription_histories).to match_array([history1])
      expect(group2.gitlab_subscription_histories).to match_array([history2])
    end
  end

  describe 'scopes' do
    describe '.with_all_ultimate_plans' do
      it 'returns histories with any ultimate plan' do
        premium_plan = create(:premium_plan)
        create(:gitlab_subscription_history, hosted_plan: premium_plan)

        ultimate_plan = create(:ultimate_plan)
        history_with_ultimate_plan = create(:gitlab_subscription_history, hosted_plan: ultimate_plan)

        ultimate_trial_plan = create(:ultimate_trial_plan)
        history_with_ultimate_trial_plan = create(:gitlab_subscription_history, hosted_plan: ultimate_trial_plan)

        expect(described_class.with_all_ultimate_plans).to match_array([
          history_with_ultimate_plan,
          history_with_ultimate_trial_plan
        ])
      end
    end

    describe '.ended_on', :freeze_time do
      it 'returns histories that ended on a given date' do
        create(:gitlab_subscription_history, end_date: Date.current)
        create(:gitlab_subscription_history, end_date: Date.tomorrow)
        history3 = create(:gitlab_subscription_history, end_date: Date.yesterday)

        date = Date.yesterday

        expect(described_class.ended_on(date)).to contain_exactly(history3)
      end
    end

    describe '.with_namespace_subscription' do
      let(:query) do
        described_class.with_namespace_subscription.find_each do |history|
          history.namespace&.gitlab_subscription&.hosted_plan
        end
      end

      it 'preloads namespace and gitlab_subscription to avoid N+1 queries' do
        create(:gitlab_subscription_history)
        create(:gitlab_subscription_history)

        control = ActiveRecord::QueryRecorder.new { query }

        create(:gitlab_subscription_history)
        create(:gitlab_subscription_history)

        expect { query }.not_to exceed_query_limit(control)
      end
    end
  end

  describe '.create_from_change' do
    context 'when supplied an invalid change type' do
      it 'raises an error' do
        expect do
          described_class.create_from_change(
            :invalid_change_type,
            { 'id' => 1 }
          )
        end.to raise_error(ArgumentError, "'invalid_change_type' is not a valid change_type")
      end
    end

    context 'when the required attributes are not present' do
      it 'returns an error when gitlab_subscription_id is not present' do
        record = described_class.create_from_change(
          :gitlab_subscription_updated,
          { 'id' => nil, 'namespace_id' => 2 }
        )

        expect(record.errors.attribute_names).to include(:gitlab_subscription_id)
      end

      it 'returns an error when namespace is not present' do
        record = described_class.create_from_change(
          :gitlab_subscription_updated,
          { 'id' => 1, 'namespace_id' => nil }
        )

        expect(record.errors.full_messages).to include("Namespace must exist")
      end

      it 'returns an error when namespace does not exist' do
        record = described_class.create_from_change(
          :gitlab_subscription_updated,
          {
            'id' => 1,
            'namespace_id' => non_existing_record_id,
            'seats_in_use' => 10,
            'trial' => true,
            'seats' => 15
          }
        )

        expect(record.errors.full_messages).to include("Namespace must exist")
      end
    end

    context 'when supplied extra attributes than exist on the history table' do
      it 'saves the tracked attributes without error' do
        current_time = Time.current

        record = described_class.create_from_change(
          :gitlab_subscription_updated,
          {
            'id' => 1,
            'namespace_id' => group1.id,
            'created_at' => current_time,
            'updated_at' => current_time,
            'non_existent_attribute' => true,
            'seats_in_use' => 10,
            'trial' => true,
            'seats' => 15
          }
        )

        expect(record).to be_valid
        expect(record).to be_persisted

        expect(record).to have_attributes(
          'gitlab_subscription_id' => 1,
          'namespace_id' => group1.id,
          'gitlab_subscription_created_at' => current_time,
          'gitlab_subscription_updated_at' => current_time,
          'seats_in_use' => 10,
          'trial' => true,
          'seats' => 15
        )

        expect(record.attributes.keys).to include(*GitlabSubscriptions::SubscriptionHistory::TRACKED_ATTRIBUTES)

        expect(record.attributes.keys).not_to include(
          'non_existent_attribute',
          *GitlabSubscriptions::SubscriptionHistory::OMITTED_ATTRIBUTES
        )
      end
    end

    context 'when tracking hosted_plan_name_uid' do
      let_it_be(:premium_plan) { create(:premium_plan) }
      let_it_be(:ultimate_plan) { create(:ultimate_plan) }

      it 'captures hosted_plan_name_uid in the history record' do
        record = described_class.create_from_change(
          :gitlab_subscription_updated,
          {
            'id' => 1,
            'namespace_id' => group1.id,
            'hosted_plan_id' => premium_plan.id,
            'hosted_plan_name_uid' => Plan::PLAN_NAME_UID_LIST[:premium],
            'seats' => 10
          }
        )

        expect(record).to be_persisted
        expect(record.hosted_plan_name_uid).to eq(Plan::PLAN_NAME_UID_LIST[:premium])
      end

      it 'captures nil hosted_plan_name_uid when hosted_plan_id is nil' do
        record = described_class.create_from_change(
          :gitlab_subscription_updated,
          {
            'id' => 1,
            'namespace_id' => group1.id,
            'hosted_plan_id' => nil,
            'hosted_plan_name_uid' => nil,
            'seats' => 10
          }
        )

        expect(record).to be_persisted
        expect(record.hosted_plan_name_uid).to be_nil
      end

      it 'includes hosted_plan_name_uid in TRACKED_ATTRIBUTES' do
        expect(GitlabSubscriptions::SubscriptionHistory::TRACKED_ATTRIBUTES).to include('hosted_plan_name_uid')
      end
    end
  end
end
