# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::PipelineProcessing::ReservedStageStatusCalculationService, '#execute', feature_category: :continuous_integration do
  using RSpec::Parameterized::TableSyntax
  let_it_be(:project) { create(:project) }
  let_it_be_with_reload(:pipeline) { create(:ci_empty_pipeline, ref: 'master', project: project) }

  let(:collection) { instance_double(Ci::PipelineProcessing::AtomicProcessingService::StatusCollection) }
  let(:job) { create(:ci_build, :created, name: 'test', pipeline: pipeline) }

  subject(:execute) { described_class.new(pipeline, collection, job).execute }

  context 'when pipeline has no reserved pre stage' do
    it { is_expected.to be_nil }
  end

  context 'when pipeline has a reserved pre stage' do
    let_it_be(:test_stage) { create(:ci_stage, pipeline: pipeline, name: 'test', position: 1) }
    let_it_be_with_reload(:reserved_pre_stage) do
      create(:ci_stage, pipeline: pipeline, name: '.pipeline-policy-pre', position: 0)
    end

    let!(:policy_job) do
      create(:ci_build, :created,
        name: 'policy_job',
        pipeline: pipeline,
        ci_stage: reserved_pre_stage)
    end

    context 'when job is on the reserved pre stage' do
      let(:job) do
        create(:ci_build, :created,
          name: 'test',
          pipeline: pipeline,
          ci_stage: reserved_pre_stage)
      end

      before do
        allow(collection)
          .to receive(:status_of_stage).with(reserved_pre_stage.position).and_return('running')
      end

      it { is_expected.to be_nil }
    end

    context 'when job is not on the reserved pre stage' do
      let(:job) do
        create(:ci_build, :created,
          name: 'test',
          pipeline: pipeline,
          scheduling_type: scheduling_type,
          ci_stage: test_stage)
      end

      before do
        allow(collection)
          .to receive(:status_of_stage).with(reserved_pre_stage.position).and_return(pre_stage_status)
      end

      where(:pre_stage_status, :scheduling_type, :result) do
        'running'  | 'stage' | 'running'
        'running'  | 'dag'   | 'running'
        'success'  | 'stage' | nil
        'success'  | 'dag'   | nil
        'failed'   | 'stage' | 'canceled'
        'failed'   | 'dag'   | 'canceled'
        'canceled' | 'stage' | 'canceled'
        'canceled' | 'dag'   | 'canceled'
        'skipped'  | 'stage' | 'canceled'
        'skipped'  | 'dag'   | 'canceled'
      end

      with_them do
        it { is_expected.to eq(result) }
      end
    end
  end
end
