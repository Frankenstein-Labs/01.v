# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::TokenInstrumentation, feature_category: :system_access do
  describe '.instrument' do
    let_it_be(:jwk) { build(:cloud_connector_keys).to_jwk }
    let(:operation_type) { 'self_signed' }
    let(:service_name) { nil }
    let(:result_value) { 'JWT_TOKEN' }

    let(:real_duration) { 0.05 }
    let(:cpu_duration) { 0.02 }

    let(:counter_double) { instance_double(::Prometheus::Client::Counter, increment: nil) }

    before do
      allow(Benchmark).to receive(:measure).and_yield.and_return(
        instance_double(Benchmark::Tms, real: real_duration, total: cpu_duration)
      )

      allow(::Prometheus::PidProvider).to receive(:worker_id).and_return('worker-1')

      allow(::Gitlab::Metrics).to receive(:counter).with(
        :cloud_connector_tokens_issued_total,
        'Total number of Cloud Connector tokens issued',
        worker_id: 'worker-1'
      ).and_return(counter_double)

      allow(::Gitlab::Metrics).to receive(:counter).with(
        :cloud_connector_token_creation_real_duration_seconds_total,
        'Total wall clock duration in seconds spent creating Cloud Connector tokens',
        worker_id: 'worker-1'
      ).and_return(counter_double)

      allow(::Gitlab::Metrics).to receive(:counter).with(
        :cloud_connector_token_creation_cpu_duration_seconds_total,
        'Total CPU duration in seconds spent creating Cloud Connector tokens',
        worker_id: 'worker-1'
      ).and_return(counter_double)
    end

    it 'yields and returns the result of the block' do
      result = described_class.instrument(jwk: jwk, operation_type: operation_type) { result_value }

      expect(result).to eq(result_value)
    end

    context 'when service_name is provided' do
      let(:service_name) { 'duo_chat' }

      it 'uses the given service_name in labels' do
        expected_labels = {
          operation_type: operation_type,
          service_name: service_name
        }

        expected_labels_with_kid = expected_labels.merge(kid: jwk.kid)

        expect(counter_double).to receive(:increment).with(expected_labels_with_kid)
        expect(counter_double).to receive(:increment).with(expected_labels, real_duration)
        expect(counter_double).to receive(:increment).with(expected_labels, cpu_duration)

        described_class.instrument(jwk: jwk, operation_type: operation_type, service_name: service_name) do
          result_value
        end
      end
    end
  end
end
