# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Zoekt::MetricsUpdateCronWorker, feature_category: :global_search do
  before do
    stub_ee_application_setting(zoekt_indexing_enabled: true)
  end

  it_behaves_like 'worker with data consistency', described_class, data_consistency: :sticky

  it 'is not a pause_control worker' do
    expect(described_class.get_pause_control).not_to eq(:zoekt)
  end

  describe '#perform' do
    subject(:worker) { described_class.new }

    context 'when no arguments are provided' do
      it_behaves_like 'an idempotent worker' do
        it 'calls the worker with each supported metrics' do
          Search::Zoekt::MetricsService::METRICS.each do |metric|
            expect(described_class).to receive(:perform_async).with(metric.to_s)
          end

          worker.perform
        end

        context 'when zoekt_indexing_enabled is false' do
          before do
            stub_ee_application_setting(zoekt_indexing_enabled: false)
          end

          it 'does not call the service' do
            expect(described_class).not_to receive(:perform_async)

            worker.perform
          end
        end

        context 'when license check for zoekt_code_search is false' do
          before do
            stub_licensed_features(zoekt_code_search: false)
          end

          it 'does not call the service' do
            expect(described_class).not_to receive(:perform_async)

            worker.perform
          end
        end
      end
    end

    context 'when metric is provided' do
      let(:metric) { :node_metrics }

      it_behaves_like 'an idempotent worker' do
        it 'calls the service with the metric' do
          expect(Search::Zoekt::MetricsService).to receive(:execute).with(metric.to_s)

          worker.perform(metric)
        end

        context 'when zoekt_indexing_enabled is false' do
          before do
            stub_ee_application_setting(zoekt_indexing_enabled: false)
          end

          it 'does not call the service' do
            expect(Search::Zoekt::MetricsService).not_to receive(:execute)

            worker.perform
          end
        end

        context 'when license check for zoekt_code_search is false' do
          before do
            stub_licensed_features(zoekt_code_search: false)
          end

          it 'does not call the service' do
            expect(described_class).not_to receive(:perform_async)

            worker.perform
          end
        end
      end
    end
  end
end
