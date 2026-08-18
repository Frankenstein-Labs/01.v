# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::TaskFailedEventWorker, :zoekt_settings_enabled, feature_category: :global_search do
  let(:event) { Search::Zoekt::TaskFailedEvent.new(data: data) }
  let_it_be_with_reload(:zoekt_task) { create(:zoekt_task, :failed) }
  let(:repo) { zoekt_task.zoekt_repository }
  let(:data) do
    { zoekt_repository_id: repo.id, task_id: zoekt_task.id }
  end

  it_behaves_like 'worker with data consistency', described_class, data_consistency: :always

  it_behaves_like 'subscribes to event'

  it_behaves_like 'an idempotent worker' do
    let(:logger) { instance_double(::Search::Zoekt::Logger) }

    before do
      allow(::Search::Zoekt::Logger).to receive(:build).and_return(logger)
    end

    context 'when task_type is delete_repo' do
      before do
        zoekt_task.delete_repo!
      end

      it 'decrements the retries_left and changes the repo state to pending_deletion' do
        expect(logger).not_to receive(:info)
        expect { consume_event(subscriber: described_class, event: event) }
          .to change { repo.reload.retries_left }.by(-1)
        expect(repo).to be_pending_deletion
      end
    end

    context 'when retries_left is greater than one' do
      it 'decrements the retries_left and changes the state to pending' do
        expect(logger).not_to receive(:info)
        expect { consume_event(subscriber: described_class, event: event) }.to change {
          repo.reload.retries_left
        }.by(-1)
        expect(repo.state).to eq('pending')
      end
    end

    context 'when retries_left is equal to one' do
      before do
        repo.update!(retries_left: 1)
      end

      it 'decrements the retries_left and change the state to failed' do
        log_data = { class: described_class, failed_repo_id: repo.id, message: 'Repository moved to failed' }
        expect(logger).to receive(:info).with(log_data.as_json)
        expect { consume_event(subscriber: described_class, event: event) }.to change {
          repo.reload.retries_left
        }.by(-1)
        expect(repo.state).to eq('failed')
      end
    end
  end
end
