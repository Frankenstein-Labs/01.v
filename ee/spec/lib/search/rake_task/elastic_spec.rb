# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::RakeTask::Elastic, feature_category: :global_search do
  describe '.validate_index_and_search' do
    let(:logger) { instance_double(Logger) }
    let(:service) { instance_double(Search::RakeTaskExecutorService) }

    before do
      allow(Search::RakeTaskExecutorService).to receive(:new).with(logger: logger).and_return(service)
      allow(described_class).to receive(:stdout_logger).and_return(logger)
    end

    it 'creates a task executor service with stdout logger' do
      expect(Search::RakeTaskExecutorService).to receive(:new).with(logger: logger)
      expect(service).to receive(:execute).with(:index_and_search_validation)

      described_class.validate_index_and_search
    end

    it 'executes the index_and_search_validation task' do
      expect(service).to receive(:execute).with(:index_and_search_validation)

      described_class.validate_index_and_search
    end
  end

  describe '.task_executor_service' do
    it 'returns a RakeTaskExecutorService instance with stdout logger' do
      service_instance = described_class.task_executor_service

      expect(service_instance).to be_a(Search::RakeTaskExecutorService)
    end
  end

  describe '.stdout_logger' do
    it 'returns a Logger instance configured for stdout' do
      logger_instance = described_class.stdout_logger

      expect(logger_instance).to be_a(Logger)
    end

    it 'caches the logger instance' do
      logger1 = described_class.stdout_logger
      logger2 = described_class.stdout_logger

      expect(logger1).to be(logger2)
    end

    it 'configures a custom formatter' do
      logger_instance = described_class.stdout_logger

      expect(logger_instance.formatter).to be_a(Proc)
    end
  end
end
