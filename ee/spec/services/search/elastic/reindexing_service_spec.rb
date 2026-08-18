# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Elastic::ReindexingService, feature_category: :global_search do
  describe '.execute' do
    subject(:service) { described_class.new(delay: delay) }

    let(:delay) { 1.minute }

    it 'instanciates the service and executes it' do
      expect(described_class).to receive(:new).with(delay: delay).and_return(service)
      expect(service).to receive(:execute)

      described_class.execute(delay: delay)
    end
  end

  describe '#execute' do
    context 'when limited indexing is enabled' do
      before do
        stub_ee_application_setting(elasticsearch_limit_indexing?: true)
      end

      subject(:service) { described_class.new }

      it 'schedules indexing for the instance without skipping projects' do
        expect(Search::Elastic::TriggerIndexingWorker).to receive(:perform_in).with(
          0, Search::Elastic::TriggerIndexingWorker::INITIAL_TASK.to_s, { 'skip' => [] }
        )

        service.execute
      end
    end

    context 'when delay is not set' do
      subject(:service) { described_class.new }

      it 'schedules indexing for the instance without delay' do
        expect(Search::Elastic::TriggerIndexingWorker).to receive(:perform_in).with(
          0, Search::Elastic::TriggerIndexingWorker::INITIAL_TASK.to_s, described_class::DEFAULT_OPTIONS
        )

        service.execute
      end
    end

    context 'when delay is set' do
      subject(:service) { described_class.new(delay: delay) }

      let(:delay) { 1.minute }

      it 'schedules indexing for the instance without delay' do
        expect(Search::Elastic::TriggerIndexingWorker).to receive(:perform_in).with(
          delay, Search::Elastic::TriggerIndexingWorker::INITIAL_TASK.to_s, described_class::DEFAULT_OPTIONS
        )

        service.execute
      end
    end
  end
end
