# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AppConfig::CascadeBuiltInProjectTemplatesEnabledWorker, feature_category: :source_code_management do
  let(:worker) { described_class.new }
  let(:service) { instance_double(Namespaces::CascadeBuiltInProjectTemplatesEnabledService) }
  let(:limiter) { instance_double(Gitlab::Metrics::RuntimeLimiter) }

  let(:built_in_project_templates_enabled) { true }

  before do
    allow(Gitlab::Metrics::RuntimeLimiter).to receive(:new)
      .with(described_class::MAX_RUNTIME)
      .and_return(limiter)
    allow(Namespaces::CascadeBuiltInProjectTemplatesEnabledService).to receive(:new)
      .with(built_in_project_templates_enabled)
      .and_return(service)

    allow(described_class).to receive(:perform_in)
    allow(limiter).to receive(:was_over_time?).and_return(false)
  end

  describe '#perform' do
    subject(:perform) { worker.perform(built_in_project_templates_enabled) }

    context 'when the batch returns nil' do
      before do
        allow(service).to receive(:update_instance_batch).and_return(nil)
      end

      it 'does not enqueue another job' do
        expect(service).to receive(:update_instance_batch).with(cursor: 0)
        expect(described_class).not_to receive(:perform_in)

        perform
      end

      it 'logs metadata' do
        expect(worker).to receive(:log_extra_metadata_on_done).with(:result, {
          over_time: false,
          final_cursor: nil
        })

        perform
      end
    end

    context 'with time for multiple batches' do
      before do
        allow(service).to receive(:update_instance_batch).and_return(10, nil)
        allow(limiter).to receive(:over_time?).and_return(false)
      end

      it 'processes multiple batches in one run' do
        expect(service).to receive(:update_instance_batch).with(cursor: 0).ordered
        expect(service).to receive(:update_instance_batch).with(cursor: 10).ordered
        expect(described_class).not_to receive(:perform_in)

        perform
      end
    end

    context 'when over time' do
      before do
        allow(limiter).to receive_messages(over_time?: true, was_over_time?: true)
        allow(service).to receive(:update_instance_batch).and_return(10)
      end

      it 're-enqueues itself with the latest cursor' do
        expect(described_class).to receive(:perform_in)
          .with(described_class::RETRY_DELAY, built_in_project_templates_enabled, 10)

        perform
      end

      it 'logs metadata' do
        expect(worker).to receive(:log_extra_metadata_on_done).with(:result, {
          over_time: true,
          final_cursor: 10
        })

        perform
      end
    end

    context 'when a cursor is provided' do
      subject(:perform) { worker.perform(built_in_project_templates_enabled, 25) }

      before do
        allow(service).to receive(:update_instance_batch).and_return(nil)
      end

      it 'starts processing from that cursor' do
        expect(service).to receive(:update_instance_batch).with(cursor: 25)
        expect(described_class).not_to receive(:perform_in)

        perform
      end
    end

    context 'when over time after processing a batch' do
      before do
        allow(service).to receive(:update_instance_batch).and_return(10, 20)
        allow(limiter).to receive(:over_time?).and_return(false, true)
      end

      it 're-enqueues with the latest cursor' do
        expect(service).to receive(:update_instance_batch).with(cursor: 0).ordered
        expect(service).to receive(:update_instance_batch).with(cursor: 10).ordered
        expect(described_class).to receive(:perform_in)
          .with(described_class::RETRY_DELAY, built_in_project_templates_enabled, 20)

        perform
      end
    end
  end
end
