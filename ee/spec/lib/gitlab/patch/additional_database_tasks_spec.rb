# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Patch::AdditionalDatabaseTasks, feature_category: :geo_replication do
  describe Gitlab::Patch::AdditionalDatabaseTasks::ActiveRecordDatabaseTasksDumpFilename do
    subject do
      Class.new do
        prepend Gitlab::Patch::AdditionalDatabaseTasks::ActiveRecordDatabaseTasksDumpFilename

        def schema_dump_path(*)
          Rails.root.join('foo.sql').to_s
        end
      end.new
    end

    describe '#schema_dump_path' do
      using RSpec::Parameterized::TableSyntax

      where(:db_config_name, :structure_path) do
        :main      | 'foo.sql'
        :embedding | 'ee/db/embedding/structure.sql'
        :geo       | 'ee/db/geo/structure.sql'
      end

      with_them do
        let(:db_config) { ActiveRecord::DatabaseConfigurations::HashConfig.new('test', db_config_name, {}) }

        it 'returns the correct path for the structure.sql file' do
          expect(subject.schema_dump_path(db_config)).to eq Rails.root.join(structure_path).to_s
        end
      end
    end
  end

  describe Gitlab::Patch::AdditionalDatabaseTasks::SchemaCacheDumpPath do
    describe '#default_schema_cache_path' do
      using RSpec::Parameterized::TableSyntax

      let(:db_config) { ActiveRecord::DatabaseConfigurations::HashConfig.new('test', db_config_name, {}) }

      before do
        allow(db_config).to receive(:primary?).and_return(primary)
      end

      where(:db_config_name, :primary, :schema_cache_path) do
        :main      | true  | 'db/schema_cache.yml'
        :ci        | false | 'db/ci_schema_cache.yml'
        :sec       | false | 'db/sec_schema_cache.yml'
        :embedding | false | Rails.root.join('ee/db/embedding/schema_cache.yml').to_s
        :geo       | false | Rails.root.join('ee/db/geo/schema_cache.yml').to_s
      end

      with_them do
        it 'returns the correct path for the schema_cache file' do
          expect(db_config.default_schema_cache_path).to eq schema_cache_path
        end
      end
    end
  end

  describe Gitlab::Patch::AdditionalDatabaseTasks::ActiveRecordMigrationConfiguredMigratePath do
    describe '#configured_migrate_path' do
      context 'when super returns nil' do
        subject do
          Class.new do
            prepend Gitlab::Patch::AdditionalDatabaseTasks::ActiveRecordMigrationConfiguredMigratePath

            def configured_migrate_path
              nil
            end
          end.new
        end

        it 'returns nil' do
          expect(subject.configured_migrate_path).to be_nil
        end
      end

      context 'when super returns only one regular migration path' do
        subject do
          Class.new do
            prepend Gitlab::Patch::AdditionalDatabaseTasks::ActiveRecordMigrationConfiguredMigratePath

            def configured_migrate_path
              'ee/db/geo/migrate'
            end
          end.new
        end

        it 'returns the configured migrate path' do
          expect(subject.configured_migrate_path).to eq('ee/db/geo/migrate')
        end
      end

      context 'when super returns only one post migrations path' do
        subject do
          Class.new do
            prepend Gitlab::Patch::AdditionalDatabaseTasks::ActiveRecordMigrationConfiguredMigratePath

            def configured_migrate_path
              'ee/db/geo/post_migrate'
            end
          end.new
        end

        it 'returns nil' do
          expect(subject.configured_migrate_path).to be_nil
        end
      end

      context 'when super does not include a post migrations path' do
        subject do
          Class.new do
            prepend Gitlab::Patch::AdditionalDatabaseTasks::ActiveRecordMigrationConfiguredMigratePath

            def configured_migrate_path
              'ee/db/geo/migrate'
            end
          end.new
        end

        it 'returns the configured migrations path' do
          expect(subject.configured_migrate_path).to eq('ee/db/geo/migrate')
        end
      end

      context 'when super includes a post migrations path' do
        subject do
          Class.new do
            prepend Gitlab::Patch::AdditionalDatabaseTasks::ActiveRecordMigrationConfiguredMigratePath

            def configured_migrate_path
              ['ee/db/geo/migrate', 'ee/db/geo/post_migrate']
            end
          end.new
        end

        it 'returns the regular migration path' do
          expect(subject.configured_migrate_path).to eq('ee/db/geo/migrate')
        end
      end
    end
  end
end
