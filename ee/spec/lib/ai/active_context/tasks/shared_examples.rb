# frozen_string_literal: true

RSpec.shared_examples 'an active context task' do
  let(:task_with_required_params) { build(:ai_active_context_task, params: required_params) }

  describe 'task initialization and validation' do
    describe '#required_params' do
      subject(:task) { described_class.new(task_with_required_params) }

      it 'returns an array of required parameter names' do
        expect(task.required_params).to be_a(Array)
        expect(task.required_params).to all(be_a(String))
      end
    end

    describe 'parameter validation' do
      context 'when all required params are provided' do
        it 'initializes without error' do
          expect { described_class.new(task_with_required_params) }.not_to raise_error
        end
      end

      context 'when required params are missing' do
        let(:task_record) { build(:ai_active_context_task, params: {}) }

        it 'raises MissingParamError' do
          expect { described_class.new(task_record) }.to raise_error(
            ::ActiveContext::Task::V1_0::MissingParamError
          )
        end
      end
    end

    describe '#execute!' do
      subject(:task) { described_class.new(task_with_required_params) }

      it 'is defined' do
        expect(task).to respond_to(:execute!)
      end
    end
  end
end

RSpec.shared_examples 'a batched active context task' do
  include_examples 'an active context task'

  describe 'batched status' do
    it 'is marked as batched' do
      expect(described_class.batched?).to be true
    end
  end
end
