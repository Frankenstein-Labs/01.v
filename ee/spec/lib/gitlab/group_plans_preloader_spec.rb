# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::GroupPlansPreloader, :saas, :request_store do
  describe '#preload' do
    let_it_be(:premium_plan) { create(:premium_plan) }
    let_it_be(:ultimate_plan) { create(:ultimate_plan) }

    let(:preloaded_groups) { described_class.new.preload(pristine_groups) }

    before_all do
      group1 = create(:group, name: 'group-1')
      create(:gitlab_subscription, namespace: group1, hosted_plan_id: premium_plan.id)

      group2 = create(:group, name: 'group-2')
      create(:gitlab_subscription, namespace: group2, hosted_plan_id: ultimate_plan.id)

      create(:group, name: 'group-3', parent: group1)
    end

    shared_examples 'preloading cases' do
      it 'only executes three SQL queries to preload the data' do
        amount = ActiveRecord::QueryRecorder
          .new { preloaded_groups }
          .count

        # One query to get the groups and their ancestors, one query to get their
        # plans, and one query to _just_ get the groups.
        expect(amount).to eq(3)
      end

      it 'associates the correct plans with the correct groups' do
        expect(preloaded_groups[0].actual_plan).to eq(premium_plan)
        expect(preloaded_groups[1].actual_plan).to eq(ultimate_plan)
        expect(preloaded_groups[2].actual_plan).to eq(premium_plan)
      end

      it 'does not execute any queries for preloaded plans' do
        preloaded_groups

        amount = ActiveRecord::QueryRecorder
          .new { preloaded_groups.each(&:actual_plan) }
          .count

        expect(amount).to be_zero
      end
    end

    context 'when an ActiveRecord relationship is provided' do
      let(:pristine_groups) { Group.order(id: :asc) }

      it_behaves_like 'preloading cases'
    end

    context 'when an array of groups is provided' do
      let(:pristine_groups) { Group.order(id: :asc).to_a }

      it_behaves_like 'preloading cases'
    end

    context 'when Group relation is empty' do
      let(:pristine_groups) { Group.none }

      it 'does not make any requests' do
        amount = ActiveRecord::QueryRecorder.new { preloaded_groups }.count

        expect(amount).to be_zero
      end
    end

    context 'when gitlab_com_subscriptions are not availale' do
      let(:pristine_groups) { Group.order(id: :asc) }

      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      it 'does not preload the plans' do
        preloaded_groups.each do |group|
          expect(Gitlab::SafeRequestStore.read(group.actual_plan_store_key)).to be_nil
        end
      end
    end
  end
end
