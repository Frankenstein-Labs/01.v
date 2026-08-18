# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::RetryPipelineService, :freeze_time, feature_category: :continuous_integration do
  let_it_be(:runner) { create(:ci_runner, :instance, :online) }
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:project) { create(:project, :repository, developers: user) }
  let_it_be(:sha) { project.repository.commit.sha }

  let(:pipeline) { create(:ci_pipeline, sha: sha, project: project) }
  let(:service) { described_class.new(project, user) }

  before do
    create(:protected_branch, :developers_can_merge, name: pipeline.ref, project: project)
  end

  context 'when the namespace is out of compute minutes' do
    let_it_be(:namespace) { create(:namespace, :with_used_build_minutes_limit) }
    let_it_be_with_reload(:project) { create(:project, :repository, namespace: namespace, developers: user) }
    let_it_be(:private_runner) do
      create(:ci_runner, :project, :online, projects: [project], tag_list: ['ruby'], run_untagged: false)
    end

    before do
      create_build('rspec 1', :failed)
      create_build('rspec 2', :canceled, tag_list: ['ruby'])
    end

    it 'retries the builds with available runners' do
      service.execute(pipeline)

      expect(pipeline.statuses.count).to eq(3)
      expect(build('rspec 1')).to be_failed
      expect(build('rspec 2')).to be_pending
      expect(pipeline.reload).to be_running
    end
  end

  context 'when allowed_plans are not matched', :saas do
    let_it_be(:namespace) { create(:namespace_with_plan, plan: :premium_plan) }
    let_it_be_with_reload(:project) { create(:project, :repository, namespace: namespace, developers: user) }
    let_it_be(:ultimate_plan) { create(:ultimate_plan) }
    let_it_be(:restricted_runner) do
      create(:ci_runner, :instance, :online,
        tag_list: ['for_plan'], run_untagged: false,
        allowed_plan_name_uids: [Plan::PLAN_NAME_UID_LIST[:ultimate]])
    end

    before do
      create_build('rspec 1', :failed, tag_list: ['for_plan'])
      create_build('rspec 2', :canceled)
    end

    it 'retries the builds with runners matching the plan of the namespace' do
      service.execute(pipeline)

      expect(pipeline.statuses.count).to eq(3)
      expect(build('rspec 1')).to be_failed
      expect(build('rspec 2')).to be_pending
      expect(pipeline.reload).to be_running
    end
  end

  context 'when both compute minutes and allowed plans are violated', :saas do
    let_it_be(:namespace) { create(:namespace_with_plan, :with_used_build_minutes_limit, plan: :premium_plan) }
    let_it_be_with_reload(:project) { create(:project, :repository, namespace: namespace, developers: user) }
    let_it_be(:ultimate_plan) { create(:ultimate_plan) }
    let_it_be(:restricted_runner) do
      create(:ci_runner, :instance, :online,
        tag_list: ['for_plan'], run_untagged: false,
        allowed_plan_name_uids: [Plan::PLAN_NAME_UID_LIST[:ultimate]])
    end

    before do
      create_build('rspec 1', :failed, tag_list: ['for_plan'])
    end

    it 'does not retry jobs that do not have available runner' do
      service.execute(pipeline)

      expect(pipeline.statuses.count).to eq(1)
      expect(build('rspec 1')).to be_failed
      expect(pipeline.reload).to be_failed
    end
  end

  context 'when the user is not authorized to run jobs' do
    before do
      allow_next_instance_of(::Users::IdentityVerification::AuthorizeCi) do |instance|
        allow(instance).to receive(:authorize_run_jobs!)
          .and_raise(::Users::IdentityVerification::Error, 'authorization error')
      end
    end

    it 'returns an error' do
      response = service.execute(pipeline)

      expect(response.http_status).to eq(:forbidden)
      expect(response.errors).to include('authorization error')
      expect(pipeline.reload).not_to be_running
    end
  end

  context 'when the pipeline is a completed merge train pipeline' do
    let(:merge_request) { create(:merge_request, source_project: project) }
    let(:pipeline) do
      create(:ci_pipeline, :merged_result_pipeline, :failed, merge_request: merge_request).tap do |pipeline|
        pipeline.update!(ref: merge_request.train_ref_path)
      end
    end

    before do
      create(:ci_build, :failed, pipeline: pipeline)
    end

    it 'does not retry the pipeline', :aggregate_failures do
      response = service.execute(pipeline)

      expect(response).to be_error
      expect(response.reason).to eq(:pipeline_not_retryable)
      expect(response.http_status).to eq(:unprocessable_entity)
      expect(pipeline.reload).to be_failed
      expect(pipeline.statuses.count).to eq(1)
    end

    it 'reuses the pipeline association inverse for jobs' do
      create(:ci_build, :failed, pipeline: pipeline)

      expect do
        service.send(:builds_relation, pipeline).each(&:retryable?)
      end
        .not_to exceed_query_limit(0).for_query(/p_ci_pipelines/)
    end
  end

  def build(name)
    pipeline.reload.statuses.latest.find_by(name: name)
  end

  def create_build(name, status, **opts)
    create(:ci_build, name: name, status: status, pipeline: pipeline, **opts) do |build|
      ::Ci::ProcessPipelineService.new(pipeline).execute
    end
  end
end
