# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Elastic::DataMigrationService, :clean_gitlab_redis_shared_state, feature_category: :global_search do
  describe '.migrations' do
    it 'all migration names are unique' do
      expect(described_class.migrations.count).to eq(described_class.migrations.map(&:name).uniq.count)
    end

    it 'all migration versions follow the same format', :aggregate_failures do
      described_class.migrations.each do |migration|
        expect(migration.version.to_s.length).to eq(14), "#{migration.name} version format is incorrect"
      end
    end

    context 'when migration_files stubbed' do
      let(:migration_files) do
        %w[ee/elastic/migrate/20201105180000_example_migration.rb
          ee/elastic/migrate/20201201130000_example_migration.rb]
      end

      before do
        allow(described_class).to receive(:migration_files).and_return(migration_files)
      end

      it 'creates migration records' do
        migration = described_class.migrations.first

        expect(described_class.migrations.count).to eq(2)
        expect(migration.version).to eq(20201105180000)
        expect(migration.name).to eq('ExampleMigration')
        expect(migration.filename).to eq(migration_files.first)
      end

      context 'when exclude_skipped is true' do
        let(:filename) { 'test.rb' }
        let(:version) { 20201105180000 }
        let(:skipped_migration) { Elastic::MigrationRecord.new(version: version, name: 'Test', filename: filename) }
        let(:migration_files) { ["ee/elastic/migrate/#{version}_#{filename}"] }

        before do
          allow(described_class).to receive(:migration_files).and_return(migration_files)
          allow(Elastic::MigrationRecord).to receive(:new).and_return(skipped_migration)
          allow(skipped_migration).to receive(:skip?).and_return(skip)
        end

        context 'when there is one migration and it is skipped' do
          let(:skip) { true }

          it 'is empty' do
            expect(described_class.migrations(exclude_skipped: true)).to be_empty
          end
        end

        context 'when there is one migration and it is not skipped' do
          let(:skip) { false }

          it 'returns the migration' do
            expect(described_class.migrations(exclude_skipped: true).first.version).to eq(version)
          end
        end
      end
    end

    describe 'migrations order optimization' do
      it 'ensure all update migrations run before backfill migrations', :aggregate_failures do
        error_message = <<~DOC
          Migrations should be ordered so all migrations that use ::Search::Elastic::MigrationUpdateMappingsHelper
          run before any migrations that use ::Search::Elastic::MigrationBackfillHelper. If this spec fails, rename the
          `YYYYMMDDHHMMSS` part of the migration filename with a datetime before the last backfill migration for the
          index_name.
          Ref: https://docs.gitlab.com/ee/development/search/advanced_search_migration_styleguide.html#best-practices-for-advanced-search-migrations
        DOC

        non_obsolete_migrations = described_class.migrations.filter_map { |m| m.send(:migration) unless m.obsolete? }

        docs_directory_path = File.join('ee', 'elastic', 'docs')

        filtered_migrations = non_obsolete_migrations.filter do |m|
          klass = m.class
          klass.include?(::Search::Elastic::MigrationUpdateMappingsHelper) ||
            klass.include?(::Search::Elastic::MigrationBackfillHelper)
        end

        migrations_grouped_by_index_and_milestone = filtered_migrations.group_by do |m|
          docs_file_path = "#{m.version}_#{m.class.name.underscore}.yml"
          docs_yaml = YAML.load_file(Rails.root.join(File.join(docs_directory_path, docs_file_path)))

          [m.send(:index_name), docs_yaml['milestone']]
        end

        migrations_grouped_by_index_and_milestone.each_key do |index_name|
          backfill_versions = non_obsolete_migrations.filter do |m|
            m.class.include?(::Search::Elastic::MigrationBackfillHelper) && m.send(:index_name) == index_name
          end.map(&:version)

          mapping_versions = non_obsolete_migrations.filter do |m|
            m.class.include?(::Search::Elastic::MigrationUpdateMappingsHelper) && m.send(:index_name) == index_name
          end.map(&:version)

          backfill_ranges = backfill_versions.each_cons(2).map { |a, b| a..b }
          result = mapping_versions.select { |v| backfill_ranges.any? { |r| r.include?(v) } }
          msg = <<~MSG
            index: #{index_name}
            migration_versions: #{result.map(&:to_s).join(', ')}
            #{error_message}
          MSG

          expect(result).to be_empty, msg
        end
      end
    end
  end

  describe '.migration_has_finished_uncached?', :elastic do
    let(:migration) { described_class.migrations.first }
    let(:migration_name) { migration.name.underscore }

    it 'returns true if migration has finished' do
      expect(described_class.migration_has_finished_uncached?(migration_name)).to be(true)

      migration.save!(completed: false)
      refresh_index!

      expect(described_class.migration_has_finished_uncached?(migration_name)).to be(false)

      migration.save!(completed: true)
      refresh_index!

      expect(described_class.migration_has_finished_uncached?(migration_name)).to be(true)
    end
  end

  describe '.migration_has_finished?' do
    let(:migration) { described_class.migrations.first }
    let(:migration_name) { migration.name.underscore }
    let(:finished) { true }

    before do
      allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
      allow(described_class).to receive(:migration_has_finished_uncached?).with(migration_name).and_return(finished)
    end

    it 'calls the uncached method only once' do
      expect(described_class).to receive(:migration_has_finished_uncached?).once

      expect(described_class.migration_has_finished?(migration_name)).to eq(finished)
      expect(described_class.migration_has_finished?(migration_name)).to eq(finished)
    end
  end

  describe '.mark_all_as_completed!', :elastic do
    before do
      # Clear out the migrations index since it is set up initially with
      # everything finished migrating
      es_helper.delete_migrations_index
      es_helper.create_migrations_index
    end

    it 'creates all migration versions' do
      expect(Elastic::MigrationRecord.load_versions(completed: true).count).to eq(0)

      described_class.mark_all_as_completed!
      refresh_index!

      expect(Elastic::MigrationRecord.load_versions(completed: true).count).to eq(described_class.migrations.count)
    end

    it 'drops all cache keys for finished and halted migrations' do
      allow(described_class).to receive(:migrations).and_return(
        [
          Elastic::MigrationRecord.new(version: 100, name: 'SomeMigration', filename: nil),
          Elastic::MigrationRecord.new(version: 200, name: 'SomeOtherMigration', filename: nil)
        ]
      )

      described_class.migrations.each do |migration|
        expect(described_class).to receive(:drop_migration_has_finished_cache!).with(migration)
        expect(described_class).to receive(:drop_migration_halted_cache!).with(migration)
      end

      described_class.mark_all_as_completed!
    end

    context 'when a migration exists in the index and is halted' do
      let(:migration) { described_class.migrations.first }

      before do
        migration.halt
        refresh_index!
      end

      it 'un-halts the migration' do
        expect(described_class.halted_migrations?).to be(true)

        described_class.mark_all_as_completed!
        refresh_index!

        expect(described_class.halted_migrations?).to be(false)
      end
    end
  end

  describe '.drop_migration_has_finished_cache!' do
    let(:migration) { described_class.migrations.first }
    let(:migration_name) { migration.name.underscore }
    let(:finished) { true }

    before do
      allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
      allow(described_class).to receive(:migration_has_finished_uncached?).with(migration_name).and_return(finished)
    end

    it 'drops cache' do
      expect(described_class).to receive(:migration_has_finished_uncached?).twice

      expect(described_class.migration_has_finished?(migration_name)).to eq(finished)

      described_class.drop_migration_has_finished_cache!(migration)

      expect(described_class.migration_has_finished?(migration_name)).to eq(finished)
    end
  end

  describe '.migration_halted?' do
    let(:migration) { described_class.migrations.last }

    before do
      allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
      allow(described_class).to receive(:migration_halted_uncached?).with(migration).and_return(true, false)
    end

    it 'calls the uncached method only once' do
      expect(described_class).to receive(:migration_halted_uncached?).once

      expect(described_class.migration_halted?(migration)).to be(true)
      expect(described_class.migration_halted?(migration)).to be(true)
    end
  end

  describe '.migration_halted_uncached?', :elastic do
    let(:migration) { described_class.migrations.last }
    let(:halted_response) { { _source: { state: { halted: true } } }.with_indifferent_access }
    let(:not_halted_response) { { _source: { state: { halted: false } } }.with_indifferent_access }

    it 'returns true if migration has been halted' do
      allow(migration).to receive(:load_from_index).and_return(not_halted_response)
      expect(described_class.migration_halted_uncached?(migration)).to be(false)

      allow(migration).to receive(:load_from_index).and_return(halted_response)
      expect(described_class.migration_halted_uncached?(migration)).to be(true)
    end
  end

  describe '.drop_migration_halted_cache!' do
    let(:migration) { described_class.migrations.last }

    before do
      allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
      allow(described_class).to receive(:migration_halted_uncached?).with(migration).and_return(true, false)
    end

    it 'drops cache' do
      expect(described_class).to receive(:migration_halted_uncached?).twice

      expect(described_class.migration_halted?(migration)).to be(true)

      described_class.drop_migration_halted_cache!(migration)

      expect(described_class.migration_halted?(migration)).to be(false)
    end
  end

  describe '.halted_migration', :elastic do
    let(:migration) { described_class.migrations.last }
    let(:halted_response) { { _source: { state: { halted: true } } }.with_indifferent_access }

    before do
      allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
      allow(Elastic::MigrationRecord).to receive(:new).and_call_original
      allow(Elastic::MigrationRecord).to receive(:new)
        .with(version: migration.version, name: migration.name, filename: migration.filename)
        .and_return(migration)
    end

    it 'returns a migration when it is halted' do
      expect(described_class.halted_migration).to be_nil

      allow(migration).to receive(:load_from_index).and_return(halted_response)
      described_class.drop_migration_halted_cache!(migration)

      expect(described_class.halted_migration).to eq(migration)
    end
  end

  describe 'pending_migrations?', :elastic do
    context 'when there are pending migrations' do
      let(:migration) { described_class.migrations.first }

      before do
        stub_ee_application_setting(elasticsearch_indexing: true)
        # reset migration index to ensure cache is cleared
        described_class.mark_all_as_completed!
        migration.save!(completed: false)
      end

      after do
        # reset migration index to prevent flakiness
        described_class.mark_all_as_completed!
      end

      it 'returns true' do
        expect(described_class.pending_migrations?).to be(true)
      end

      context 'when elasticsearch_indexing is false' do
        before do
          stub_ee_application_setting(elasticsearch_indexing: false)
        end

        it 'returns false' do
          expect(described_class.pending_migrations?).to be(false)
        end
      end
    end

    context 'when there are no pending migrations' do
      it 'returns false' do
        described_class.mark_all_as_completed!

        expect(described_class.pending_migrations?).to be(false)
      end
    end

    context 'when the cache has stale "finished" data' do
      let(:migration) { described_class.migrations.first }

      before do
        stub_ee_application_setting(elasticsearch_indexing: true)
        described_class.mark_all_as_completed!
        migration.save!(completed: false)
      end

      after do
        described_class.mark_all_as_completed!
      end

      it 'returns true by using the uncached check', :aggregate_failures do
        expect(described_class).not_to receive(:migration_has_finished?)
        expect(described_class.pending_migrations?).to be(true)
      end
    end
  end

  describe '.index_created_by_pending_migration?' do
    let(:create_index_migration) do
      described_class.find_by_name(:create_vulnerability_reads_index)
    end

    before do
      stub_ee_application_setting(elasticsearch_indexing: true)
      allow(described_class).to receive(:migration_has_finished_uncached?).and_return(true)
    end

    context 'when a create-index migration for the class is pending' do
      before do
        allow(described_class).to receive(:migration_has_finished_uncached?)
          .with(create_index_migration.name_for_key)
          .and_return(false)
      end

      it 'returns true for the targeted class' do
        expect(described_class.index_created_by_pending_migration?(Vulnerabilities::Read)).to be(true)
      end

      it 'returns false for a different class' do
        expect(described_class.index_created_by_pending_migration?(Vulnerability)).to be(false)
      end
    end

    context 'when the create-index migration is finished' do
      it 'returns false' do
        expect(described_class.index_created_by_pending_migration?(Vulnerabilities::Read)).to be(false)
      end
    end

    context 'when a pending migration defines target_class but does not include MigrationCreateIndexHelper' do
      let(:fake_migration) do
        Class.new do
          def name_for_key
            'fake_migration'
          end

          def target_class
            Vulnerabilities::Read
          end
        end.new
      end

      before do
        allow(described_class).to receive(:pending_migrations).and_return([fake_migration])
      end

      it 'returns false because the migration lacks the creates_standalone_index? marker' do
        expect(described_class.index_created_by_pending_migration?(Vulnerabilities::Read)).to be(false)
      end
    end
  end

  describe '.pending_create_index_target_classes' do
    let(:create_index_migration) do
      described_class.find_by_name(:create_vulnerability_reads_index)
    end

    before do
      stub_ee_application_setting(elasticsearch_indexing: true)
      allow(described_class).to receive(:migration_has_finished_uncached?).and_return(true)
    end

    context 'when a create-index migration is pending' do
      before do
        allow(described_class).to receive(:migration_has_finished_uncached?)
          .with(create_index_migration.name_for_key)
          .and_return(false)
      end

      it 'returns a Set containing the target class' do
        result = described_class.pending_create_index_target_classes

        expect(result).to be_a(Set)
        expect(result).to include(Vulnerabilities::Read)
      end
    end

    context 'when no create-index migrations are pending' do
      it 'returns an empty Set' do
        expect(described_class.pending_create_index_target_classes).to eq(Set.new)
      end
    end

    context 'when a pending migration lacks the creates_standalone_index? marker' do
      let(:fake_migration) do
        Class.new do
          def name_for_key
            'fake_migration'
          end

          def target_class
            Vulnerabilities::Read
          end
        end.new
      end

      before do
        allow(described_class).to receive(:pending_migrations).and_return([fake_migration])
      end

      it 'excludes its target_class from the result' do
        expect(described_class.pending_create_index_target_classes).not_to include(Vulnerabilities::Read)
      end
    end
  end

  describe 'pending_migrations', :elastic do
    # `freeze: false` is required here: migration objects are POROs that are
    # mutated via `save!`; freezing them raises FrozenError. Keep the opt-out
    # (see gitlab-org/gitlab#602925).
    let_it_be(:pending_migration1, freeze: false) { described_class.migrations[1] }
    # `freeze: false` is required here: migration objects are POROs that are
    # mutated via `save!`; freezing them raises FrozenError. Keep the opt-out
    # (see gitlab-org/gitlab#602925).
    let_it_be(:pending_migration2, freeze: false) { described_class.migrations[2] }

    before_all do
      # reset migration index to ensure cache is dropped
      described_class.mark_all_as_completed!

      pending_migration1.save!(completed: false)
      pending_migration2.save!(completed: false)
    end

    after(:all) do
      # reset migration index to prevent flakiness
      described_class.mark_all_as_completed!
    end

    context 'when elasticsearch_indexing is enabled' do
      before do
        stub_ee_application_setting(elasticsearch_indexing: true)
      end

      it 'returns only pending migrations' do
        expected = [pending_migration1, pending_migration2].map(&:name)

        expect(described_class.pending_migrations.map(&:name)).to eq(expected)
      end

      it 'does not include pending migrations which are skipped' do
        allow_next_instance_of(Elastic::MigrationRecord) do |m|
          allow(m).to receive(:skip?).and_return(true)
        end

        expect(described_class.pending_migrations.map(&:name)).to eq([])
      end
    end

    context 'when elasticsearch_indexing is disabled' do
      before do
        stub_ee_application_setting(elasticsearch_indexing: false)
      end

      it 'returns no pending migrations' do
        expect(described_class.pending_migrations).to eq([])
      end
    end

    context 'when the cache has stale "finished" data' do
      before do
        stub_ee_application_setting(elasticsearch_indexing: true)
        described_class.mark_all_as_completed!
        pending_migration1.save!(completed: false)
      end

      after do
        pending_migration1.save!(completed: false)
        pending_migration2.save!(completed: false)
      end

      it 'bypasses the cache and returns accurate results', :aggregate_failures do
        expect(described_class).not_to receive(:migration_has_finished?)
        expect(described_class.pending_migrations.map(&:name)).to include(pending_migration1.name)
      end
    end
  end
end
