# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::Minutes::UpdateBuildMinutesService, feature_category: :hosted_runners do
  include ::Ci::MinutesHelpers

  let(:namespace) { create(:group, shared_runners_minutes_limit: 100) }
  let(:project) { create(:project, :private, namespace: namespace) }
  let(:pipeline) { create(:ci_pipeline, project: project) }

  let(:duration) { 1.hour }
  let(:build) do
    build_created_at = 2.hours.ago
    create(:ci_build, :success,
      runner: runner, pipeline: pipeline,
      started_at: build_created_at, finished_at: build_created_at + duration)
  end

  let(:namespace_usage) { Ci::Minutes::NamespaceMonthlyUsage.find_or_create_current(namespace_id: namespace.id) }
  let(:project_usage) { Ci::Minutes::ProjectMonthlyUsage.find_or_create_current(project_id: project.id) }

  subject { described_class.new(project, nil).execute(build) }

  describe '#execute', :aggregate_failures, :freeze_time do
    shared_examples 'does nothing' do
      it 'does not update monthly usages' do
        expect { subject }.to not_change { Ci::Minutes::NamespaceMonthlyUsage.count }
          .and not_change { Ci::Minutes::ProjectMonthlyUsage.count }
      end
    end

    shared_examples 'updates usage' do |expected_ci_minutes, expected_shared_runners_duration|
      it 'tracks the usage on a monthly basis' do
        subject

        expect(namespace_usage.amount_used.to_f).to eq(expected_ci_minutes)
        expect(namespace_usage.shared_runners_duration).to eq(expected_shared_runners_duration)

        expect(project_usage.amount_used.to_f).to eq(expected_ci_minutes)
        expect(project_usage.shared_runners_duration).to eq(expected_shared_runners_duration)
      end
    end

    context 'with shared runner', :sidekiq_inline do
      let(:cost_factor) { 2.0 }
      let(:runner) { create(:ci_runner, :instance, private_projects_minutes_cost_factor: cost_factor) }

      it_behaves_like 'updates usage', 120, 1.hour

      context 'when on .com', :saas do
        it 'sends an email' do
          expect_next_instance_of(Ci::Minutes::EmailNotificationService) do |service|
            expect(service).to receive(:execute)
          end

          subject
        end
      end

      context 'when not on .com', :sidekiq_inline do
        before do
          allow(Gitlab).to receive(:com?).and_return(false)
        end

        it 'does not send an email' do
          expect(Ci::Minutes::EmailNotificationService).not_to receive(:new)

          subject
        end
      end

      context 'when consumption is 0', :saas, :sidekiq_inline do
        before do
          allow_next_instance_of(::Gitlab::Ci::Minutes::Consumption) do |consumption|
            allow(consumption).to receive(:amount).and_return(0)
          end
        end

        it 'updates only the shared runners duration' do
          expect { subject }.to change { Ci::Minutes::NamespaceMonthlyUsage.count }

          expect(namespace_usage.amount_used).to eq(0)
          expect(namespace_usage.shared_runners_duration).to eq(build.duration)

          expect(project_usage.amount_used).to eq(0)
          expect(project_usage.shared_runners_duration).to eq(build.duration)
        end

        it 'does not send an email' do
          expect(Ci::Minutes::EmailNotificationService).not_to receive(:new)

          subject
        end
      end

      context 'when usage has existing amount', :sidekiq_inline do
        let(:existing_ci_minutes) { 100 }
        let(:existing_shared_runners_duration) { 200 }

        before do
          set_ci_minutes_used(namespace, existing_ci_minutes, existing_shared_runners_duration)

          create(:ci_project_monthly_usage,
            project: project,
            amount_used: existing_ci_minutes,
            shared_runners_duration: existing_shared_runners_duration)
        end

        it_behaves_like 'updates usage', 220, 200 + 1.hour

        it 'creates tracking event' do
          expect { subject }.to trigger_internal_events("track_ci_build_minutes_with_runner_type")
            .with(
              namespace: namespace,
              additional_properties: { value: 60.0, label: 'instance_type' }
            )
        end
      end

      context 'when group is subgroup', :sidekiq_inline do
        let(:subgroup) { create(:group, parent: namespace) }
        let(:project) { create(:project, :private, group: subgroup) }

        it_behaves_like 'updates usage', 120, 1.hour
      end
    end

    context 'for project runner', :sidekiq_inline do
      let(:runner) { create(:ci_runner, :project, projects: [project]) }

      it_behaves_like 'does nothing'
    end

    context 'when runner is nil', :sidekiq_inline do
      let(:cost_factor) { 2.0 }
      let(:runner) { nil }

      it_behaves_like 'does nothing'

      it 'tracks event' do
        expect { subject }.to trigger_internal_events("track_ci_build_minutes_with_runner_type")
          .with(
            namespace: namespace,
            additional_properties: { value: 60.0, label: nil }
          )
      end
    end

    context 'with dedicated gitlab hosted runner' do
      let(:cost_factor) { 3.0 }
      let(:runner) { create(:ci_runner, :instance, private_projects_minutes_cost_factor: cost_factor) }

      before do
        allow(runner).to receive(:dedicated_gitlab_hosted?).and_return(true)
        allow(::Gitlab::CurrentSettings).to receive(:gitlab_dedicated_instance?).and_return(true)
      end

      it 'uses HostedRunners::Consumption for calculation' do
        allow(::Ci::Minutes::UpdateGitlabHostedRunnerMonthlyUsageWorker).to receive(:perform_async)
        amount = 180
        consumption_double = instance_double(::Gitlab::Ci::Minutes::HostedRunners::Consumption, amount: amount)

        expect(::Gitlab::Ci::Minutes::HostedRunners::Consumption).to receive(:new)
          .with(pipeline: build.pipeline, runner_matcher: build.runner.runner_matcher, duration: build.duration)
          .and_return(consumption_double)

        expect(::Ci::Minutes::UpdateGitlabHostedRunnerMonthlyUsageWorker).to receive(:perform_async)
          .with(
            namespace.id,
            {
              compute_minutes: amount,
              duration: build.duration,
              project_id: build.project_id,
              runner_id: build.runner_id,
              build_id: build.id
            }.stringify_keys
          )

        subject
      end

      it 'does not update instance usage' do
        expect(::Ci::Minutes::UpdateProjectAndNamespaceUsageWorker).not_to receive(:perform_async)

        subject
      end

      context 'with sidekiq integrated', :sidekiq_inline do
        def find_usage
          Ci::Minutes::GitlabHostedRunnerMonthlyUsage.find_or_create_current(
            root_namespace_id: namespace.id,
            project_id: project.id,
            runner_id: runner.id
          )
        end

        it 'increases the usage' do
          subject

          usage = find_usage

          expect(usage.compute_minutes_used).to be_within(1).of(180)
          expect(usage.runner_duration_seconds).to eq(3600) # 1 hours in seconds
        end

        context 'with existing usage' do
          before do
            Ci::Minutes::GitlabHostedRunnerMonthlyUsage.create!(
              root_namespace_id: namespace.id,
              runner_id: runner.id,
              project_id: project.id,
              billing_month: Time.current.beginning_of_month,
              compute_minutes_used: 3,
              runner_duration_seconds: 60
            )
          end

          it 'increases the usage' do
            subject

            usage = find_usage

            expect(usage.compute_minutes_used).to be_within(1).of(183)
            expect(usage.runner_duration_seconds).to eq(3660)
          end
        end
      end
    end
  end
end
