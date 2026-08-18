# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Zoekt::HealthCheck::ConfigurationService, :silence_stdout, feature_category: :global_search do
  let(:logger) { instance_double(Logger) }
  let(:service) { described_class.new(logger: logger) }
  let(:application_setting) { instance_double(ApplicationSetting) }

  before do
    allow(logger).to receive(:info)
    allow(ApplicationSetting).to receive(:current).and_return(application_setting)

    # Set up default "good state" - all features enabled, healthy configuration
    allow(application_setting).to receive_messages(
      zoekt_indexing_enabled?: true,
      zoekt_search_enabled?: true,
      zoekt_indexing_paused?: false
    )
    allow(Search::Zoekt::EnabledNamespace).to receive_messages(
      count: 5,
      with_missing_indices: instance_double(ActiveRecord::Relation, count: 0),
      search_disabled: instance_double(ActiveRecord::Relation, count: 0)
    )
    allow(Search::Zoekt::Repository).to receive_messages(count: 10)
    ready_relation = instance_double(ActiveRecord::Relation)
    allow(Search::Zoekt::Repository).to receive(:ready).and_return(ready_relation)
    allow(ready_relation).to receive(:count).and_return(10)
  end

  describe '#execute' do
    it 'logs a blank line and the section header', :aggregate_failures do
      expect(logger).to receive(:info).with("").ordered
      expect(logger).to receive(:info).with(include('Configuration:')).ordered

      service.execute
    end

    context 'when indexing is disabled' do
      before do
        allow(application_setting).to receive(:zoekt_indexing_enabled?).and_return(false)
      end

      it 'returns unhealthy status with indexing error' do
        result = service.execute

        expect(result[:status]).to eq(:unhealthy)
        expect(result[:errors]).to include(
          'Enable indexing in Admin > Settings > Search > Exact code search'
        )
      end

      it 'logs indexing disabled error' do
        expect(logger).to receive(:info).with(include('✗ Indexing disabled'))

        service.execute
      end
    end

    context 'when searching is disabled' do
      before do
        allow(application_setting).to receive(:zoekt_search_enabled?).and_return(false)
      end

      it 'returns degraded status with searching warning' do
        result = service.execute

        expect(result[:status]).to eq(:degraded)
        expect(result[:warnings]).to include(
          'Enable searching in Admin > Settings > Search > Exact code search'
        )
      end

      it 'logs searching disabled warning' do
        expect(logger).to receive(:info).with(include('⚠ Searching disabled'))

        service.execute
      end
    end

    context 'when indexing is paused' do
      before do
        allow(application_setting).to receive(:zoekt_indexing_paused?).and_return(true)
      end

      it 'returns degraded status with pause warning' do
        result = service.execute

        expect(result[:status]).to eq(:degraded)
        expect(result[:warnings]).to include(
          'Unpause indexing in Admin > Settings > Search > Exact code search'
        )
      end

      it 'logs indexing paused warning' do
        expect(logger).to receive(:info).with(include('⚠ Indexing paused'))

        service.execute
      end
    end

    context 'when no namespaces are enabled' do
      before do
        allow(Search::Zoekt::EnabledNamespace).to receive(:count).and_return(0)
      end

      it 'returns degraded status with namespace warning' do
        result = service.execute

        expect(result[:status]).to eq(:degraded)
        expect(result[:warnings]).to include(
          'Enable namespaces for indexing or set auto-index root namespaces in Admin settings'
        )
      end

      it 'logs no namespaces enabled warning' do
        expect(logger).to receive(:info).with(include('⚠ 0 namespaces enabled for indexing'))

        service.execute
      end
    end

    context 'when namespaces have missing indices' do
      before do
        allow(Search::Zoekt::EnabledNamespace).to receive_messages(
          count: 10,
          with_missing_indices: instance_double(ActiveRecord::Relation, count: 3)
        )
      end

      it 'returns degraded status with missing indices warning' do
        result = service.execute

        expect(result[:status]).to eq(:degraded)
        expect(result[:warnings]).to include(
          'Wait for indexing to complete or check for indexing errors on 3 namespaces'
        )
      end

      it 'logs missing indices warning' do
        expect(logger).to receive(:info).with(include('⚠ 3 namespaces without indices'))

        service.execute
      end
    end

    context 'when namespaces have search disabled' do
      before do
        allow(Search::Zoekt::EnabledNamespace).to receive_messages(
          count: 10,
          search_disabled: instance_double(ActiveRecord::Relation, count: 2)
        )
      end

      it 'returns degraded status with search disabled warning' do
        result = service.execute

        expect(result[:status]).to eq(:degraded)
        expect(result[:warnings]).to include('Enable search on 2 namespaces in group settings')
      end

      it 'logs search disabled warning' do
        expect(logger).to receive(:info).with(include('⚠ 2 namespaces with search disabled'))

        service.execute
      end
    end

    context 'when repository indexing is incomplete' do
      before do
        allow(Search::Zoekt::Repository).to receive_messages(count: 100)
        ready_relation = instance_double(ActiveRecord::Relation)
        allow(Search::Zoekt::Repository).to receive(:ready).and_return(ready_relation)
        allow(ready_relation).to receive(:count).and_return(40)
      end

      it 'returns unhealthy status when less than 50% indexed' do
        result = service.execute

        expect(result[:status]).to eq(:unhealthy)
        expect(result[:errors]).to include('Check indexing logs and resolve errors - only 40.0% repositories indexed')
      end

      it 'logs low repository indexing rate' do
        expect(logger).to receive(:info).with(include('✗ 40/100 repositories ready (40.0%)'))

        service.execute
      end
    end

    context 'when repository indexing is in progress' do
      before do
        allow(Search::Zoekt::Repository).to receive_messages(count: 100)
        ready_relation = instance_double(ActiveRecord::Relation)
        allow(Search::Zoekt::Repository).to receive(:ready).and_return(ready_relation)
        allow(ready_relation).to receive(:count).and_return(70)
      end

      it 'returns degraded status when 50-80% indexed' do
        result = service.execute

        expect(result[:status]).to eq(:degraded)
        expect(result[:warnings]).to include('Wait for indexing completion - 70.0% repositories indexed')
      end

      it 'logs repository indexing in progress' do
        expect(logger).to receive(:info).with(include('⚠ 70/100 repositories ready (70.0%)'))

        service.execute
      end
    end

    context 'when all configuration is healthy' do
      before do
        allow(Search::Zoekt::EnabledNamespace).to receive(:count).and_return(8)
        allow(Search::Zoekt::Repository).to receive_messages(count: 12)
        ready_relation = instance_double(ActiveRecord::Relation)
        allow(Search::Zoekt::Repository).to receive(:ready).and_return(ready_relation)
        allow(ready_relation).to receive(:count).and_return(12)
      end

      it 'returns healthy status' do
        result = service.execute

        expect(result[:status]).to eq(:healthy)
        expect(result[:errors]).to be_empty
        expect(result[:warnings]).to be_empty
      end

      it 'logs all healthy checks' do
        expect(logger).to receive(:info).with(include('✓ Indexing enabled'))
        expect(logger).to receive(:info).with(include('✓ Searching enabled'))
        expect(logger).to receive(:info).with(include('✓ Indexing active'))
        expect(logger).to receive(:info).with(include('✓ 8 namespaces enabled for indexing'))
        expect(logger).to receive(:info).with(include('✓ All namespaces have indices'))
        expect(logger).to receive(:info).with(include('✓ All namespaces have search enabled'))
        expect(logger).to receive(:info).with(include('✓ 12/12 repositories ready (100.0%)'))

        service.execute
      end
    end

    context 'when no repositories exist' do
      before do
        allow(Search::Zoekt::Repository).to receive(:count).and_return(0)
      end

      it 'returns healthy status and skips repository check' do
        result = service.execute

        expect(result[:status]).to eq(:healthy)
        expect(result[:errors]).to be_empty
        expect(result[:warnings]).to be_empty
      end
    end
  end

  describe '.execute' do
    it 'creates instance and calls execute' do
      # Using default healthy state from setup
      expect(described_class).to receive(:new).with(logger: logger).and_call_original

      described_class.execute(logger: logger)
    end
  end
end
