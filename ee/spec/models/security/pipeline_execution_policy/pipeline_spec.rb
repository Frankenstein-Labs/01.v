# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::PipelineExecutionPolicy::Pipeline, feature_category: :security_policy_management do
  let(:policy_config) { build(:pipeline_execution_policy_config) }
  let(:instance) { described_class.new(pipeline: build(:ci_empty_pipeline), policy_config: policy_config) }

  describe '#strategy_override_project_ci?' do
    subject { instance.strategy_override_project_ci? }

    it { is_expected.to be(false) }

    context 'when strategy is override_project_ci' do
      let(:policy_config) { build(:pipeline_execution_policy_config, :override_project_ci) }

      it { is_expected.to be(true) }
    end
  end

  describe '#strategy_inject_policy?' do
    subject { instance.strategy_inject_policy? }

    it { is_expected.to be(false) }

    context 'when strategy is inject_policy' do
      let(:policy_config) { build(:pipeline_execution_policy_config, :inject_policy) }

      it { is_expected.to be(true) }
    end
  end

  describe '#suffix_on_conflict?' do
    subject { instance.suffix_on_conflict? }

    context 'when suffix_strategy is `never`' do
      let(:policy_config) { build(:pipeline_execution_policy_config, :suffix_never) }

      it { is_expected.to be(false) }
    end

    context 'when suffix_strategy is `on_conflict`' do
      let(:policy_config) { build(:pipeline_execution_policy_config, :suffix_on_conflict) }

      it { is_expected.to be(true) }
    end
  end

  describe '#skip_ci_allowed?' do
    subject { instance.skip_ci_allowed?(123) }

    context 'when skip_ci is disallowed' do
      let(:policy_config) { build(:pipeline_execution_policy_config, :skip_ci_disallowed) }

      it { is_expected.to be(false) }
    end

    context 'when skip_ci is allowed' do
      let(:policy_config) { build(:pipeline_execution_policy_config, :skip_ci_allowed) }

      it { is_expected.to be(true) }
    end
  end

  describe '#no_pipeline_allowed?' do
    subject { instance.no_pipeline_allowed?(123) }

    context 'when no_pipeline is disallowed' do
      let(:policy_config) { build(:pipeline_execution_policy_config, :no_pipeline_disallowed) }

      it { is_expected.to be(false) }
    end

    context 'when no_pipeline is allowed' do
      let(:policy_config) { build(:pipeline_execution_policy_config, :no_pipeline_allowed) }

      it { is_expected.to be(true) }
    end
  end
end
