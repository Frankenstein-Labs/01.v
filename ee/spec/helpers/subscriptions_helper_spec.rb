# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SubscriptionsHelper, feature_category: :subscription_management do
  describe '#plan_title' do
    let_it_be(:free_plan) do
      { "name" => "Free Plan", "free" => true, "code" => "free" }
    end

    let(:bronze_plan) do
      {
        "id" => "bronze_id",
        "name" => "Bronze Plan",
        "free" => false,
        "code" => "bronze",
        "price_per_year" => 48.0
      }
    end

    let(:raw_plan_data) do
      [free_plan, bronze_plan]
    end

    before do
      allow(helper).to receive(:params).and_return(plan_id: 'bronze_id', namespace_id: nil)

      allow_next_instance_of(GitlabSubscriptions::FetchSubscriptionPlansService) do |instance|
        allow(instance).to receive(:execute).and_return(raw_plan_data)
      end
    end

    subject { helper.plan_title }

    it { is_expected.to eq('Bronze') }

    context 'no plan_id URL parameter present' do
      before do
        allow(helper).to receive(:params).and_return({})
      end

      it { is_expected.to be_nil }
    end

    context 'a non-existing plan_id URL parameter present' do
      before do
        allow(helper).to receive(:params).and_return(plan_id: 'xxx')
      end

      it { is_expected.to be_nil }
    end
  end

  describe '#present_groups' do
    context 'when supplied a collection of groups' do
      it 'serializes them for the display' do
        group_1 = build(:group, id: 1, name: 'Group 1', path: 'group_1')
        group_2 = build(:group, id: 2, name: 'Group 2', path: 'group_2')

        expect(helper.present_groups([group_1, group_2])).to eq([
          { id: 1, name: 'Group 1', full_path: 'group_1' },
          { id: 2, name: 'Group 2', full_path: 'group_2' }
        ])
      end
    end

    context 'when the collection is empty' do
      it 'returns an empty collection' do
        expect(helper.present_groups([])).to be_empty
      end
    end
  end
end
