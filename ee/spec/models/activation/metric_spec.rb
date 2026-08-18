# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Activation::Metric, feature_category: :onboarding do
  describe 'associations' do
    it { is_expected.to belong_to(:user).required(true) }
    it { is_expected.to belong_to(:namespace).optional }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:metric) }
  end

  describe 'scopes' do
    let_it_be(:user) { create(:user) }
    let_it_be(:other_user) { create(:user) }
    let_it_be(:namespace) { create(:namespace) }
    let_it_be(:metric) { create(:activation_metric, user: user, namespace: namespace) }
    let_it_be(:other_metric) { create(:activation_metric, user: other_user) }

    describe '.for_user' do
      it 'returns metrics for the given user' do
        expect(described_class.for_user(user)).to contain_exactly(metric)
      end
    end

    describe '.for_namespace' do
      it 'returns metrics for the given namespace' do
        expect(described_class.for_namespace(namespace)).to contain_exactly(metric)
      end
    end

    describe '.by_metric' do
      it 'returns metrics matching the given metric type' do
        expect(described_class.by_metric(:merged_mr)).to contain_exactly(metric, other_metric)
      end
    end
  end

  describe '.track' do
    let_it_be(:user) { create(:user) }
    let(:metric) { :merged_mr }
    let(:namespace) { group }
    let_it_be(:group) { create(:group) }
    let_it_be(:subgroup) { create(:group, parent: group) }

    subject(:track) { described_class.track(metric, user: user, namespace: namespace) }

    context 'when feature flag is enabled' do
      before do
        stub_feature_flags(activation_tracking: user)
      end

      it 'records the metric' do
        expect { track }.to change { described_class.count }.by(1)

        record = described_class.last
        expect(record.user_id).to eq(user.id)
        expect(record.namespace_id).to eq(group.id)
        expect(record.metric).to eq('merged_mr')
      end

      context 'when namespace is a subgroup' do
        let(:namespace) { subgroup }

        it 'resolves to the root namespace' do
          track

          record = described_class.last
          expect(record.namespace_id).to eq(group.id)
        end
      end

      context 'when namespace is nil' do
        let(:namespace) { nil }

        it 'records the metric without a namespace' do
          expect { track }.to change { described_class.count }.by(1)

          record = described_class.last
          expect(record.namespace_id).to be_nil
        end
      end

      context 'when metric is nil' do
        let(:metric) { nil }

        it 'does not record the metric' do
          expect { track }.not_to change { described_class.count }
        end
      end
    end

    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(activation_tracking: false)
      end

      it 'does not record the metric' do
        expect { track }.not_to change { described_class.count }
      end
    end
  end

  describe '.record_for' do
    let_it_be(:user) { create(:user) }
    let_it_be(:namespace) { create(:namespace) }

    context 'when no existing record exists' do
      it 'creates a new record' do
        expect do
          described_class.record_for(user_id: user.id, metric: :merged_mr, namespace_id: namespace.id)
        end.to change { described_class.count }.by(1)
      end
    end

    context 'when record already exists' do
      before_all do
        create(:activation_metric, user: user, namespace: namespace)
      end

      it 'returns the existing record without creating a duplicate' do
        expect do
          described_class.record_for(user_id: user.id, metric: :merged_mr, namespace_id: namespace.id)
        end.not_to change { described_class.count }
      end
    end

    context 'when namespace_id is nil' do
      it 'creates a record without namespace' do
        expect do
          described_class.record_for(user_id: user.id, metric: :merged_mr)
        end.to change { described_class.count }.by(1)

        record = described_class.last
        expect(record.namespace_id).to be_nil
      end

      it 'does not create duplicate records' do
        described_class.record_for(user_id: user.id, metric: :merged_mr)

        expect do
          described_class.record_for(user_id: user.id, metric: :merged_mr)
        end.not_to change { described_class.count }
      end
    end

    it 'always returns an Activation::Metric instance' do
      result = described_class.record_for(user_id: user.id, metric: :merged_mr, namespace_id: namespace.id)
      expect(result).to be_a(described_class)
    end
  end

  describe '.completed?' do
    let_it_be(:user) { create(:user) }
    let_it_be(:namespace) { create(:namespace) }
    let_it_be(:metric_record) { create(:activation_metric, user: user, namespace: namespace) }

    context 'when the metric has been recorded' do
      it 'returns true' do
        expect(described_class.completed?(user_id: user.id, metric: :merged_mr, namespace_id: namespace.id)).to be(true)
      end
    end

    context 'when the metric has not been recorded' do
      let_it_be(:other_user) { create(:user) }

      it 'returns false' do
        expect(described_class.completed?(user_id: other_user.id, metric: :merged_mr)).to be(false)
      end
    end

    context 'when checking without namespace' do
      let_it_be(:user_without_ns) { create(:user) }
      let_it_be(:metric_without_ns) { create(:activation_metric, user: user_without_ns, namespace: nil) }

      it 'returns true for nil namespace' do
        expect(described_class.completed?(user_id: user_without_ns.id, metric: :merged_mr)).to be(true)
      end
    end
  end
end
