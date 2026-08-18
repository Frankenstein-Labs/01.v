# frozen_string_literal: true

require 'spec_helper'
require_relative 'shared_examples'

RSpec.describe Ai::ActiveContext::Tasks::NullifyField, feature_category: :code_suggestions do
  let(:default_params) do
    {
      'collection' => 'code',
      'field' => 'embeddings_v1'
    }
  end

  it_behaves_like 'a batched active context task' do
    let(:required_params) { default_params }
  end

  describe '#execute!' do
    let(:task_record) { build(:ai_active_context_task, params: default_params) }
    let(:task) { described_class.new(task_record) }

    it 'calls nullify_field with collection name and field name' do
      expect(task).to receive(:nullify_field).with('code', 'embeddings_v1', batch_size: 10_000)
      task.execute!
    end

    it 'uses DEFAULT_BATCH_SIZE of 10_000' do
      expect(described_class::DEFAULT_BATCH_SIZE).to eq(10_000)
    end

    it 'uses custom batch_size from params' do
      custom_params = default_params.merge('batch_size' => '500')
      task_record = build(:ai_active_context_task, params: custom_params)
      task = described_class.new(task_record)

      expect(task).to receive(:nullify_field).with('code', 'embeddings_v1', batch_size: 500)
      task.execute!
    end
  end

  describe '#completed?' do
    let(:task_record) { build(:ai_active_context_task, params: default_params) }
    let(:task) { described_class.new(task_record) }

    it 'returns true when there are no documents with the field' do
      allow(task).to receive(:any_documents_with_field?).and_return(false)

      expect(task.completed?).to be true
    end

    it 'returns false when there are documents with the field' do
      allow(task).to receive(:any_documents_with_field?).and_return(true)

      expect(task.completed?).to be false
    end
  end

  describe 'private helpers' do
    let(:task_record) { build(:ai_active_context_task, params: default_params) }
    let(:task) { described_class.new(task_record) }

    it 'returns the field name from params' do
      expect(task.send(:field_name)).to eq('embeddings_v1')
    end

    it 'checks for documents with the field via the collection search' do
      mock_query = instance_double(::ActiveContext::Query)
      allow(::ActiveContext::Query).to receive(:exists).and_return(mock_query)
      allow(mock_query).to receive(:limit).and_return(mock_query)
      allow(Ai::ActiveContext::Collections::Code).to receive(:search).with(user: nil,
        query: mock_query).and_return([1])

      expect(task.send(:any_documents_with_field?)).to be true
      expect(::ActiveContext::Query).to have_received(:exists)
      expect(mock_query).to have_received(:limit).with(1)
      expect(Ai::ActiveContext::Collections::Code).to have_received(:search).with(user: nil, query: mock_query)
    end
  end
end
