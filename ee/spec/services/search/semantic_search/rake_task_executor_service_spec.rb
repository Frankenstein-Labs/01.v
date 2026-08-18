# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::SemanticSearch::RakeTaskExecutorService, :silence_stdout, feature_category: :global_search do
  let(:logger) { instance_double(Logger) }
  let(:service) { described_class.new(logger: logger) }

  before do
    allow(logger).to receive(:info)
    allow(logger).to receive(:warn)
    allow(logger).to receive(:error)
  end

  describe '#execute' do
    it 'raises ArgumentError when unknown task is provided' do
      expect { service.execute(:foo) }.to raise_error(ArgumentError, "Unknown task: foo")
    end

    it 'executes info task' do
      expect(service).to receive(:info)

      service.execute(:info)
    end
  end

  describe '#info' do
    let(:connection) do
      instance_double(Ai::ActiveContext::Connection, name: 'postgres', adapter_class: 'PostgreSQL', active: true)
    end

    let(:repos) { class_double(Ai::ActiveContext::Code::Repository) }
    let(:code_queue) { class_double(Ai::ActiveContext::Queues::Code) }
    let(:backfill_queue) { class_double(Ai::ActiveContext::Queues::CodeBackfill) }
    let(:retry_queue) { class_double(ActiveContext::RetryQueue) }
    let(:dead_queue) { class_double(ActiveContext::DeadQueue) }

    before do
      allow(ActiveContext::Config).to receive(:indexing_enabled?).and_return(true)
      allow(Ai::ActiveContext::Collections::Code).to receive(:indexing?).and_return(true)
      allow(Ai::ActiveContext::Connection).to receive(:active).and_return(connection)
      allow(Ai::ActiveContext::Code::Repository).to receive_messages(count: 10, ready: repos, pending: repos,
        code_indexing_in_progress: repos, embedding_indexing_in_progress: repos, failed: repos)
      allow(repos).to receive(:count).and_return(5, 2, 1, 1, 1)
      allow(Ai::ActiveContext::Queues::Code).to receive_messages(queue_size: 100, number_of_shards: 4,
        shard_limit: 1000)
      allow(Ai::ActiveContext::Queues::CodeBackfill).to receive_messages(queue_size: 50, number_of_shards: 2,
        shard_limit: 500)
      allow(ActiveContext::RetryQueue).to receive(:queue_size).and_return(10)
      allow(ActiveContext::DeadQueue).to receive(:queue_size).and_return(5)
    end

    it 'displays indexing status' do
      expect(logger).to receive(:info).with(/Indexing enabled/)
      expect(logger).to receive(:info).with(/Indexing active/)

      service.execute(:info)
    end

    it 'displays connection info when connection exists' do
      expect(logger).to receive(:info).with(/Connection:/)
      expect(logger).to receive(:info).with(/Name:.*postgres/)
      expect(logger).to receive(:info).with(/Adapter:.*PostgreSQL/)

      service.execute(:info)
    end

    it 'displays repository stats with percentages' do
      expect(logger).to receive(:info).with(/Repositories/)
      expect(logger).to receive(:info).with(/Total:.*10/)
      expect(logger).to receive(:info).with(/Ready:.*5.*\(50%\)/)
      expect(logger).to receive(:info).with(/Pending:.*2.*\(20%\)/)

      service.execute(:info)
    end

    it 'displays embedding queue stats with processing note' do
      expect(logger).to receive(:info).with(/Embedding Queues/)
      expect(logger).to receive(:info).with(/Code queue:.*100/)
      expect(logger).to receive(:info).with(/Backfill queue:.*50/)
      expect(logger).to receive(:info).with(/Retry queue:.*10/)
      expect(logger).to receive(:info).with(/Dead queue:.*5/)
      expect(logger).to receive(:info).with(/Note: Queue is processed every 1 minute \(up to \d+ items at once\)/)

      service.execute(:info)
    end

    context 'when indexing is disabled' do
      before do
        allow(ActiveContext::Config).to receive(:indexing_enabled?).and_return(false)
        allow(Ai::ActiveContext::Collections::Code).to receive(:indexing?).and_return(false)
      end

      it 'displays indexing as disabled' do
        expect(logger).to receive(:info).with(/Indexing enabled.*no/)
        expect(logger).to receive(:info).with(/Indexing active.*no/)

        service.execute(:info)
      end
    end

    context 'when connection exists but is inactive' do
      let(:connection) do
        instance_double(Ai::ActiveContext::Connection, name: 'postgres', adapter_class: 'PostgreSQL', active: false)
      end

      it 'displays active as no' do
        expect(logger).to receive(:info).with(/Active:.*no/)

        service.execute(:info)
      end
    end

    context 'when no connection exists' do
      before do
        allow(Ai::ActiveContext::Connection).to receive(:active).and_return(nil)
      end

      it 'displays warning message' do
        expect(logger).to receive(:warn).with(/None configured/)

        service.execute(:info)
      end
    end
  end

  describe '#safely' do
    it 'logs the error message in red when a StandardError is raised inside the section' do
      error = StandardError.new('something went wrong')
      allow(service).to receive(:display_indexing_status).and_raise(error)
      allow(service).to receive(:display_connection_info)
      allow(service).to receive(:display_repository_stats)
      allow(service).to receive(:display_embedding_queue_stats)

      expect(logger).to receive(:error).with(Rainbow("\nIndexing Status: error - something went wrong").red)

      service.execute(:info)
    end

    it 'continues executing remaining sections after one section raises' do
      allow(service).to receive(:display_indexing_status).and_raise(StandardError, 'boom')

      expect(service).to receive(:display_connection_info)
      expect(service).to receive(:display_repository_stats)
      expect(service).to receive(:display_embedding_queue_stats)

      service.execute(:info)
    end
  end
end
