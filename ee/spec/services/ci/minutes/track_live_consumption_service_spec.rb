# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::Minutes::TrackLiveConsumptionService, :saas, feature_category: :hosted_runners do
  let(:project) { create(:project, :private, shared_runners_enabled: true, namespace: namespace) }
  let(:pipeline) { create(:ci_pipeline, project: project) }
  let(:namespace) { create(:namespace_with_plan, plan: :default_plan, shared_runners_minutes_limit: 100) }
  let(:user) { create(:user) }
  let(:build) { create(:ci_build, :running, project: project, pipeline: pipeline, runner: runner, user: user) }
  let(:runner) { create(:ci_runner, :instance) }

  let(:service) { described_class.new(build) }

  describe '#execute', :clean_gitlab_redis_shared_state do
    subject { service.execute }

    shared_examples 'returns early' do |error_message|
      it 'returns an error response' do
        response = subject

        expect(response).to be_error
        expect(response.message).to eq(error_message)
      end
    end

    shared_examples 'limit not exceeded' do |expected_balance, expected_consumption|
      it 'does not drop the build', :aggregate_failures do
        response = subject
        expect(response).to be_success
        expect(response.message).to eq('Compute minutes limit not exceeded')
        expect(response.payload.fetch(:current_balance).round).to eq(expected_balance)

        expect(service.live_consumption.to_i).to eq(expected_consumption)
      end
    end

    shared_examples 'limit exceeded' do |balance|
      it 'drops the build' do
        response = subject
        expect(response).to be_success
        expect(response.message).to eq('Build dropped due to compute minutes limit exceeded')
        expect(response.payload.fetch(:current_balance).round).to eq(balance)

        expect(build.reload).to be_failed
        expect(build.failure_reason).to eq('ci_quota_exceeded')

        expect(service.live_consumption.to_i).to eq(minutes_consumption)
      end

      it 'logs event' do
        allow(Gitlab::AppLogger).to receive(:info).and_call_original
        expect(Gitlab::AppLogger).to receive(:info).with(
          message: 'Build dropped due to compute minutes limit exceeded',
          namespace: project.root_namespace.name,
          project_path: project.full_path,
          build_id: build.id,
          user_id: user&.id,
          username: user&.username)

        subject
      end
    end

    context 'when build is not running' do
      let(:build) { create(:ci_build, :success) }

      it_behaves_like 'returns early', 'Build is not running'
    end

    context 'when runner is not of instance type' do
      let(:runner) { create(:ci_runner, :project, projects: [project]) }

      it_behaves_like 'returns early', 'Cost factor not enabled for build'
    end

    context 'when cost factor is not enabled for build' do
      before do
        allow(build).to receive(:cost_factor_enabled?).and_return(false)
      end

      it_behaves_like 'returns early', 'Cost factor not enabled for build'
    end

    context 'when namespace has unlimited minutes' do
      before do
        usage = double('usage', quota_enabled?: false)
        allow(project).to receive(:ci_minutes_usage).and_return(usage)
      end

      it_behaves_like 'returns early', 'Cost factor not enabled for build'
    end

    context 'when build has not been tracked recently' do
      it 'considers the current consumption as zero' do
        response = subject
        expect(response).to be_success
        expect(response.message).to eq('Build consumption is zero')
      end
    end

    context 'when build has been tracked recently', :freeze_time do
      before do
        service.time_last_tracked_consumption!(1.minute.ago.utc)
      end

      it_behaves_like 'limit not exceeded', 99, 1
    end

    context 'when current consumption exceeds the limit but not the grace period', :freeze_time do
      before do
        service.time_last_tracked_consumption!(200.minutes.ago.utc)
      end

      it_behaves_like 'limit not exceeded', -100, 200
    end

    context 'when current consumption exceeds the limit and the grace period', :freeze_time do
      let(:minutes_consumption) do
        namespace.shared_runners_minutes_limit + consumption_threshold.abs + 1
      end

      let(:consumption_threshold) { described_class::FREE_USER_CONSUMPTION_THRESHOLD }

      before do
        service.time_last_tracked_consumption!(minutes_consumption.minutes.ago.utc)
      end

      it_behaves_like 'limit exceeded', -101

      it 'caches the paid namespace check', :use_clean_rails_memory_store_caching do
        cache_key = "ci:minutes:user:#{build.user_id}:paid_namespace"

        expect { subject }.to change {
          Rails.cache.read(cache_key)
        }.from(nil).to(false)
      end

      context 'when namespace is on a trial hosted plan' do
        let(:namespace) do
          create(:namespace_with_plan,
            plan: :premium_plan,
            trial: true,
            trial_starts_on: Date.current,
            trial_ends_on: Date.current.advance(days: 15),
            shared_runners_minutes_limit: 100)
        end

        it_behaves_like 'limit exceeded', -101
      end

      context 'when namespace is on a paid plan' do
        let(:namespace) { create(:namespace_with_plan, plan: :premium_plan, shared_runners_minutes_limit: 100) }
        let(:consumption_threshold) { described_class::CONSUMPTION_THRESHOLD }

        it_behaves_like 'limit exceeded', -1001

        it 'uses the original consumption threshold for paid namespaces' do
          expect(build.user).to receive(:belongs_to_paid_namespace?).with(exclude_trials: true).and_return(true)

          expect(service.send(:consumption_threshold)).to eq(described_class::CONSUMPTION_THRESHOLD)
        end
      end

      context 'when user is nil' do
        let(:user) { nil }
        let(:consumption_threshold) { described_class::CONSUMPTION_THRESHOLD }

        it_behaves_like 'limit exceeded', -1001
      end

      context 'when feature flag is disabled' do
        let(:consumption_threshold) { described_class::CONSUMPTION_THRESHOLD }

        before do
          stub_feature_flags(ci_reduced_consumption_threshold_for_free_users: false)
        end

        it_behaves_like 'limit exceeded', -1001
      end
    end
  end

  describe '#live_consumption', :clean_gitlab_redis_shared_state do
    subject { service.live_consumption }

    context 'when build has not been tracked' do
      it { is_expected.to be_zero }
    end

    context 'when build has been tracked once' do
      it 'returns the consumption since last update' do
        freeze_time do
          service.time_last_tracked_consumption!(3.minutes.ago)
          service.execute

          expect(subject).to eq(3.0)
        end
      end
    end

    context 'when build has been tracked multiple times' do
      before do
        service.time_last_tracked_consumption!(7.minutes.ago)

        travel_to 5.minutes.ago do
          service.execute # track 2 min
        end

        service.execute # track 5 min

        travel_to 10.minutes.from_now do
          service.execute # track 10 min
        end
      end

      it 'accumulates the consumption over different runs' do
        expect(subject.to_i).to eq(17)
      end
    end
  end
end
