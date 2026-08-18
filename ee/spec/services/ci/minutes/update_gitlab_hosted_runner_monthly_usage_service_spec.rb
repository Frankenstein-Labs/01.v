# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::Minutes::UpdateGitlabHostedRunnerMonthlyUsageService, feature_category: :hosted_runners do
  let_it_be(:root_namespace) { create(:group) }
  let_it_be(:project) { create(:project, namespace: root_namespace) }
  let_it_be(:runner) { create(:ci_runner, :instance) }
  let(:namespace_id) { root_namespace.id }
  let(:project_id) { project.id }
  let(:runner_id) { runner.id }
  let(:build) { create(:ci_build) }
  let(:build_compute_minutes) { 10 }
  let(:build_duration) { 600 } # 10 minutes in seconds

  let(:monthly_usage) do
    described_class.new(namespace_id, project_id, runner_id, build.id, build_compute_minutes, build_duration)
  end

  describe '#execute', :freeze_time do
    subject(:execute) { monthly_usage.execute }

    shared_examples 'not created' do
      it 'does not create usage' do
        expect { execute }
          .not_to change { Ci::Minutes::GitlabHostedRunnerMonthlyUsage.count }
      end
    end

    shared_examples 'not updated' do
      it 'does not update usage' do
        expect { execute }
          .not_to change { Ci::Minutes::GitlabHostedRunnerMonthlyUsage.count }
      end
    end

    context 'when GitLab is a dedicated instance' do
      before do
        allow(Gitlab::CurrentSettings).to receive(:gitlab_dedicated_instance?).and_return(true)
      end

      it 'creates the monthly usage' do
        expect { execute }
          .to change { Ci::Minutes::GitlabHostedRunnerMonthlyUsage.count }.by(1)

        usage = Ci::Minutes::GitlabHostedRunnerMonthlyUsage.last
        expect(usage.runner_duration_seconds).to eq(build_duration)
        expect(usage.compute_minutes_used).to eq(build_compute_minutes)
      end

      context 'when no runner id' do
        let(:runner_id) { nil }

        it_behaves_like 'not created'
      end

      context 'when no project id' do
        let(:project_id) { nil }

        it_behaves_like 'not created'
      end

      context 'when the namespace id is null' do
        let(:namespace_id) { nil }

        it_behaves_like 'not created'
      end

      context 'when usage record already exists for the runner' do
        let(:starting_minutes) { 1 }
        let(:starting_duration) { 60 }
        let!(:usage) do
          Ci::Minutes::GitlabHostedRunnerMonthlyUsage.create!(
            root_namespace_id: root_namespace.id,
            project_id: project.id,
            runner_id: runner.id,
            compute_minutes_used: starting_minutes,
            runner_duration_seconds: starting_duration,
            billing_month: Time.current.beginning_of_month
          )
        end

        it 'updates the usage' do
          execute

          usage.reload
          expect(Ci::Minutes::GitlabHostedRunnerMonthlyUsage.count).to eq 1
          expect(usage.runner_duration_seconds).to eq(build_duration + starting_duration)
          expect(usage.compute_minutes_used).to eq(build_compute_minutes + starting_minutes)
        end

        context 'when no runner id' do
          let(:runner_id) { nil }

          it_behaves_like 'not updated'
        end

        context 'when no project id' do
          let(:project_id) { nil }

          it_behaves_like 'not updated'
        end

        context 'when no namespace id' do
          let(:namespace_id) { nil }

          it_behaves_like 'not updated'
        end
      end
    end

    context 'when GitLab is not a dedicated instance' do
      before do
        allow(Gitlab::CurrentSettings).to receive(:gitlab_dedicated_instance?).and_return(false)
      end

      it_behaves_like 'not updated'
    end
  end
end
