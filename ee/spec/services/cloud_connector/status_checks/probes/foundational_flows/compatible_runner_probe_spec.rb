# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::StatusChecks::Probes::FoundationalFlows::CompatibleRunnerProbe,
  feature_category: :duo_agent_platform do
  describe '#execute' do
    subject(:result) { described_class.new.execute }

    let(:duo_tag) { ::Ai::DuoWorkflows::Workflow::WORKLOAD_TAG }
    let(:no_runner_message) do
      "No instance runner with the '#{duo_tag}' tag is registered. " \
        "Register an active instance runner with this tag and a Docker-compatible executor " \
        "(such as docker, docker-autoscaler, or kubernetes) to run foundational flows."
    end

    let(:paused_runner_message) do
      "All instance runners with the '#{duo_tag}' tag are paused. " \
        "Unpause at least one to run foundational flows."
    end

    let(:not_connected_message) do
      "No instance runner with the '#{duo_tag}' tag has connected yet. " \
        "Start the runner so it registers with GitLab before running foundational flows."
    end

    let(:wrong_executor_message) do
      "No instance runner with the '#{duo_tag}' tag uses a Docker-compatible executor. " \
        "Reconfigure the runner to use docker, docker-autoscaler, kubernetes, or another " \
        "Docker-based executor so it can run foundational flows."
    end

    shared_examples 'a successful probe' do
      it 'reports success' do
        expect(result).to be_a(CloudConnector::StatusChecks::Probes::ProbeResult)
        expect(result.name).to eq(:compatible_runner_probe)
        expect(result.success?).to be(true)
        expect(result.message).to eq('A compatible runner is available.')
      end
    end

    shared_examples 'a failed probe' do |message_var|
      it 'reports failure with an actionable message' do
        expect(result).to be_a(CloudConnector::StatusChecks::Probes::ProbeResult)
        expect(result.name).to eq(:compatible_runner_probe)
        expect(result.success?).to be(false)
        expect(result.message).to eq(send(message_var))
      end
    end

    def create_eligible_runner(runner_type:, active: true, tags: [duo_tag], executor: :docker, **runner_args)
      runner = create(:ci_runner, runner_type, active: active, tag_list: tags, **runner_args)
      create(:ci_runner_machine, runner: runner, executor_type: executor) if executor
      runner
    end

    context 'when no runners exist' do
      it_behaves_like 'a failed probe', :no_runner_message
    end

    context 'with an instance runner that has the duo tag, is active, and has a docker manager' do
      before do
        create_eligible_runner(runner_type: :instance)
      end

      it_behaves_like 'a successful probe'
    end

    context 'with an instance runner whose only manager is a shell executor' do
      before do
        create_eligible_runner(runner_type: :instance, executor: :shell)
      end

      it_behaves_like 'a failed probe', :wrong_executor_message
    end

    context 'with an instance runner that is paused' do
      before do
        create_eligible_runner(runner_type: :instance, active: false)
      end

      it_behaves_like 'a failed probe', :paused_runner_message
    end

    context 'with a project-scoped runner that is otherwise eligible' do
      let_it_be(:project) { create(:project) }

      before do
        create_eligible_runner(runner_type: :project, projects: [project])
      end

      it_behaves_like 'a failed probe', :no_runner_message
    end

    context 'with an instance runner that lacks the duo tag' do
      before do
        create_eligible_runner(runner_type: :instance, tags: %w[other])
      end

      it_behaves_like 'a failed probe', :no_runner_message
    end

    context 'with an instance runner that has no runner managers' do
      before do
        create_eligible_runner(runner_type: :instance, executor: nil)
      end

      it_behaves_like 'a failed probe', :not_connected_message
    end

    context 'with multiple managers where at least one is docker-compatible' do
      before do
        runner = create(:ci_runner, :instance, active: true, tag_list: [duo_tag])
        create(:ci_runner_machine, runner: runner, executor_type: :shell)
        create(:ci_runner_machine, runner: runner, executor_type: :kubernetes)
      end

      it_behaves_like 'a successful probe'
    end

    context 'when the persisted executor_type column is stale but the cached value is docker-compatible' do
      before do
        runner = create(:ci_runner, :instance, active: true, tag_list: [duo_tag])
        manager = create(:ci_runner_machine, runner: runner, executor_type: :unknown)
        manager.cache_attributes(executor_type: 'docker')
      end

      it_behaves_like 'a successful probe'
    end
  end
end
