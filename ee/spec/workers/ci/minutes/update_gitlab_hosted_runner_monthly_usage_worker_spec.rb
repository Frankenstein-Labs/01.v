# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::Minutes::UpdateGitlabHostedRunnerMonthlyUsageWorker, feature_category: :hosted_runners do
  let_it_be(:namespace) { create(:namespace) }
  let_it_be(:project) { create(:project, namespace: namespace) }
  let_it_be(:runner) { create(:ci_runner, :project, projects: [project]) }
  let_it_be(:build) { create(:ci_build, project: project, runner: runner) }

  let(:compute_minutes) { 100.0 }
  let(:duration) { 60_000 }
  let(:worker) { described_class.new }

  let(:params) do
    {
      'compute_minutes' => compute_minutes,
      'duration' => duration,
      'project_id' => project.id,
      'runner_id' => runner.id,
      'build_id' => build.id
    }
  end

  describe '#perform', :clean_gitlab_redis_shared_state do
    subject(:perform) { worker.perform(namespace.id, params) }

    context 'when called for the first time' do
      it 'executes the service' do
        service_instance = double
        expect(::Ci::Minutes::UpdateGitlabHostedRunnerMonthlyUsageService).to receive(:new)
          .with(namespace.id, project.id, runner.id, build.id, compute_minutes, duration)
          .and_return(service_instance)
        expect(service_instance).to receive(:execute)

        perform
      end
    end

    context 'when called multiple times with the same parameters', :sidekiq_inline, :freeze_time do
      before do
        allow(::Gitlab::CurrentSettings).to receive(:gitlab_dedicated_instance?).and_return(true)
      end

      it 'increments the minutes only once' do
        worker.perform(namespace.id, params)
        worker.perform(namespace.id, params)

        usage = Ci::Minutes::GitlabHostedRunnerMonthlyUsage.first

        expect(usage.compute_minutes_used).to eq(compute_minutes)
        expect(usage.runner_duration_seconds).to eq(duration)
      end
    end
  end
end
