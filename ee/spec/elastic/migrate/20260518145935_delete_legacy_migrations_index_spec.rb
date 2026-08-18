# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../elastic/migrate/20260518145935_delete_legacy_migrations_index'

RSpec.describe DeleteLegacyMigrationsIndex, :elastic, feature_category: :global_search do
  let(:version) { 20260518145935 }
  let(:migration) { described_class.new(version) }
  let(:helper) { Search::Elastic::Helper.default }
  let(:client) { Gitlab::Search::Client.new }
  let(:old_index_name) { "#{helper.target_name}-migrations" }
  let(:settings) { { number_of_shards: 1 } }
  let(:mappings) do
    {
      properties: {
        completed: { type: 'boolean' },
        state: { type: 'object' },
        started_at: { type: 'date' },
        completed_at: { type: 'date' },
        name: { type: 'keyword' }
      }
    }
  end

  before do
    allow(Search::Elastic::Helper).to receive(:default).and_return(helper)
    cleanup_index
  end

  after do
    cleanup_index
  end

  def cleanup_index
    helper.delete_index(index_name: old_index_name) if helper.index_exists?(index_name: old_index_name)
  end

  def create_index(index_settings: settings, index_mappings: mappings)
    client.indices.create( # rubocop:disable Rails/SaveBang -- Elasticsearch client does not use ActiveRecord bang methods
      index: old_index_name,
      body: {
        settings: index_settings,
        mappings: index_mappings
      }
    )
  end

  describe '#migrate' do
    context 'when old index does not exist' do
      it 'logs and returns early' do
        allow(migration).to receive(:log)

        migration.migrate

        expect(migration).to have_received(:log).with(/does not exist/)
        expect(migration.completed?).to be true
      end
    end

    context 'when old index exists' do
      before do
        create_index
      end

      it 'deletes the index' do
        expect(helper.index_exists?(index_name: old_index_name)).to be true
        expect(migration.completed?).to be false

        migration.migrate

        expect(migration.completed?).to be true
        expect(helper.index_exists?(index_name: old_index_name)).to be false
      end

      it 'logs the deletion' do
        allow(migration).to receive(:log)

        migration.migrate

        expect(migration).to have_received(:log).with(/Starting migration to delete/)
        expect(migration).to have_received(:log).with(/has been deleted/)
      end
    end

    context 'when an error occurs' do
      before do
        # We reset the global helper stub here to allow allow_next_instance_of to work.
        # The simplified direct stub form (allow(helper).to receive...) doesn't work
        # because retry_on_failure's error handling prevents RSpec from catching the error properly.
        allow(Search::Elastic::Helper).to receive(:default).and_call_original
        create_index
      end

      it 'raises the error and allows retry_on_failure to handle it' do
        allow_next_instance_of(Search::Elastic::Helper) do |helper_instance|
          allow(helper_instance).to receive(:delete_index).and_raise(StandardError.new('Connection failed'))
        end

        expect { migration.migrate }.to raise_error(StandardError, 'Connection failed')
      end
    end
  end

  describe '#completed?' do
    context 'when old index does not exist' do
      it 'returns true' do
        expect(migration.completed?).to be true
      end
    end

    context 'when old index exists' do
      before do
        create_index
      end

      it 'returns false' do
        expect(migration.completed?).to be false
      end
    end
  end
end
