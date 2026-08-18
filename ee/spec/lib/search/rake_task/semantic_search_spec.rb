# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::RakeTask::SemanticSearch, :silence_stdout, feature_category: :global_search do
  let(:task_executor_service) { instance_double(Search::SemanticSearch::RakeTaskExecutorService) }

  before do
    allow(described_class).to receive(:task_executor_service).and_return(task_executor_service)
    allow(task_executor_service).to receive(:execute)
    allow(described_class).to receive(:clear_screen)
    allow(described_class).to receive(:sleep)
    allow(described_class).to receive(:puts)
  end

  describe '.info' do
    before do
      allow(described_class).to receive(:run_with_interval).and_call_original
      allow(described_class).to receive(:loop) do |&block|
        block.call
        raise Interrupt
      end
    end

    it 'executes the info task' do
      expect(task_executor_service).to receive(:execute).with(:info)

      described_class.info(name: 'test')
    end

    it 'does not enter the loop when watch_interval is nil' do
      expect(described_class).not_to receive(:loop)

      described_class.info(name: 'test', watch_interval: nil)
    end

    it 'does not enter the loop when watch_interval is zero' do
      expect(described_class).not_to receive(:loop)

      described_class.info(name: 'test', watch_interval: '0')
    end

    it 'does not enter the loop when watch_interval is negative' do
      expect(described_class).not_to receive(:loop)

      described_class.info(name: 'test', watch_interval: '-1')
    end

    it 'enters the loop when watch_interval is positive' do
      expect(described_class).to receive(:loop)

      described_class.info(name: 'test', watch_interval: '5')
    end

    it 'clears the screen on each iteration' do
      expect(described_class).to receive(:clear_screen).once

      described_class.info(name: 'test', watch_interval: '5')
    end
  end

  describe '.task_executor_service' do
    before do
      allow(described_class).to receive(:task_executor_service).and_call_original
    end

    it 'returns a Search::SemanticSearch::RakeTaskExecutorService instance' do
      expect(described_class.send(:task_executor_service)).to be_a(Search::SemanticSearch::RakeTaskExecutorService)
    end
  end
end
