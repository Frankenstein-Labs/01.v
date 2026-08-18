# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Code::IncrementalIndexingService, feature_category: :global_search do
  let_it_be(:collection) { create(:ai_active_context_collection) }
  let_it_be(:project) { create(:project) }
  let_it_be_with_reload(:repository) do
    create(
      :ai_active_context_code_repository,
      state: :ready,
      project: project,
      metadata: { initial_indexing_last_queued_item: 'hash0' }
    )
  end

  let(:logger) { instance_double(::Gitlab::ActiveContext::Logger, info: nil, error: nil) }

  before do
    allow(ActiveContext::CollectionCache).to receive(:fetch).and_return(collection)
    allow(::ActiveContext::Config).to receive(:logger).and_return(logger)
  end

  def build_log_payload(message, extra_params = {})
    {
      class_name: described_class.to_s,
      message: message,
      ai_active_context_code_repository_id: repository.id,
      project_id: project.id
    }.merge(extra_params).stringify_keys
  end

  describe '.execute' do
    subject(:execute) { described_class.execute(repository) }

    it 'calls the indexer with a block and tracks refs for each id as it processes' do
      expect(repository.state).to eq('ready')

      expect(Ai::ActiveContext::Code::Indexer).to receive(:run!) do |repo, &block|
        expect(repo).to eq(repository)
        block.call('hash1')
        block.call('hash2')
      end

      expect(::Ai::ActiveContext::Collections::Code).to receive(:track_refs!)
                                                          .with(hashes: ['hash1'], routing: repository.project_id)
      expect(::Ai::ActiveContext::Collections::Code).to receive(:track_refs!)
                                                          .with(hashes: ['hash2'], routing: repository.project_id)

      expect(logger).to receive(:info).with(
        build_log_payload('incremental_indexing_last_queued_item', incremental_indexing_last_queued_item: 'hash2')
      ).ordered

      execute

      expect(repository.state).to eq('ready')
      expect(repository.incremental_indexing_last_queued_item).to eq('hash2')
      expect(repository.initial_indexing_last_queued_item).to eq('hash0')
    end

    context 'when indexing fails' do
      let(:error) { StandardError.new('Indexing failed') }

      before do
        allow(Ai::ActiveContext::Code::Indexer).to receive(:run!).and_raise(error)
      end

      it 'sets the repository to failed and passes the error on' do
        expect(logger).to receive(:error).with(
          build_log_payload('incremental indexing failed', last_error: error.message)
        )

        expect { execute }.to raise_error(error)

        expect(repository.state).to eq('ready')
        expect(repository.last_error).to eq(error.message)
      end
    end
  end
end
