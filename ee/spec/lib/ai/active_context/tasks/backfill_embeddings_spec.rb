# frozen_string_literal: true

require 'spec_helper'
require_relative 'shared_examples'

RSpec.describe Ai::ActiveContext::Tasks::BackfillEmbeddings, feature_category: :code_suggestions do
  let(:default_params) do
    {
      'collection' => 'code',
      'field' => 'embeddings_v2'
    }
  end

  it_behaves_like 'a batched active context task' do
    let(:required_params) { default_params }
  end

  describe '#execute!' do
    let(:task_record) { build(:ai_active_context_task, params: default_params) }
    let(:task) { described_class.new(task_record) }
    let(:mock_docs) do
      [
        { 'id' => 'doc1', 'project_id' => 'project1' },
        { 'id' => 'doc2', 'project_id' => 'project2' }
      ]
    end

    it 'searches for missing documents up to batch size' do
      allow(task).to receive(:search_for_missing_docs).and_return(mock_docs)
      allow(Ai::ActiveContext::Collections::Code).to receive(:track!)
      task.execute!
      expect(task).to have_received(:search_for_missing_docs).with(limit: 1000)
    end

    it 'tracks documents with the backfill queue' do
      allow(task).to receive(:search_for_missing_docs).and_return(mock_docs)
      allow(Ai::ActiveContext::Collections::Code).to receive(:track!)
      task.execute!
      expect(Ai::ActiveContext::Collections::Code).to have_received(:track!).with(
        [
          { id: 'doc1', routing: 'project1' },
          { id: 'doc2', routing: 'project2' }
        ],
        queue: Ai::ActiveContext::Queues::CodeBackfill
      )
    end

    it 'uses DEFAULT_BATCH_SIZE of 1000' do
      expect(described_class::DEFAULT_BATCH_SIZE).to eq(1000)
    end

    it 'uses custom batch_size from params' do
      custom_params = default_params.merge('batch_size' => '500')
      task_record = build(:ai_active_context_task, params: custom_params)
      task = described_class.new(task_record)

      allow(task).to receive(:search_for_missing_docs).and_return(mock_docs)
      allow(Ai::ActiveContext::Collections::Code).to receive(:track!)
      task.execute!
      expect(task).to have_received(:search_for_missing_docs).with(limit: 500)
    end
  end

  describe '#completed?' do
    let(:task_record) { build(:ai_active_context_task, params: default_params) }
    let(:task) { described_class.new(task_record) }

    it 'returns true when backfill queue is empty and there are no missing documents' do
      stub_const('Ai::ActiveContext::Queues::CodeBackfill',
        class_double(Ai::ActiveContext::Queues::CodeBackfill, queue_size: 0))
      allow(task).to receive(:search_for_missing_docs).and_return([])

      expect(task.completed?).to be true
    end

    it 'returns false when backfill queue is not empty or there are missing documents' do
      stub_const('Ai::ActiveContext::Queues::CodeBackfill',
        class_double(Ai::ActiveContext::Queues::CodeBackfill, queue_size: 1))
      allow(task).to receive(:search_for_missing_docs).and_return([])

      expect(task.completed?).to be false

      # also when there are missing documents
      stub_const('Ai::ActiveContext::Queues::CodeBackfill',
        class_double(Ai::ActiveContext::Queues::CodeBackfill, queue_size: 0))
      allow(task).to receive(:search_for_missing_docs).and_return([{ 'id' => 'doc' }])

      expect(task.completed?).to be false
    end
  end

  describe 'private helpers' do
    let(:task_record) { build(:ai_active_context_task, params: default_params) }
    let(:task) { described_class.new(task_record) }

    it 'returns the field name from params' do
      expect(task.send(:field_name)).to eq('embeddings_v2')
    end

    it 'uses the collection backfill queue' do
      expect(task.send(:queue)).to eq(Ai::ActiveContext::Queues::CodeBackfill)
    end

    it 'searches the collection for missing documents using the query builder' do
      mock_query = instance_double(::ActiveContext::Query)
      allow(::ActiveContext::Query).to receive(:missing).and_return(mock_query)
      allow(mock_query).to receive(:limit).and_return(mock_query)
      allow(Ai::ActiveContext::Collections::Code).to receive(:search).with(user: nil,
        query: mock_query).and_return([{ 'id' => 'doc' }])

      result = task.send(:search_for_missing_docs, limit: 5)

      expect(::ActiveContext::Query).to have_received(:missing)
      expect(mock_query).to have_received(:limit).with(5)
      expect(Ai::ActiveContext::Collections::Code).to have_received(:search).with(user: nil, query: mock_query)
      expect(result).to be_an(Array)
    end
  end
end
