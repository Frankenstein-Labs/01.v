# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::BuildDependencyGraphWorker, feature_category: :dependency_management do
  let_it_be(:project) { create(:project) }

  it_behaves_like 'an idempotent worker' do
    let(:job_args) { [project.id] }
  end

  it_behaves_like 'worker with data consistency', described_class, data_consistency: :sticky

  describe 'worker configuration' do
    subject(:worker) { described_class }

    let(:number_of_retries) { worker.sidekiq_options["retry"] }
    let(:deduplication_strategy) { worker.get_deduplicate_strategy }
    let(:deduplication_settings) { worker.get_deduplication_options }

    it 'can be retried' do
      expect(worker.retry_disabled?).to be_falsey
      expect(number_of_retries).to eq(2)
    end

    context 'when the job raises' do
      let(:retries) { 1 }
      let(:retry_block) { worker.sidekiq_retry_in_block.call(retries, exception) }

      context 'on ActiveRecord::RecordInvalid' do
        let(:exception) { ActiveRecord::RecordInvalid.new }

        it 'gets discarded' do
          expect(retry_block).to eq(:discard)
        end
      end

      context 'on ActiveRecord::InvalidForeignKey' do
        let(:exception) { ActiveRecord::InvalidForeignKey.new }

        it 'gets discarded' do
          expect(retry_block).to eq(:discard)
        end
      end

      context 'on other exception' do
        let(:exception) { StandardError.new }

        it 'gets retried' do
          expect(retry_block).to eq(60)
        end
      end
    end

    it 'can be deduplicated' do
      expect(deduplication_strategy).to eq(:until_executed)
      expect(deduplication_settings).to include(if_deduplicated: :reschedule_once)
    end
  end

  describe '#perform' do
    subject(:run_worker) { described_class.new.perform(project.id) }

    before do
      allow(Sbom::BuildDependencyGraph).to receive(:execute)
    end

    context 'when there is no pipeline with the given ID' do
      subject(:perform) { described_class.new.perform(non_existing_record_id) }

      it 'does not raise an error' do
        expect { perform }.not_to raise_error
      end
    end

    it 'calls `Sbom::BuildDependencyGraph`' do
      run_worker

      expect(Sbom::BuildDependencyGraph).to have_received(:execute).with(project)
    end
  end
end
