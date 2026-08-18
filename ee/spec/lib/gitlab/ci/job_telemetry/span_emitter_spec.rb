# frozen_string_literal: true

require 'spec_helper'
require 'opentelemetry/sdk'

RSpec.describe Gitlab::Ci::JobTelemetry::SpanEmitter, feature_category: :fleet_visibility do
  let_it_be(:project, freeze: true) { create(:project) }
  let_it_be(:pipeline, freeze: true) { create(:ci_pipeline, project: project) }
  let_it_be(:runner, freeze: true) { create(:ci_runner, runner_type: :instance_type) }

  let_it_be_with_reload(:build) do
    create(:ci_build,
      pipeline: pipeline,
      runner: runner,
      created_at: 10.minutes.ago,
      queued_at: 9.minutes.ago,
      started_at: 8.minutes.ago,
      finished_at: 5.minutes.ago)
  end

  let(:exporter) { OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new }
  let(:id_generator) { Gitlab::Ci::JobTelemetry::DeterministicIdGenerator.new }
  let(:tracer_provider) do
    OpenTelemetry::SDK::Trace::TracerProvider.new(
      sampler: OpenTelemetry::SDK::Trace::Samplers::ALWAYS_ON,
      id_generator: id_generator
    ).tap { |p| p.add_span_processor(OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(exporter)) }
  end

  let(:tracer) { tracer_provider.tracer('gitlab-ci-rails') }

  let(:emitter) { described_class.new(build, tracer: tracer, id_generator: id_generator) }

  describe '#trace_id' do
    subject(:trace_id) { emitter.trace_id }

    it { is_expected.to eq(format('%032x', pipeline.id)) }

    context 'when the build belongs to a child pipeline' do
      let_it_be(:bridge, freeze: true) { create(:ci_bridge, pipeline: pipeline) }
      let_it_be(:child_pipeline, freeze: true) { create(:ci_pipeline, source: :parent_pipeline, project: project) }
      let_it_be(:source_pipeline, freeze: true) do
        create(:ci_sources_pipeline, source_job: bridge, source_project: project,
          pipeline: child_pipeline, project: project)
      end

      let_it_be(:build, freeze: true) { create(:ci_build, pipeline: child_pipeline) }

      it 'returns the trace_id derived from the root pipeline ID' do
        is_expected.to eq(format('%032x', pipeline.id))
      end
    end
  end

  describe '#span_id_for' do
    it 'returns a deterministic 16-char hex ID for the given kind' do
      # Independent reimplementation of the algorithm to verify output, not just
      # that the method calls itself to catch accidental changes to the formula.
      expected = OpenSSL::Digest::SHA256.hexdigest("#{pipeline.id}:#{build.id}:running")[0, 16]

      expect(emitter.span_id_for(described_class::SPAN_KIND_RUNNING)).to eq(expected)
    end

    it 'returns different IDs for different kinds' do
      ids = described_class::SPAN_NAMES.keys.map { |kind| emitter.span_id_for(kind) }

      expect(ids.uniq.size).to eq(ids.size)
    end

    it 'returns the same ID across calls for the same kind' do
      first = emitter.span_id_for(described_class::SPAN_KIND_RUNNING)
      second = emitter.span_id_for(described_class::SPAN_KIND_RUNNING)

      expect(first).to eq(second)
    end
  end

  describe '#emit_job_pending' do
    subject(:emitted_span) { exporter.finished_spans.first }

    context 'when queued_at and started_at are set' do
      before do
        emitter.emit_job_pending
      end

      it 'emits a job_pending span with queued_at and started_at timestamps' do
        expect(emitted_span).to have_attributes(
          name: 'job_pending',
          start_timestamp: to_nanoseconds(build.queued_at),
          end_timestamp: to_nanoseconds(build.started_at)
        )
      end

      it 'sets the parent span ID to job_lifecycle' do
        expected_parent = emitter.span_id_for(described_class::SPAN_KIND_LIFECYCLE)

        expect(emitted_span.parent_span_id.unpack1('H*')).to eq(expected_parent)
      end

      it 'sets base attributes' do
        expect(emitted_span.attributes).to include(
          'ci.job.id' => build.id.to_s,
          'ci.pipeline.id' => build.pipeline_id.to_s,
          'ci.project.id' => build.project_id.to_s
        )
      end
    end

    context 'when queued_at is nil' do
      before do
        build.queued_at = nil
        emitter.emit_job_pending
      end

      it 'does not emit a span' do
        expect(exporter.finished_spans).to be_empty
      end
    end

    context 'when id_generator is nil (tracer disabled)' do
      let(:emitter) { described_class.new(build, tracer: tracer, id_generator: nil) }

      before do
        emitter.emit_job_pending
      end

      it 'still emits a span (with random span_id)' do
        expect(exporter.finished_spans.size).to eq(1)
      end
    end
  end

  describe '#emit_job_running' do
    subject(:emitted_span) { exporter.finished_spans.first }

    context 'when started_at, finished_at, and runner are set' do
      before do
        emitter.emit_job_running
      end

      it 'emits a job_running span with started_at and finished_at timestamps' do
        expect(emitted_span).to have_attributes(
          name: 'job_running',
          start_timestamp: to_nanoseconds(build.started_at),
          end_timestamp: to_nanoseconds(build.finished_at)
        )
      end

      it 'sets the parent span ID to job_lifecycle' do
        expected_parent = emitter.span_id_for(described_class::SPAN_KIND_LIFECYCLE)

        expect(emitted_span.parent_span_id.unpack1('H*')).to eq(expected_parent)
      end

      it 'includes runner attributes' do
        expect(emitted_span.attributes).to include(
          'ci.runner.id' => runner.id.to_s,
          'ci.runner.type' => 'instance_type'
        )
      end
    end

    context 'when build has no runner' do
      before do
        build.runner = nil
        emitter.emit_job_running
      end

      it 'does not include runner attributes' do
        expect(emitted_span.attributes.keys).not_to include('ci.runner.id', 'ci.runner.type')
      end
    end
  end

  describe '#emit_job_lifecycle' do
    subject(:emitted_span) { exporter.finished_spans.first }

    context 'when the build belongs to a top-level pipeline' do
      before do
        emitter.emit_job_lifecycle(status: 'success')
      end

      it 'emits a job_lifecycle span with created_at and finished_at timestamps' do
        expect(emitted_span).to have_attributes(
          name: 'job_lifecycle',
          start_timestamp: to_nanoseconds(build.created_at),
          end_timestamp: to_nanoseconds(build.finished_at)
        )
      end

      it 'includes ci.job.status and ci.pipeline.source attributes' do
        expect(emitted_span.attributes).to include(
          'ci.job.status' => 'success',
          'ci.pipeline.source' => pipeline.source.to_s
        )
      end

      it 'uses a phantom pipeline parent span_id (no real pipeline root span exists)' do
        expected_phantom = OpenSSL::Digest::SHA256.hexdigest("pipeline:#{pipeline.id}")[0, 16]

        expect(emitted_span.parent_span_id.unpack1('H*')).to eq(expected_phantom)
      end
    end

    context 'when the build belongs to a child pipeline' do
      let_it_be(:bridge, freeze: true) { create(:ci_bridge, pipeline: pipeline) }
      let_it_be(:child_pipeline, freeze: true) { create(:ci_pipeline, source: :parent_pipeline, project: project) }
      let_it_be(:source_pipeline, freeze: true) do
        create(:ci_sources_pipeline, source_job: bridge, source_project: project,
          pipeline: child_pipeline, project: project)
      end

      let_it_be(:build, freeze: true) do
        create(:ci_build,
          pipeline: child_pipeline,
          created_at: 10.minutes.ago,
          finished_at: 5.minutes.ago)
      end

      before do
        emitter.emit_job_lifecycle(status: 'success')
      end

      it 'parents the lifecycle span under the bridge span' do
        expect(emitted_span.parent_span_id.unpack1('H*')).to eq(format('%016x', bridge.id))
      end
    end

    context 'when the build has no pipeline' do
      before do
        allow(build).to receive(:pipeline).and_return(nil)
        emitter.emit_job_lifecycle(status: 'success')
      end

      it 'falls back to phantom pipeline parent and uses pipeline_id for trace_id' do
        expected_phantom = OpenSSL::Digest::SHA256.hexdigest("pipeline:#{build.pipeline_id}")[0, 16]
        expected_trace_id = format('%032x', build.pipeline_id)

        expect(emitted_span.parent_span_id.unpack1('H*')).to eq(expected_phantom)
        expect(emitted_span.trace_id.unpack1('H*')).to eq(expected_trace_id)
        expect(emitted_span.attributes['ci.pipeline.source']).to eq('')
      end
    end
  end

  describe 'deterministic span IDs' do
    it 'emitted spans have span_ids matching span_id_for(kind)' do
      emitter.emit_job_pending
      emitter.emit_job_running
      emitter.emit_job_lifecycle(status: 'success')

      span_ids_by_name = exporter.finished_spans.to_h { |s| [s.name, s.span_id.unpack1('H*')] }

      expect(span_ids_by_name).to eq(
        'job_pending' => emitter.span_id_for(described_class::SPAN_KIND_PENDING),
        'job_running' => emitter.span_id_for(described_class::SPAN_KIND_RUNNING),
        'job_lifecycle' => emitter.span_id_for(described_class::SPAN_KIND_LIFECYCLE)
      )
    end

    it 'parent_span_ids correctly reference the lifecycle span_id' do
      emitter.emit_job_pending
      emitter.emit_job_running
      emitter.emit_job_lifecycle(status: 'success')

      lifecycle_span_id = emitter.span_id_for(described_class::SPAN_KIND_LIFECYCLE)
      pending_span = exporter.finished_spans.find { |s| s.name == 'job_pending' }
      running_span = exporter.finished_spans.find { |s| s.name == 'job_running' }

      expect(pending_span.parent_span_id.unpack1('H*')).to eq(lifecycle_span_id)
      expect(running_span.parent_span_id.unpack1('H*')).to eq(lifecycle_span_id)
    end
  end

  describe 'trace ID consistency across spans' do
    it 'all spans share the same trace ID' do
      emitter.emit_job_pending
      emitter.emit_job_running
      emitter.emit_job_lifecycle(status: 'success')

      trace_ids = exporter.finished_spans.map { |s| s.trace_id.unpack1('H*') }.uniq
      expect(trace_ids).to eq([emitter.trace_id])
    end
  end

  describe 'error handling' do
    before do
      allow(tracer).to receive(:start_span).and_raise(StandardError, 'boom')
      allow(Gitlab::ErrorTracking).to receive(:track_exception)
    end

    it 'rescues errors and tracks the exception without raising' do
      expect { emitter.emit_job_pending }.not_to raise_error

      expect(Gitlab::ErrorTracking).to have_received(:track_exception).with(
        instance_of(StandardError),
        hash_including(
          message: 'CI telemetry span emission failed',
          span_name: 'job_pending',
          job_id: build.id
        )
      )
    end
  end

  def to_nanoseconds(time)
    (time.to_i * 1_000_000_000) + time.nsec
  end
end
