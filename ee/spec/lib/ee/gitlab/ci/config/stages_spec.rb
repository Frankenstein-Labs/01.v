# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe Gitlab::Ci::Config::Stages, feature_category: :pipeline_composition do
  describe '.wrap_with_reserved_stages' do
    subject { described_class.wrap_with_reserved_stages(stages) }

    context 'with nil value' do
      let(:stages) { nil }

      it { is_expected.to eq %w[.pipeline-policy-pre .pipeline-policy-post] }
    end

    context 'with values' do
      let(:stages) { %w[s1 .pipeline-policy-pre] }

      it { is_expected.to eq %w[.pipeline-policy-pre s1 .pipeline-policy-post] }
    end
  end

  describe '#inject_reserved_stages!' do
    subject(:injected_config) { described_class.new(config).inject_reserved_stages! }

    it 'does not mutate the original config' do
      config = { stages: ['test'] }
      new_config = described_class.new(config).inject_reserved_stages!

      expect(new_config).not_to eq(config)
    end

    context 'when stages are not defined' do
      let(:config) { { job: { script: 'test' } } }

      it 'returns reserved stages with default stages' do
        expect(injected_config[:stages])
          .to eq(%w[.pipeline-policy-pre .pre build test deploy .post .pipeline-policy-post])
      end
    end

    context 'when stages are empty' do
      let(:config) { { stages: [], job: { script: 'test' } } }

      it 'returns reserved stages with default stages' do
        expect(injected_config[:stages])
          .to eq(%w[.pipeline-policy-pre .pre build test deploy .post .pipeline-policy-post])
      end
    end

    context 'when stages are defined' do
      let(:config) { { stages: %w[test], job: { script: 'test' } } }

      it 'returns stages with reserved stages' do
        expect(injected_config[:stages]).to eq(%w[.pipeline-policy-pre test .pipeline-policy-post])
      end
    end

    context 'when stages contain a reserved stage' do
      let(:config) { { stages: %w[.pipeline-policy-pre test], job: { script: 'test' } } }

      it 'does not include duplicate reserved stages' do
        expect(injected_config[:stages]).to eq(%w[.pipeline-policy-pre test .pipeline-policy-post])
      end
    end

    context 'when stages contain a reserved stage in wrong order' do
      let(:config) { { stages: %w[test .pipeline-policy-pre], job: { script: 'test' } } }

      it 'returns stages with reserved stages in the correct order' do
        expect(injected_config[:stages]).to eq(%w[.pipeline-policy-pre test .pipeline-policy-post])
      end
    end
  end
end
