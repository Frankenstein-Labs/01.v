# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::RepoMarkedAsToDeleteEventWorker, :zoekt_settings_enabled, feature_category: :global_search do
  let(:event) { Search::Zoekt::RepoMarkedAsToDeleteEvent.new(data: data) }
  let_it_be_with_reload(:repos) { create_list(:zoekt_repository, 3, :orphaned) }
  let(:scope) { Search::Zoekt::Repository.all }
  let(:data) { {} }

  it_behaves_like 'subscribes to event'

  it 'has the `until_executed` deduplicate strategy' do
    expect(described_class.get_deduplicate_strategy).to eq(:until_executed)
  end

  it_behaves_like 'an idempotent worker' do
    it 'creates a delete repo task for all repos in the list and will not reemit event' do
      expect(Search::Zoekt::Repository).to receive(:should_be_deleted).twice.and_call_original
      expect do
        consume_event(subscriber: described_class, event: event)
      end.to change { Search::Zoekt::Task.where(task_type: :delete_repo).size }.from(0).to(repos.size)
        .and not_publish_event(Search::Zoekt::RepoMarkedAsToDeleteEvent)
    end

    it 'processes in batches and reemits the event since there will be more repositories left to be process' do
      stub_const("#{described_class}::BATCH_SIZE", 2)
      expect(Search::Zoekt::Repository).to receive(:should_be_deleted).twice.and_call_original
      expect do
        consume_event(subscriber: described_class, event: event)
      end.to change { Search::Zoekt::Task.where(task_type: :delete_repo).size }.from(0).to(described_class::BATCH_SIZE)
        .and publish_event(Search::Zoekt::RepoMarkedAsToDeleteEvent).with(Hash.new({}))
    end

    context 'when preflight check fails due to too many pending tasks' do
      before do
        stub_const("#{described_class}::PENDING_TASKS_LIMIT", 2)
        create_list(:zoekt_task, 3, :pending, task_type: :delete_repo)
      end

      it 'does not create new tasks and does not reemit event' do
        expect(Search::Zoekt::Repository).not_to receive(:should_be_deleted)
        expect do
          consume_event(subscriber: described_class, event: event)
        end.to not_change(Search::Zoekt::Task.where(task_type: :delete_repo), :size)
          .and not_publish_event(Search::Zoekt::RepoMarkedAsToDeleteEvent)
      end
    end

    context 'when preflight check passes with pending tasks under limit' do
      before do
        stub_const("#{described_class}::PENDING_TASKS_LIMIT", 5)
        create_list(:zoekt_task, 2, :pending, task_type: :delete_repo)
      end

      it 'creates new tasks normally' do
        expect(Search::Zoekt::Repository).to receive(:should_be_deleted).twice.and_call_original
        expect do
          consume_event(subscriber: described_class, event: event)
        end.to change { Search::Zoekt::Task.where(task_type: :delete_repo).size }.from(2).to(2 + repos.size)
          .and not_publish_event(Search::Zoekt::RepoMarkedAsToDeleteEvent)
      end
    end

    context 'when preflight check passes with processing tasks under limit' do
      before do
        stub_const("#{described_class}::PENDING_TASKS_LIMIT", 5)
        create_list(:zoekt_task, 2, :processing, task_type: :delete_repo)
      end

      it 'creates new tasks normally' do
        expect(Search::Zoekt::Repository).to receive(:should_be_deleted).twice.and_call_original
        expect do
          consume_event(subscriber: described_class, event: event)
        end.to change { Search::Zoekt::Task.where(task_type: :delete_repo).size }.from(2).to(2 + repos.size)
          .and not_publish_event(Search::Zoekt::RepoMarkedAsToDeleteEvent)
      end
    end

    context 'when preflight check ignores completed tasks' do
      before do
        stub_const("#{described_class}::PENDING_TASKS_LIMIT", 2)
        create_list(:zoekt_task, 3, :done, task_type: :delete_repo)
        create(:zoekt_task, :pending, task_type: :delete_repo)
      end

      it 'creates new tasks as completed tasks are not counted' do
        expect(Search::Zoekt::Repository).to receive(:should_be_deleted).twice.and_call_original
        expect do
          consume_event(subscriber: described_class, event: event)
        end.to change { Search::Zoekt::Task.where(task_type: :delete_repo).size }.from(4).to(4 + repos.size)
          .and not_publish_event(Search::Zoekt::RepoMarkedAsToDeleteEvent)
      end
    end
  end
end
