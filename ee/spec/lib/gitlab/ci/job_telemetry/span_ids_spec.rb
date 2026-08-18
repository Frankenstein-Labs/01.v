# frozen_string_literal: true

require 'fast_spec_helper'
require 'openssl'

require_relative '../../../../../../lib/gitlab/ci/trace_context'
require_relative '../../../../../../ee/lib/gitlab/ci/job_telemetry/span_ids'

RSpec.describe Gitlab::Ci::JobTelemetry::SpanIds, feature_category: :fleet_visibility do
  describe '.trace_id_for' do
    subject(:trace_id) { described_class.trace_id_for(42) }

    it { is_expected.to eq('0000000000000000000000000000002a') }
    it { is_expected.to match(/\A[0-9a-f]{32}\z/) }

    it 'differs for different pipeline ids' do
      expect(described_class.trace_id_for(42)).not_to eq(described_class.trace_id_for(43))
    end
  end

  describe '.for_job' do
    subject(:span_id) { described_class.for_job(100, 200, :running) }

    it { is_expected.to match(/\A[0-9a-f]{16}\z/) }

    it 'matches the documented SHA256 formula' do
      expected = OpenSSL::Digest::SHA256.hexdigest('100:200:running')[0, 16]

      is_expected.to eq(expected)
    end

    it 'differs across kinds for the same job' do
      lifecycle = described_class.for_job(100, 200, :lifecycle)
      pending = described_class.for_job(100, 200, :pending)
      running = described_class.for_job(100, 200, :running)

      expect([lifecycle, pending, running].uniq.size).to eq(3)
    end

    it 'differs across builds in the same pipeline' do
      other = described_class.for_job(100, 201, :running)

      is_expected.not_to eq(other)
    end
  end

  describe '.for_pipeline_phantom' do
    subject(:phantom_id) { described_class.for_pipeline_phantom(100) }

    it { is_expected.to match(/\A[0-9a-f]{16}\z/) }

    it 'matches the documented SHA256 formula' do
      expected = OpenSSL::Digest::SHA256.hexdigest('pipeline:100')[0, 16]

      is_expected.to eq(expected)
    end

    it 'differs from a same-input job span id (different namespace prefix)' do
      job_span = described_class.for_job(100, 100, :lifecycle)

      is_expected.not_to eq(job_span)
    end
  end

  describe '.for_bridge' do
    subject(:bridge_id) { described_class.for_bridge(42) }

    it { is_expected.to eq('000000000000002a') }

    it 'matches `format("%016x", id)` so future Bridge instrumentation can correlate' do
      is_expected.to eq(format('%016x', 42))
    end
  end

  describe 'anti-drift: SpanIds delegates to TraceContext' do
    let(:test_ids) { [0, 1, 42, 999_999, 2**53] }

    it 'trace_id_for produces identical output to TraceContext', :aggregate_failures do
      test_ids.each do |id|
        expect(described_class.trace_id_for(id)).to eq(
          Gitlab::Ci::TraceContext.trace_id_for(id)
        ), "Mismatch for trace_id_for(#{id})"
      end
    end

    it 'for_job produces identical output to TraceContext.span_id_for_job', :aggregate_failures do
      kinds = %i[lifecycle pending running]

      test_ids.each do |root_id|
        kinds.each do |kind|
          expect(described_class.for_job(root_id, 200, kind)).to eq(
            Gitlab::Ci::TraceContext.span_id_for_job(root_id, 200, kind)
          ), "Mismatch for for_job(#{root_id}, 200, #{kind})"
        end
      end
    end

    it 'for_bridge produces identical output to TraceContext.span_id_for_bridge', :aggregate_failures do
      test_ids.each do |id|
        expect(described_class.for_bridge(id)).to eq(
          Gitlab::Ci::TraceContext.span_id_for_bridge(id)
        ), "Mismatch for for_bridge(#{id})"
      end
    end
  end
end
