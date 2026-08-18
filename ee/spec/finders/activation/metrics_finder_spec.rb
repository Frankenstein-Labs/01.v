# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Activation::MetricsFinder, feature_category: :onboarding do
  let_it_be(:user) { create(:user) }
  let_it_be(:other_user) { create(:user) }
  let_it_be(:namespace) { create(:namespace) }
  let_it_be(:other_namespace) { create(:namespace) }
  let_it_be(:metric_with_namespace) { create(:activation_metric, user: user, namespace: namespace) }
  let_it_be(:metric_other_namespace) { create(:activation_metric, user: user, namespace: other_namespace) }
  let_it_be(:metric_other_user) { create(:activation_metric, user: other_user, namespace: namespace) }

  let(:params) { {} }

  describe '#execute' do
    subject(:result) { described_class.new(user: user, params: params).execute }

    it 'returns all metrics for the user' do
      expect(result).to contain_exactly(metric_with_namespace, metric_other_namespace)
    end

    context 'when filtering by namespace' do
      let(:params) { { namespace: namespace } }

      it 'returns metrics for the given namespace' do
        expect(result).to contain_exactly(metric_with_namespace)
      end
    end

    context 'when filtering by metric type' do
      let(:params) { { metric: :merged_mr } }

      it 'returns metrics matching the given type' do
        expect(result).to contain_exactly(metric_with_namespace, metric_other_namespace)
      end
    end

    context 'when filtering by both namespace and metric type' do
      let(:params) { { namespace: namespace, metric: :merged_mr } }

      it 'returns metrics matching both filters' do
        expect(result).to contain_exactly(metric_with_namespace)
      end
    end

    it 'does not apply a default limit' do
      expect(result.limit_value).to be_nil
    end
  end
end
