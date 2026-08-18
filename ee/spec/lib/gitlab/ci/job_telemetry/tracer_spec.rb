# frozen_string_literal: true

require 'fast_spec_helper'

require_relative '../../../../../../ee/lib/gitlab/ci/job_telemetry/tracer'

RSpec.describe Gitlab::Ci::JobTelemetry::Tracer, feature_category: :fleet_visibility do
  let(:otel_endpoint) { 'https://otel-collector.example.com/v1/traces' }

  subject(:tracer_instance) { described_class.instance }

  before do
    allow(tracer_instance).to receive(:endpoint).and_return(otel_endpoint)
    tracer_instance.clear_memoization(:provider)
  end

  describe '#enabled?' do
    context 'when ci_telemetry_otel_endpoint is configured' do
      it { is_expected.to be_enabled }
    end

    context 'when ci_telemetry_otel_endpoint is nil' do
      let(:otel_endpoint) { nil }

      it { is_expected.not_to be_enabled }
    end

    context 'when ci_telemetry_otel_endpoint is blank' do
      let(:otel_endpoint) { '' }

      it { is_expected.not_to be_enabled }
    end
  end

  describe '#tracer' do
    subject(:tracer) { tracer_instance.tracer }

    context 'when endpoint is configured' do
      let(:provider) { tracer.instance_variable_get(:@tracer_provider) }

      it { is_expected.to be_a(OpenTelemetry::SDK::Trace::Tracer) }

      it 'creates an OTLP exporter targeting the configured endpoint' do
        expect(OpenTelemetry::Exporter::OTLP::Exporter)
          .to receive(:new).with(endpoint: otel_endpoint).and_call_original

        tracer
      end

      it 'uses ALWAYS_ON sampler' do
        expect(provider.sampler).to eq(OpenTelemetry::SDK::Trace::Samplers::ALWAYS_ON)
      end

      it 'sets the service name resource attribute' do
        expect(provider.resource.attribute_enumerator.to_h).to include('service.name' => described_class::SERVICE_NAME)
      end

      it 'emits spans with attributes' do
        exporter = OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
        allow(OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor)
          .to receive(:new)
          .and_return(OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(exporter))

        span = tracer.start_span('test_span', attributes: { 'ci.job.id' => '123' })
        span.finish

        recorded = exporter.finished_spans.first
        expect(recorded.name).to eq('test_span')
        expect(recorded.attributes).to include('ci.job.id' => '123')
      end
    end

    context 'when endpoint is not configured' do
      let(:otel_endpoint) { nil }

      it { is_expected.to be_a(OpenTelemetry::Trace::Tracer) }
      it { is_expected.not_to be_a(OpenTelemetry::SDK::Trace::Tracer) }
    end

    context 'when exporter creation fails' do
      before do
        allow(OpenTelemetry::Exporter::OTLP::Exporter)
          .to receive(:new).and_raise(ArgumentError, 'invalid endpoint')
        allow(Gitlab::AppLogger).to receive(:warn)
      end

      it { is_expected.to be_a(OpenTelemetry::Trace::Tracer) }
      it { is_expected.not_to be_a(OpenTelemetry::SDK::Trace::Tracer) }

      it 'logs a warning' do
        tracer

        expect(Gitlab::AppLogger).to have_received(:warn).with(
          message: 'Failed to create CI telemetry tracer',
          error_class: 'ArgumentError',
          error_message: 'invalid endpoint'
        )
      end
    end
  end

  describe '#id_generator' do
    subject(:id_generator) { tracer_instance.id_generator }

    it { is_expected.to be_a(Gitlab::Ci::JobTelemetry::DeterministicIdGenerator) }

    it 'returns the same memoized instance across calls' do
      is_expected.to be(tracer_instance.id_generator)
    end

    it 'is the same instance installed on the provider' do
      provider = tracer_instance.tracer.instance_variable_get(:@tracer_provider)

      is_expected.to be(provider.id_generator)
    end
  end

  describe '#reset!' do
    subject(:reset!) { tracer_instance.reset! }

    context 'when provider exists' do
      let(:first_provider) { tracer_instance.tracer.instance_variable_get(:@tracer_provider) }

      before do
        first_provider
      end

      it 'shuts down the existing provider' do
        expect(first_provider).to receive(:shutdown)

        reset!
      end

      it 'creates a new provider on next access' do
        reset!

        new_provider = tracer_instance.tracer.instance_variable_get(:@tracer_provider)
        expect(new_provider).not_to eq(first_provider)
      end

      it 'creates a new id_generator on next access' do
        first_id_generator = tracer_instance.id_generator
        reset!

        expect(tracer_instance.id_generator).not_to be(first_id_generator)
      end
    end

    context 'when provider is a no-op (endpoint not configured)' do
      let(:otel_endpoint) { nil }

      it 'does not call shutdown but still clears memoization' do
        first_provider = tracer_instance.send(:provider)
        expect(first_provider).not_to be_a(::OpenTelemetry::SDK::Trace::TracerProvider)
        expect(first_provider).not_to receive(:shutdown)

        reset!

        expect(tracer_instance.send(:provider)).not_to be(first_provider)
      end
    end

    context 'when endpoint changes' do
      let(:new_endpoint) { 'https://new-collector.example.com/v1/traces' }

      before do
        tracer_instance.tracer
        allow(tracer_instance).to receive(:endpoint).and_return(new_endpoint)
        allow(OpenTelemetry::Exporter::OTLP::Exporter).to receive(:new).and_call_original
      end

      it 'picks up the new endpoint after reset!' do
        tracer_instance.tracer
        expect(OpenTelemetry::Exporter::OTLP::Exporter).not_to have_received(:new)

        reset!
        tracer_instance.tracer
        expect(OpenTelemetry::Exporter::OTLP::Exporter)
          .to have_received(:new).with(endpoint: new_endpoint)
      end
    end
  end

  describe 'isolation from global tracer provider' do
    it 'does not modify the global OpenTelemetry tracer provider' do
      expect { tracer_instance.tracer }.not_to change { OpenTelemetry.tracer_provider }
    end
  end

  describe '#endpoint' do
    subject(:endpoint) { tracer_instance.send(:endpoint) }

    before do
      allow(tracer_instance).to receive(:endpoint).and_call_original
      allow(Gitlab::CurrentSettings).to receive(:method_missing)
                                          .with(:ci_telemetry_otel_endpoint).and_return(otel_endpoint)
    end

    it 'reads from Gitlab::CurrentSettings' do
      expect(endpoint).to eq(otel_endpoint)
    end
  end
end
