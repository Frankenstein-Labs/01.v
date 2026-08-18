# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::CreatePipelineService, feature_category: :pipeline_composition do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user) { project.first_owner }
  let_it_be(:downstream_project) do
    create(:project, path: 'project', namespace: create(:namespace), developers: user)
  end

  let(:service) { described_class.new(project, user, { ref: 'refs/heads/master' }) }

  let(:config) do
    <<~YAML
    regular_job:
      stage: build
      script:
        - echo 'hello'
    bridge_dag_job:
      stage: test
      needs:
        - regular_job
      trigger: '#{downstream_project.full_path}'
    YAML
  end

  before do
    stub_ci_pipeline_yaml_file(config)
  end

  it 'persists pipeline' do
    pipeline = create_pipeline!

    expect(pipeline).to be_persisted
  end

  it 'persists both jobs' do
    expect { create_pipeline! }.to change { Ci::Build.count }.from(0).to(1)
      .and change { Ci::Bridge.count }.from(0).to(1)
  end

  it 'persists bridge needs' do
    pipeline = create_pipeline!
    job = pipeline.builds.first
    bridge = pipeline.bridges.first

    expect(bridge.needs.first.name).to eq(job.name)
  end

  it 'persists bridge target project' do
    pipeline = create_pipeline!
    bridge = pipeline.bridges.first

    expect(bridge.downstream_project).to eq downstream_project
  end

  it "sets scheduling_type of bridge_dag_job as 'dag'" do
    pipeline = create_pipeline!
    bridge = pipeline.bridges.first

    expect(bridge.scheduling_type).to eq('dag')
  end

  context 'when needs is empty array' do
    let(:config) do
      <<~YAML
        regular_job:
          stage: build
          script: echo 'hello'
        bridge_dag_job:
          stage: test
          needs: []
          trigger: 'some/project'
      YAML
    end

    it 'creates a pipeline with regular_job and bridge_dag_job pending' do
      pipeline = create_pipeline!
      processables = pipeline.processables
      Ci::InitialPipelineProcessWorker.new.perform(pipeline.id)

      regular_job = processables.find { |processable| processable.name == 'regular_job' }
      bridge_dag_job = processables.find { |processable| processable.name == 'bridge_dag_job' }

      expect(pipeline).to be_persisted
      expect(regular_job.status).to eq('pending')
      expect(bridge_dag_job.status).to eq('pending')
    end
  end

  context 'with cross pipeline artifacts' do
    let_it_be(:dependency) { create(:ci_build, :success, name: 'dependency', project: downstream_project) }
    let_it_be(:job_artifact) { create(:ci_job_artifact, :dotenv, job: dependency, accessibility: 'public') }
    let_it_be(:dependency_variable) { create(:ci_job_variable, :dotenv_source, job: dependency) }

    let(:config) do
      <<~YAML
      regular_job:
        stage: build
        variables:
          DEPENDENCY_PROJECT: #{downstream_project.full_path}
          DEPENDENCY_REF: #{dependency.ref}
          DEPENDENCY_NAME: #{dependency.name}
        script:
          - echo 'hello'
        needs:
          - project: ${DEPENDENCY_PROJECT}
            ref: ${DEPENDENCY_REF}
            job: ${DEPENDENCY_NAME}
            artifacts: true
      YAML
    end

    before do
      stub_ci_pipeline_yaml_file(config)
      stub_licensed_features(cross_project_pipelines: true)
    end

    shared_examples 'job with dependencies and variables' do
      it 'has dependencies and variables', :aggregate_failures do
        pipeline = create_pipeline!
        job = pipeline.builds.first

        expect(job).to be_present
        expect(job.all_dependencies).to include(dependency)
        expect(job.scoped_variables.to_hash).to include(dependency_variable.key => dependency_variable.value)
      end
    end

    context 'when feature is available through license' do
      before do
        stub_licensed_features(cross_project_pipelines: true)
      end

      it_behaves_like 'job with dependencies and variables'
    end

    context 'when feature is available through usage ping features' do
      before do
        stub_usage_ping_features(true)
      end

      it_behaves_like 'job with dependencies and variables'
    end
  end

  def create_pipeline!
    service.execute(:push).payload
  end
end
