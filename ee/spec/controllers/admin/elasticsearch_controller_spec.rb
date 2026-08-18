# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::ElasticsearchController, feature_category: :global_search do
  let_it_be(:admin) { create(:admin) }
  let(:elasticsearch_settings_redirect) { search_admin_application_settings_path(anchor: 'js-elasticsearch-settings') }
  let(:reindexing_redirect) { search_admin_application_settings_path(anchor: 'js-elasticsearch-reindexing') }

  before do
    sign_in(admin)
  end

  describe 'POST #enqueue_index' do
    it 'starts indexing' do
      expect(::Search::Elastic::ReindexingService).to receive(:execute)

      post :enqueue_index

      expect(response).to redirect_to elasticsearch_settings_redirect
    end
  end

  describe 'POST #trigger_reindexing' do
    let(:params) do
      { search_elastic_reindexing_task: { elasticsearch_max_slices_running: 60, elasticsearch_slice_multiplier: 2 } }
    end

    it 'creates a reindexing task' do
      expect_next_instance_of(Search::Elastic::ReindexingTask) do |task|
        expect(task).to receive(:save).and_return(true)
      end

      post :trigger_reindexing, params: params

      expect(controller).to set_flash[:notice].to include('reindexing triggered')
      expect(response).to redirect_to reindexing_redirect
    end

    it 'does not create a reindexing task if there is another one' do
      allow(Search::Elastic::ReindexingTask).to receive(:current).and_return(build(:elastic_reindexing_task))

      post :trigger_reindexing, params: params

      expect(controller).to set_flash[:warning].to include('already in progress')
      expect(response).to redirect_to reindexing_redirect
    end

    it 'does not create a reindexing task if a required param is nil' do
      params = {
        search_elastic_reindexing_task: { elasticsearch_max_slices_running: nil, elasticsearch_slice_multiplier: 2 }
      }
      post :trigger_reindexing, params: params

      expect(controller).to set_flash[:alert].to include('Elasticsearch reindexing was not started')
      expect(response).to redirect_to reindexing_redirect
    end
  end

  describe 'POST #cancel_index_deletion' do
    let(:task) { create(:elastic_reindexing_task, state: :success, delete_original_index_at: Time.current) }

    it 'sets delete_original_index_at to nil' do
      post :cancel_index_deletion, params: { task_id: task.id }

      expect(task.reload.delete_original_index_at).to be_nil
      expect(controller).to set_flash[:notice].to include('deletion is canceled')
      expect(response).to redirect_to reindexing_redirect
    end
  end

  describe 'POST #retry_migration' do
    let(:migration) { Elastic::DataMigrationService.migrations.last }

    it 'deletes the migration record and drops the halted cache' do
      allow(Elastic::MigrationRecord).to receive(:new).and_call_original
      allow(Elastic::MigrationRecord).to receive(:new)
        .with(version: migration.version, name: migration.name, filename: migration.filename).and_return(migration)
      allow(Elastic::DataMigrationService).to receive(:migration_halted?).and_return(false)
      allow(Elastic::DataMigrationService).to receive(:migration_halted?).with(migration).and_return(true, false)
      expect(Elastic::DataMigrationService.halted_migrations?).to be_truthy

      post :retry_migration, params: { version: migration.version }

      expect(Elastic::DataMigrationService.halted_migrations?).to be_falsey
      expect(controller).to set_flash[:notice].to include('Migration has been scheduled to be retried')
      expect(response).to redirect_to elasticsearch_settings_redirect
    end
  end
end
