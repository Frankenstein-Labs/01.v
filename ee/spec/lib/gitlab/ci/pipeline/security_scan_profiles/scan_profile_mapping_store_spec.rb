# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Pipeline::SecurityScanProfiles::ScanProfileMappingStore,
  :clean_gitlab_redis_shared_state, feature_category: :security_policy_management do
  describe '.redis_key' do
    it 'returns a namespaced key' do
      expect(described_class.redis_key(123)).to eq('scan_profile_builds:123')
    end
  end

  describe '.profile_id_for_build' do
    let(:build) { instance_double(::Ci::Build, pipeline_id: 1, name: 'sast-0') }

    context 'when Redis has the mapping' do
      before do
        key = described_class.redis_key(1)
        ::Gitlab::Redis::SharedState.with do |redis|
          redis.hset(key, 'sast-0', '42')
        end
      end

      it 'returns the profile_id from Redis' do
        expect(described_class.profile_id_for_build(build)).to eq(42)
      end
    end

    context 'when Redis does not have the mapping' do
      it 'returns nil' do
        expect(described_class.profile_id_for_build(build)).to be_nil
      end
    end
  end

  describe '.persist_mappings' do
    let_it_be(:project) { create(:project) }
    let_it_be(:user) { create(:user) }
    let_it_be(:pipeline) { create(:ci_pipeline, project: project, user: user) }

    let_it_be(:profile_build) do
      create(:ci_build, project: project, user: user, pipeline: pipeline, name: 'sast-0')
    end

    let_it_be(:regular_build) do
      create(:ci_build, project: project, user: user, pipeline: pipeline, name: 'rspec')
    end

    let(:context) do
      instance_double(::Gitlab::Ci::Pipeline::SecurityScanProfiles::PipelineContext)
    end

    context 'when profile-triggered builds exist' do
      before do
        allow(context).to receive(:injected_jobs?).and_return(true)
        allow(context).to receive(:each_injected_job_with_profile_id)
          .and_yield('sast-0', 42)

        described_class.persist_mappings(pipeline: pipeline, context: context)
      end

      it 'writes profile_id mappings to Redis keyed by job name' do
        key = described_class.redis_key(pipeline.id)
        stored = ::Gitlab::Redis::SharedState.with { |redis| redis.hgetall(key) }

        expect(stored).to eq('sast-0' => '42')
      end

      it 'does not include regular builds' do
        key = described_class.redis_key(pipeline.id)
        stored = ::Gitlab::Redis::SharedState.with { |redis| redis.hgetall(key) }

        expect(stored).not_to have_key('rspec')
      end

      it 'sets a TTL on the Redis key' do
        key = described_class.redis_key(pipeline.id)
        ttl = ::Gitlab::Redis::SharedState.with { |redis| redis.ttl(key) }

        expect(ttl).to be_within(5).of(24.hours.to_i)
      end
    end

    context 'when multiple injected jobs exist' do
      before do
        allow(context).to receive(:injected_jobs?).and_return(true)
        allow(context).to receive(:each_injected_job_with_profile_id)
          .and_yield('sast-0', 42)
          .and_yield('secret-detection-0', 99)

        described_class.persist_mappings(pipeline: pipeline, context: context)
      end

      it 'writes all job name mappings to Redis' do
        key = described_class.redis_key(pipeline.id)
        stored = ::Gitlab::Redis::SharedState.with { |redis| redis.hgetall(key) }

        expect(stored).to eq('sast-0' => '42', 'secret-detection-0' => '99')
      end
    end

    context 'when no injected jobs exist' do
      before do
        allow(context).to receive(:injected_jobs?).and_return(false)
      end

      it 'does not write to Redis' do
        described_class.persist_mappings(pipeline: pipeline, context: context)

        key = described_class.redis_key(pipeline.id)
        exists = ::Gitlab::Redis::SharedState.with { |redis| redis.exists?(key) }

        expect(exists).to be(false)
      end
    end

    context 'when injected jobs yield no profile IDs' do
      before do
        allow(context).to receive(:injected_jobs?).and_return(true)
        allow(context).to receive(:each_injected_job_with_profile_id)
      end

      it 'does not write to Redis' do
        described_class.persist_mappings(pipeline: pipeline, context: context)

        key = described_class.redis_key(pipeline.id)
        exists = ::Gitlab::Redis::SharedState.with { |redis| redis.exists?(key) }

        expect(exists).to be(false)
      end
    end

    context 'when Redis raises an error' do
      before do
        allow(context).to receive(:injected_jobs?).and_return(true)
        allow(context).to receive(:each_injected_job_with_profile_id)
          .and_yield('sast-0', 42)

        redis_double = instance_double(Redis)
        allow(::Gitlab::Redis::SharedState).to receive(:with).and_yield(redis_double)
        allow(redis_double).to receive(:multi).and_raise(Redis::BaseError, 'connection refused')
      end

      it 'does not raise' do
        expect { described_class.persist_mappings(pipeline: pipeline, context: context) }.not_to raise_error
      end

      it 'tracks the exception' do
        expect(::Gitlab::ErrorTracking).to receive(:track_exception)
          .with(instance_of(Redis::BaseError), extra: { pipeline_id: pipeline.id })

        described_class.persist_mappings(pipeline: pipeline, context: context)
      end
    end
  end
end
