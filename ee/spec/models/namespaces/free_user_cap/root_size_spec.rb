# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::FreeUserCap::RootSize, :saas, feature_category: :seat_cost_management do
  let_it_be_with_refind(:namespace) { create(:group_with_plan, :private, plan: :free_plan) }

  let(:model) { described_class.new(namespace) }
  let(:current_size) { 50.megabytes }

  before do
    create(:plan_limits, plan: namespace.gitlab_subscription.hosted_plan, storage_size_limit: 100)
    create(:namespace_root_storage_statistics, namespace: namespace, storage_size: current_size)
  end

  describe '#above_size_limit?' do
    subject { model.above_size_limit? }

    context 'when below limit' do
      it { is_expected.to be(false) }
    end

    context 'when above limit' do
      let(:current_size) { 101.megabytes }

      before do
        # proves local class override method takes effect
        allow(model).to receive(:enforce_limit?).and_return(false)
      end

      it { is_expected.to be(true) }
    end
  end

  describe '#limit' do
    subject { model.limit }

    context 'when there is additional purchased storage and a plan' do
      before do
        namespace.update!(additional_purchased_storage_size: 10_000)
      end

      it { is_expected.to eq(10_100.megabytes) }
    end

    context 'when there is no additional purchased storage' do
      before do
        namespace.update!(additional_purchased_storage_size: 0)
      end

      it { is_expected.to eq(100.megabytes) }
    end

    context 'with cached values', :use_clean_rails_memory_store_caching do
      it 'caches the value' do
        key = [
          namespace.actual_limits.cache_key_with_version,
          'namespaces',
          namespace.id,
          described_class::LIMIT_CACHE_NAME
        ]

        subject

        expect(Rails.cache.read(key)).to eq(100.megabytes)
      end
    end
  end
end
