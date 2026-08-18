# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::InitialPipelineProcessWorker, '#perform', :freeze_time, feature_category: :continuous_integration do
  let_it_be(:namespace) { create(:namespace, :with_used_build_minutes_limit) }
  let_it_be(:project) { create(:project, :small_repo, namespace: namespace) }
  let_it_be(:sha) { project.repository.commit.sha }
  let_it_be_with_reload(:pipeline) do
    create(:ci_pipeline, :with_job, sha: sha, project: project, status: :created)
  end

  let_it_be(:instance_runner) { create(:ci_runner, :instance, :online) }

  include_examples 'an idempotent worker' do
    let(:job_args) { pipeline.id }

    context 'when the project is out of compute minutes' do
      it 'marks the pipeline as failed' do
        expect(pipeline).to be_created

        subject

        expect(pipeline.reload).to be_failed
      end
    end
  end
end
