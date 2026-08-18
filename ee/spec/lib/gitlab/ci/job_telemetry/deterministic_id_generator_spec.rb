# frozen_string_literal: true

require 'fast_spec_helper'
require 'opentelemetry/sdk'

require_relative '../../../../../lib/gitlab/ci/job_telemetry/deterministic_id_generator'

RSpec.describe Gitlab::Ci::JobTelemetry::DeterministicIdGenerator, feature_category: :fleet_visibility do
  let(:primed_hex) { 'abc123def4567890' }
  let(:generator) { described_class.new }

  describe '#generate_span_id' do
    subject(:span_id) { generator.generate_span_id }

    it 'returns 8 bytes' do
      expect(span_id.bytesize).to eq(8)
    end

    it 'returns a different value on each call' do
      expect(generator.generate_span_id).not_to eq(generator.generate_span_id)
    end

    context 'when a span_id is primed via #with_span_id' do
      let(:captured_ids) { [] }

      context 'and called once inside the block' do
        before do
          generator.with_span_id(primed_hex) { captured_ids << span_id }
        end

        it 'returns the primed value' do
          expect(captured_ids.first.unpack1('H*')).to eq(primed_hex)
        end
      end

      context 'and called twice inside the block', :aggregate_failures do
        before do
          generator.with_span_id(primed_hex) do
            captured_ids << generator.generate_span_id
            captured_ids << generator.generate_span_id
          end
        end

        it 'returns the primed value only on first call' do
          expect(captured_ids.first.unpack1('H*')).to eq(primed_hex)
          expect(captured_ids.last.unpack1('H*')).not_to eq(primed_hex)
        end
      end
    end
  end

  describe '#with_span_id' do
    let(:captured_ids) { [] }

    context 'when the block exits cleanly' do
      before do
        generator.with_span_id(primed_hex) { generator.generate_span_id }
      end

      it 'clears the primed value' do
        expect(generator.generate_span_id.unpack1('H*')).not_to eq(primed_hex)
      end
    end

    context 'when the block raises an error' do
      before do
        generator.with_span_id(primed_hex) { raise 'boom' }
      rescue StandardError
        # expected
      end

      it 'clears the primed value' do
        expect(generator.generate_span_id.unpack1('H*')).not_to eq(primed_hex)
      end
    end

    context 'when calls are nested' do
      let(:outer_hex) { 'aaaaaaaaaaaaaaaa' }
      let(:inner_hex) { 'bbbbbbbbbbbbbbbb' }

      before do
        generator.with_span_id(outer_hex) do
          generator.with_span_id(inner_hex) { captured_ids << generator.generate_span_id }
          captured_ids << generator.generate_span_id
        end
      end

      it 'restores the outer primed value after the inner block exits' do
        expect(captured_ids.map { |id| id.unpack1('H*') }).to eq([inner_hex, outer_hex])
      end
    end

    context 'with concurrent threads' do
      let(:thread_count) { 5 }
      let(:results) { {} }

      before do
        threads = Array.new(thread_count) do |i|
          Thread.new do
            generator.with_span_id(format('%016x', i)) do
              sleep(0.01) # interleave threads
              results[i] = generator.generate_span_id.unpack1('H*')
            end
          end
        end
        threads.each(&:join)
      end

      it 'isolates primed span_ids per thread' do
        expect(results).to eq(thread_count.times.index_with { |i| format('%016x', i) })
      end
    end
  end

  describe '#generate_trace_id' do
    subject(:trace_id) { generator.generate_trace_id }

    it 'returns 16 bytes' do
      expect(trace_id.bytesize).to eq(16)
    end
  end
end
