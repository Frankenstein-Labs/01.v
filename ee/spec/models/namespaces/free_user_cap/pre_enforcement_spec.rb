# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::FreeUserCap::PreEnforcement, :saas, feature_category: :seat_cost_management do
  let_it_be(:group) { create(:group_with_plan, :private, plan: :free_plan) }

  describe '#qualifies?' do
    subject(:qualifies?) { described_class.new(group).qualifies? }

    before do
      create(:plan_limits, plan: group.gitlab_subscription.hosted_plan, storage_size_limit: 100)
      create(:namespace_root_storage_statistics, namespace: group, storage_size: current_size)
    end

    context 'when over the storage limit' do
      let(:current_size) { 101.megabytes }

      it { is_expected.to be false }
    end

    context 'when below the storage limit' do
      let(:current_size) { 50.megabytes }

      it { is_expected.to be false }
    end

    context 'when the feature flag is disabled' do
      before do
        stub_feature_flags(free_user_cap_without_storage_check: false)
      end

      context 'when over the storage limit' do
        let(:current_size) { 101.megabytes }

        it { is_expected.to be true }
      end

      context 'when below the storage limit' do
        let(:current_size) { 50.megabytes }

        it { is_expected.to be false }
      end
    end
  end
end
