# frozen_string_literal: true

require 'spec_helper'
require_relative 'shared_examples'

RSpec.describe Ai::ActiveContext::Tasks::AddEmbeddingsField, feature_category: :code_suggestions do
  let(:default_params) do
    {
      'collection' => 'code',
      'field' => 'embeddings_v2',
      'dimensions' => 1536
    }
  end

  it_behaves_like 'an active context task' do
    let(:required_params) { default_params }
  end

  describe '#execute!' do
    let(:task_record) { build(:ai_active_context_task, params: default_params) }
    let(:task) { described_class.new(task_record) }

    it 'calls add_field with the collection name and passes field name and dimensions to the block' do
      mock_collection = instance_double(ActiveContext::Databases::CollectionBuilder, vector: nil)

      expect(task).to receive(:add_field).with('code').and_yield(mock_collection)
      task.execute!
      expect(mock_collection).to have_received(:vector).with('embeddings_v2', dimensions: 1536)
    end
  end
end
