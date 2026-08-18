# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::LifecyclePolicy, feature_category: :team_planning do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:lifecycle) { create(:work_item_custom_lifecycle, namespace: group) }

  subject(:policy) { described_class.new(user, lifecycle) }

  before do
    stub_licensed_features(work_item_status: true)
  end

  context 'when user does not have access to the namespace' do
    it { is_expected.to be_disallowed(:read_work_item_lifecycle) }
  end

  context 'when user has access to the namespace' do
    before_all do
      group.add_guest(user)
    end

    it { is_expected.to be_allowed(:read_work_item_lifecycle) }

    context 'when feature is not available' do
      before do
        stub_licensed_features(work_item_status: false)
      end

      it { is_expected.to be_disallowed(:read_work_item_lifecycle) }
    end
  end
end
