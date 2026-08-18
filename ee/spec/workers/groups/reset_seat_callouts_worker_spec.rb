# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::ResetSeatCalloutsWorker, feature_category: :seat_cost_management do
  let_it_be(:group, freeze: false) { build(:group) }
  let_it_be(:user, freeze: false) { create(:user) }
  let_it_be(:feature_name) { EE::Users::GroupCalloutsHelper::ALL_SEATS_USED_ALERT }
  let_it_be(:callout, freeze: false) do
    create(:group_callout, user: user, group: group, feature_name: feature_name)
  end

  before_all do
    group.add_owner(user)
  end

  before do
    allow(Group).to receive(:find_by_id).with(group.id).and_return(group)
  end

  subject(:worker) { described_class.new }

  it 'resets the callout' do
    expect(callout_count).to eq(1)

    worker.perform(group.id)

    expect(callout_count).to eq(0)
  end

  context 'when group is nil' do
    before do
      allow(Group).to receive(:find_by_id).with(group.id).and_return(nil)
    end

    it 'does not rest the callout' do
      expect(callout_count).to eq(1)

      worker.perform(group.id)

      expect(callout_count).to eq(1)
    end
  end

  def callout_count
    Users::GroupCallout.where(feature_name: feature_name).count
  end
end
