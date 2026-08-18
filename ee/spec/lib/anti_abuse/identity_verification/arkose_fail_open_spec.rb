# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AntiAbuse::IdentityVerification::ArkoseFailOpen,
  :clean_gitlab_redis_shared_state,
  feature_category: :instance_resiliency do
  subject(:fail_open) { described_class }

  let(:bucket_hours)   { described_class::BUCKET_DURATION_HOURS }
  let(:success_prefix) { described_class::COUNTER_SUCCESS_KEY_PREFIX }
  let(:failure_prefix) { described_class::COUNTER_FAILURE_KEY_PREFIX }
  let(:stream_key)     { described_class::VERIFICATION_RATE_STREAM_KEY }
  let(:fail_open_key)  { described_class::FAIL_OPEN_ACTIVE_KEY }
  let(:fail_open_ttl)  { described_class::FAIL_OPEN_TTL_SECONDS }

  # Freeze at bucket boundary for determinism
  let(:t0) { Time.zone.parse('2025-11-05 00:00:00') }

  # ---------- Helpers ----------
  def bucket_id(at_time)
    "#{at_time.to_date.strftime('%Y%m%d')}-#{at_time.hour / bucket_hours}"
  end

  def key_for(prefix, at_time)
    "#{prefix}#{bucket_id(at_time)}"
  end

  def redis_get(key)
    Gitlab::Redis::SharedState.with { |r| r.get(key)&.to_i }
  end

  def redis_get_s(key)
    Gitlab::Redis::SharedState.with { |r| r.get(key) }
  end

  def redis_ttl(key)
    Gitlab::Redis::SharedState.with { |r| r.ttl(key) }
  end

  def redis_xlen(key)
    Gitlab::Redis::SharedState.with { |r| r.call('xlen', key) || 0 }
  end

  def redis_xrange(key)
    Gitlab::Redis::SharedState.with { |r| r.call('xrange', key, '-', '+') || [] }
  end

  def seed_prev_bucket(success:, failure:, at_time:)
    prev_bucket = bucket_id(at_time)
    s_key = "#{success_prefix}#{prev_bucket}"
    f_key = "#{failure_prefix}#{prev_bucket}"
    Gitlab::Redis::SharedState.with do |r|
      r.incrby(s_key, success)
      r.incrby(f_key, failure)
    end
  end

  def seed_baseline(rates)
    Gitlab::Redis::SharedState.with do |r|
      rates.each do |v|
        r.xadd(stream_key, { 'bucket' => 'seed', 'vrate' => v.to_s })
      end
    end
  end
  # -----------------------------

  describe '#active?' do
    before do
      Gitlab::Redis::SharedState.with { |r| r.set(fail_open_key, 'test', ex: fail_open_ttl) }
    end

    it 'returns true when fail-open key exists' do
      expect(fail_open.active?).to be(true)
    end
  end

  describe '#track_token_verification_result' do
    it 'increments SUCCESS counter within the same bucket' do
      travel_to(t0) do
        key = key_for(success_prefix, t0)

        expect do
          fail_open.track_token_verification_result(success: true)
        end.to change { redis_get(key) }.from(nil).to(1)
      end

      t1 = t0 + 30.minutes
      travel_to(t1) do
        key = key_for(success_prefix, t1)

        expect do
          fail_open.track_token_verification_result(success: true)
        end.to change { redis_get(key) }.from(1).to(2)
      end
    end

    it 'increments FAILURE counter within the same bucket' do
      travel_to(t0) do
        key = key_for(failure_prefix, t0)

        expect do
          fail_open.track_token_verification_result(success: false)
        end.to change { redis_get(key) }.from(nil).to(1)
      end

      t1 = t0 + 30.minutes
      travel_to(t1) do
        key = key_for(failure_prefix, t1)

        expect do
          fail_open.track_token_verification_result(success: false)
        end.to change { redis_get(key) }.from(1).to(2)
      end
    end

    it 'does not reset TTL when incrementing within the same bucket' do
      travel_to(t0) do
        key = key_for(success_prefix, t0)

        fail_open.track_token_verification_result(success: true)
        ttl_initial = redis_ttl(key)

        travel 1.minute

        fail_open.track_token_verification_result(success: true)
        ttl_after = redis_ttl(key)

        expect(redis_get(key)).to eq(2)
        expect(ttl_after).to be <= ttl_initial
      end
    end

    it 'starts SUCCESS from zero in a new bucket and sets TTL once' do
      travel_to(t0) do
        key0 = key_for(success_prefix, t0)

        expect do
          fail_open.track_token_verification_result(success: true)
        end.to change { redis_get(key0) }.from(nil).to(1)
      end

      t1 = t0 + bucket_hours.hours + 5.minutes
      travel_to(t1) do
        key1 = key_for(success_prefix, t1)

        expect do
          fail_open.track_token_verification_result(success: true)
        end.to change { redis_get(key1) }.from(nil).to(1)

        expect(redis_ttl(key1)).to be > 0

        key0 = key_for(success_prefix, t0)
        expect(redis_get(key0)).to eq(1)
      end
    end

    it 'starts FAILURE from zero in a new bucket and sets TTL once' do
      travel_to(t0) do
        key0 = key_for(failure_prefix, t0)

        expect do
          fail_open.track_token_verification_result(success: false)
        end.to change { redis_get(key0) }.from(nil).to(1)
      end

      t1 = t0 + bucket_hours.hours + 5.minutes
      travel_to(t1) do
        key1 = key_for(failure_prefix, t1)

        expect do
          fail_open.track_token_verification_result(success: false)
        end.to change { redis_get(key1) }.from(nil).to(1)

        expect(redis_ttl(key1)).to be > 0

        key0 = key_for(failure_prefix, t0)
        expect(redis_get(key0)).to eq(1)
      end
    end

    it 'rescues and reports unexpected errors' do
      allow(fail_open).to receive(:increment_counter!).and_raise(Redis::BaseError.new('boom'))

      expect(Gitlab::ErrorTracking).to receive(:track_exception)
        .with(instance_of(Redis::BaseError))

      expect { fail_open.track_token_verification_result(success: true) }.not_to raise_error
    end

    describe 'previous-bucket anomaly evaluation' do
      before do
        stub_const("#{described_class}::MIN_ATTEMPTS_FOR_EVALUATION", 5)
      end

      let(:prev_bucket_time) { t0 + described_class::BUCKET_DURATION_SECONDS.seconds - 5.minutes }
      let(:new_bucket_time)  { t0 + described_class::BUCKET_DURATION_SECONDS.seconds + 1.minute }

      describe 'verification rate of the previous window' do
        context 'when previous-bucket attempts are sufficient' do
          before do
            # 5 total attempts (>= MIN_ATTEMPTS_FOR_EVALUATION)
            travel_to(prev_bucket_time) { seed_prev_bucket(success: 3, failure: 2, at_time: t0) }
          end

          it 'is recorded' do
            travel_to(new_bucket_time) do
              expect { fail_open.track_token_verification_result(success: true) }
                .to change { redis_xlen(stream_key) }.by(1)
            end
          end
        end

        context 'when previous-bucket attempts are insufficient' do
          before do
            # 3 total attempts (< MIN_ATTEMPTS_FOR_EVALUATION)
            travel_to(t0) { seed_prev_bucket(success: 2, failure: 1, at_time: t0) }
          end

          it 'is not recorded' do
            new_bucket_time = t0 + bucket_hours.hours + 1.minute

            travel_to(new_bucket_time) do
              expect { fail_open.track_token_verification_result(success: true) }
                .not_to change { redis_xlen(stream_key) }
            end
          end
        end

        context 'when there is insufficient baseline data' do
          before do
            allow(fail_open).to receive(:historical_verification_rates).and_return([])
            travel_to(prev_bucket_time) { seed_prev_bucket(success: 5, failure: 5, at_time: t0) }
          end

          it 'is recorded despite missing baseline' do
            initial_len = redis_xlen(stream_key)

            travel_to(new_bucket_time) do
              expect { fail_open.track_token_verification_result(success: true) }
                .to change { redis_xlen(stream_key) }.from(initial_len).to(initial_len + 1)
            end
          end
        end

        context 'when anomaly decision is non-anomalous' do
          before do
            seed_baseline([90.0, 92.0, 88.0, 91.0, 89.0, 93.0, 87.0, 90.5, 89.5, 92.5])
            travel_to(prev_bucket_time) { seed_prev_bucket(success: 9, failure: 1, at_time: t0) }
          end

          it 'is appended to the stream' do
            travel_to(new_bucket_time) do
              expect { fail_open.track_token_verification_result(success: true) }
                .to change { redis_xlen(stream_key) }.by(1)

              entry = redis_xrange(stream_key).last
              _id, fields = entry

              expect(fields).to include('bucket')
              expect(fields).to include('vrate')
              expect(fields).to include('90.0')
            end
          end
        end

        context 'when anomaly decision is anomalous' do
          before do
            seed_baseline([95.0, 96.0, 94.0, 97.0, 95.0, 96.0, 95.0, 94.0, 96.0, 95.0])
            travel_to(prev_bucket_time) { seed_prev_bucket(success: 1, failure: 500, at_time: t0) }
          end

          it 'is not appended to the stream' do
            initial_len = redis_xlen(stream_key)

            travel_to(new_bucket_time) do
              expect { fail_open.track_token_verification_result(success: true) }
                .not_to change { redis_xlen(stream_key) }.from(initial_len)
            end
          end
        end
      end

      describe '#calculate_verification_rate' do
        before do
          travel_to(prev_bucket_time) do
            seed_prev_bucket(success: 3, failure: 2, at_time: t0)
          end

          allow(Gitlab::AppLogger).to receive(:info)
        end

        it 'returns the verification rate and logs when log is true' do
          travel_to(new_bucket_time) do
            result = fail_open.send(:calculate_verification_rate, log: true)

            expect(result).to eq(60.0) # 3 / 5 * 100
            expect(Gitlab::AppLogger).to have_received(:info).with(
              hash_including(
                message: 'Arkose token verification rate',
                bucket: bucket_id(t0),
                success_count: 3,
                failure_count: 2,
                total_count: 5,
                rate: 60.0
              )
            )
          end
        end

        it 'returns the verification rate and does not log when log is false' do
          travel_to(new_bucket_time) do
            result = fail_open.send(:calculate_verification_rate, log: false)

            expect(result).to eq(60.0)
            expect(Gitlab::AppLogger).not_to have_received(:info)
          end
        end
      end

      describe '#historical_verification_rates' do
        it 'returns floats for entries with vrate and skips entries without vrate' do
          Gitlab::Redis::SharedState.with do |r|
            r.xadd(stream_key, { 'bucket' => '202511050', 'vrate' => '90.0' })
            r.xadd(stream_key, { 'bucket' => '202511051' })
          end

          result = fail_open.send(:historical_verification_rates)

          expect(result).to eq([90.0])
        end
      end
    end

    describe 'fail-open activation on anomaly' do
      before do
        stub_const("#{described_class}::MIN_ATTEMPTS_FOR_EVALUATION", 5)
        stub_const("#{described_class}::MIN_BASELINE_COUNT", 10)
        stub_const("#{described_class}::FAIL_OPEN_TTL_SECONDS", 10 * 60)

        seed_baseline(Array.new(10, 95.0))

        travel_to(prev_bucket_time) { seed_prev_bucket(success: 5, failure: 5, at_time: t0) }

        decision = AntiAbuse::IdentityVerification::ArkoseAnomalyDetection::Decision.new(
          anomalous: true, reason: 'zscore=-3.2 mean=95.0 std=1.0 current=50.0'
        )
        allow(AntiAbuse::IdentityVerification::ArkoseAnomalyDetection)
          .to receive(:decide).and_return(decision)
      end

      let(:prev_bucket_time) { t0 + described_class::BUCKET_DURATION_SECONDS.seconds - 5.minutes }
      let(:new_bucket_time)  { t0 + described_class::BUCKET_DURATION_SECONDS.seconds + 1.minute }

      it 'sets the fail-open key with reason and TTL, marks active, and does not append vrate' do
        initial_len = redis_xlen(stream_key)

        travel_to(new_bucket_time) do
          expect { fail_open.track_token_verification_result(success: true) }
            .not_to change { redis_xlen(stream_key) }
        end

        value = redis_get_s(fail_open_key)
        ttl   = redis_ttl(fail_open_key)

        expect(value).to eq('zscore=-3.2 mean=95.0 std=1.0 current=50.0')
        expect(ttl).to be > 0
        expect(ttl).to be <= fail_open_ttl
        expect(fail_open.active?).to be(true)
        expect(redis_xlen(stream_key)).to eq(initial_len)
      end
    end
  end
end
