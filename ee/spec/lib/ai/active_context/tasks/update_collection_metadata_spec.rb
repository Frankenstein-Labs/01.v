# frozen_string_literal: true

require 'spec_helper'
require_relative 'shared_examples'

RSpec.describe Ai::ActiveContext::Tasks::UpdateCollectionMetadata, feature_category: :code_suggestions do
  let(:default_params) do
    {
      'collection' => 'code',
      'metadata' => { 'key' => 'value' }
    }
  end

  it_behaves_like 'an active context task' do
    let(:required_params) { default_params }
  end

  describe '#execute!' do
    let(:task_record) { build(:ai_active_context_task, params: default_params) }
    let(:task) { described_class.new(task_record) }

    context 'when collection exists' do
      let(:collection) { create(:ai_active_context_collection) }

      before do
        allow(Ai::ActiveContext::Collection).to receive(:find_by_name).and_return(collection)
        allow(collection).to receive(:update_metadata!)
      end

      it 'updates the collection metadata' do
        task.execute!
        expect(collection).to have_received(:update_metadata!).with({ 'key' => 'value' })
      end
    end

    context 'when collection does not exist' do
      before do
        allow(Ai::ActiveContext::Collection).to receive(:find_by_name).and_return(nil)
      end

      it 'raises TaskError' do
        expect { task.execute! }.to raise_error(
          ::ActiveContext::Task::V1_0::TaskError, /Collection 'code' not found/
        )
      end
    end
  end
end
