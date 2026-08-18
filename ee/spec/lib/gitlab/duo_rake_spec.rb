# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'gitlab:duo tasks', :gitlab_duo, :silence_stdout, feature_category: :duo_chat do
  include RakeHelpers

  before_all do
    Rake.application.rake_require 'tasks/gitlab/duo'
    Rake::Task.define_task(:environment)
  end

  describe 'duo:setup' do
    let(:setup_instance) do
      instance_double(Gitlab::Duo::Developments::Setup)
    end

    before do
      allow(Gitlab::Duo::Developments::Setup).to receive(:new).and_return(setup_instance)
      allow(setup_instance).to receive(:execute).and_return(true)
    end

    it 'creates a Gitlab::Duo::Developments::Setup instance with correct arguments' do
      Rake::Task['gitlab:duo:setup'].invoke('test')

      expect(Gitlab::Duo::Developments::Setup).to have_received(:new).with(hash_including(add_on: 'test'))
    end
  end

  describe 'duo:setup_evaluation' do
    let(:task_name) { 'gitlab:duo:setup_evaluation' }
    let(:root_group_path) { 'my-evaluation-group' }
    let(:setup_evaluation_service_instance) do
      instance_double(Gitlab::Duo::Developments::SetupGroupsForModelEvaluation)
    end

    subject(:task) { Rake::Task[task_name] }

    before do
      allow(Gitlab::Duo::Developments::SetupGroupsForModelEvaluation).to receive(:new)
        .with(hash_including(root_group_path: root_group_path))
        .and_return(setup_evaluation_service_instance)

      allow(setup_evaluation_service_instance).to receive(:execute)

      task.reenable
    end

    it 'instantiates SetupGroupsForModelEvaluation with args and calls execute' do
      expect(Gitlab::Duo::Developments::SetupGroupsForModelEvaluation).to receive(:new)
        .with(hash_including(root_group_path: root_group_path))
        .and_return(setup_evaluation_service_instance)
      expect(setup_evaluation_service_instance).to receive(:execute)

      task.invoke(root_group_path)
    end

    context 'when root_group_path argument is not provided' do
      before do
        allow(Gitlab::Duo::Developments::SetupGroupsForModelEvaluation).to receive(:new)
          .and_call_original
      end

      it 'raises an error because the argument is required by the service initializer' do
        expect { task.invoke }.to raise_error(RuntimeError, 'You must specify :root_group_path')
      end
    end
  end

  describe 'duo:fix_pipeline_seeder' do
    let(:task_name) { 'gitlab:duo:fix_pipeline_seeder' }
    let(:output_file) { 'custom_output.yml' }

    subject(:task) { Rake::Task[task_name] }

    before do
      allow(Gitlab::Duo::Developments::FixPipelineSeeder).to receive(:seed_pipelines)
      task.reenable
    end

    it 'calls FixPipelineSeeder.seed_pipelines with default output file when no argument provided' do
      expect(Gitlab::Duo::Developments::FixPipelineSeeder).to receive(:seed_pipelines)
        .with(output_file: 'fix_pipeline_evaluation_pipelines.yml')

      task.invoke
    end

    it 'calls FixPipelineSeeder.seed_pipelines with custom output file when argument provided' do
      expect(Gitlab::Duo::Developments::FixPipelineSeeder).to receive(:seed_pipelines)
        .with(output_file: output_file)

      task.invoke(output_file)
    end
  end

  describe 'duo:onboard_dap' do
    let(:task_name) { 'gitlab:duo:onboard_dap' }

    subject(:task) { Rake::Task[task_name] }

    before do
      Rake::Task.define_task(:gitlab_environment)
      allow(Gitlab::Duo::Developments::DapOnboarding).to receive(:execute)
      task.reenable
    end

    it 'calls DapOnboarding.execute' do
      expect(Gitlab::Duo::Developments::DapOnboarding).to receive(:execute)

      task.invoke
    end
  end
end
