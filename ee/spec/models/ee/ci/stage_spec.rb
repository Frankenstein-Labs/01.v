# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::Stage, :saas, feature_category: :continuous_integration do
  let_it_be(:pipeline) { create(:ci_empty_pipeline) }

  describe '#reserved_pre?' do
    subject { stage.reserved_pre? }

    let(:stage) { create(:ci_stage, pipeline: pipeline, project: pipeline.project, name: name) }

    context 'when name matches the reserved pre stage name' do
      let(:name) { ::Gitlab::Ci::Config::Stages::RESERVED_POLICY_PRE }

      it { is_expected.to be(true) }
    end

    context 'when name does not match the reserved pre stage name' do
      let(:name) { 'build' }

      it { is_expected.to be(false) }
    end
  end
end
