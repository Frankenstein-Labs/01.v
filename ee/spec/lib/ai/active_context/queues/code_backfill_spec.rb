# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Queues::CodeBackfill, feature_category: :code_suggestions do
  before do
    allow(::ActiveContext).to receive_message_chain(:adapter, :full_collection_name)
      .and_return(ActiveContextHelpers.code_collection_name)
  end

  describe 'inheritance' do
    it 'inherits from Code queue' do
      expect(described_class).to be < Ai::ActiveContext::Queues::Code
    end
  end

  describe '.preprocess_options' do
    it 'returns queue_name and next_model_only option set to true' do
      expect(described_class.preprocess_options).to eq({
        queue_name: 'code_backfill',
        next_model_only: true
      })
    end
  end

  describe '.extra_preprocess_options' do
    it 'returns next_model_only option set to true' do
      expect(described_class.extra_preprocess_options).to eq({ next_model_only: true })
    end
  end

  describe 'queue processing properties' do
    it 'returns default values' do
      expect(described_class.number_of_shards).to eq(1)
      expect(described_class.shard_limit).to eq(1000)
    end

    context 'when a Code collection record exists' do
      let_it_be_with_reload(:collection) { create(:ai_active_context_collection, :code_collection) }

      it 'returns default values' do
        expect(described_class.number_of_shards).to eq(1)
        expect(described_class.shard_limit).to eq(1000)
      end

      context 'when the collection queue-related options are set' do
        before do
          collection.update!(
            options: {
              queue_shard_count: 4,
              queue_shard_limit: 250
            }
          )
        end

        it 'returns the values defined in the collection options' do
          expect(described_class.number_of_shards).to eq(4)
          expect(described_class.shard_limit).to eq(250)
        end
      end
    end
  end

  describe '.queues' do
    it 'includes the code backfill queue' do
      expect(ActiveContext::Queues.queues).to include('ai_activecontext_queues:{code_backfill}')
    end
  end
end
