# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Minutes::RunnerCostFactor, feature_category: :continuous_integration do
  let_it_be(:project) { build_stubbed(:project) }
  let(:runner_matcher) { instance_double(Gitlab::Ci::Matching::RunnerMatcher) }

  subject(:new_factor) { described_class.new(runner_matcher, project) }

  describe '#value' do
    context 'when project is public' do
      let(:cost_factor) { 0.5 }

      before do
        allow(project).to receive(:public?).and_return(true)
        allow(runner_matcher).to receive(:public_projects_minutes_cost_factor).and_return(cost_factor)
      end

      it 'returns the public projects minutes cost factor' do
        expect(new_factor.value).to eq(cost_factor)
      end
    end

    context 'when project is private' do
      let(:cost_factor) { 1.0 }

      before do
        allow(project).to receive(:public?).and_return(false)
        allow(runner_matcher).to receive(:private_projects_minutes_cost_factor).and_return(cost_factor)
      end

      it 'returns the private projects minutes cost factor' do
        expect(new_factor.value).to eq(cost_factor)
      end
    end
  end
end
