# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Code::SchedulingWorker, feature_category: :global_search do
  let(:tasks) do
    { example_task: { dispatch: { event: TestEvent } }, another_task: { dispatch: { event: TestEvent } } }
  end

  let(:event_class) do
    Class.new(::Gitlab::EventStore::Event) do
      def schema
        {
          'type' => 'object',
          'properties' => {},
          'additionalProperties' => false
        }
      end
    end
  end

  before do
    stub_const('TestEvent', event_class)
    stub_const('Ai::ActiveContext::Code::SchedulingService::TASKS', tasks)
    allow(Ai::ActiveContext::Code::SchedulingService).to receive(:execute).with(any_args).and_return(true)
  end

  it_behaves_like 'worker with data consistency', described_class, data_consistency: :sticky

  it_behaves_like 'active_context pause-controlled worker' do
    let(:worker_params) { [] }
  end

  describe '#perform' do
    let(:worker) { described_class.new }

    context 'when indexing is disabled' do
      before do
        allow(::Ai::ActiveContext::Collections::Code).to receive(:indexing?).and_return(false)
      end

      it 'returns false without further execution' do
        expect(worker.perform).to be false
        expect(Ai::ActiveContext::Code::SchedulingService).not_to receive(:execute)
        expect(worker).not_to receive(:initiate)
      end
    end

    context 'when indexing is enabled' do
      before do
        allow(::Ai::ActiveContext::Collections::Code).to receive(:indexing?).and_return(true)
      end

      context 'when no task is provided' do
        it_behaves_like 'an idempotent worker' do
          before do
            allow(worker).to receive(:with_context)
          end

          it 'calls initiate and enqueues jobs for each task' do
            expect(worker).to receive(:initiate)
            expect(worker.perform).to be_nil
          end
        end

        it 'enqueues a job for each task' do
          expect(worker).to receive(:with_context).twice.and_yield
          expect(described_class).to receive(:perform_async).with('example_task')
          expect(described_class).to receive(:perform_async).with('another_task')

          worker.perform
        end
      end

      context 'when a specific task is provided' do
        let(:task) { 'example_task' }

        it_behaves_like 'an idempotent worker' do
          let(:job_args) { ['example_task'] }

          it 'calls the service to execute the task' do
            expect(Ai::ActiveContext::Code::SchedulingService).to receive(:execute).with('example_task')

            worker.perform(task)
          end
        end

        it 'executes the specified task' do
          expect(Ai::ActiveContext::Code::SchedulingService).to receive(:execute).with(task)

          worker.perform(task)
        end
      end
    end
  end
end
