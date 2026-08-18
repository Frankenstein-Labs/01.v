# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'gitlab:geo:logical_replication:*', :silence_stdout, feature_category: :geo_replication do
  include RakeHelpers
  include ::EE::GeoHelpers

  let(:statement_invalid) { ActiveRecord::StatementInvalid.new }

  before_all do
    Rake.application.rake_require 'tasks/gitlab/geo/logical_replication'
    Rake::Task.define_task(:gitlab_environment)
  end

  before do
    %w[
      publication:create
      publication:delete
      publication:set_tables
      subscription:refresh
    ].each { |task| Rake::Task["gitlab:geo:logical_replication:#{task}"].reenable }
  end

  describe 'gitlab:geo:logical_replication:publication:create' do
    let(:task_name) { 'gitlab:geo:logical_replication:publication:create' }

    context 'when running on a primary site' do
      before do
        stub_primary_site
        allow(ApplicationRecord.connection).to receive(:execute)
      end

      it 'creates the publication' do
        run_rake_task(task_name)

        expect(ApplicationRecord.connection).to have_received(:execute)
          .with("CREATE PUBLICATION geo_publication;")
      end

      context 'when the publication already exists' do
        before do
          allow(statement_invalid).to receive(:cause).and_return(PG::DuplicateObject.new)
          allow(ApplicationRecord.connection).to receive(:execute).and_raise(statement_invalid)
        end

        it 'reports the publication exists and does not raise' do
          expect { run_rake_task(task_name) }
            .to output(/Publication already exists/).to_stdout
        end
      end

      context 'when an unexpected database error occurs' do
        before do
          allow(ApplicationRecord.connection).to receive(:execute).and_raise(
            ActiveRecord::StatementInvalid.new('syntax error')
          )
        end

        it 're-raises the error' do
          expect { run_rake_task(task_name) }.to raise_error(ActiveRecord::StatementInvalid)
        end
      end
    end

    context 'when running on a secondary site' do
      before do
        stub_secondary_site
      end

      it 'aborts' do
        expect { run_rake_task(task_name) }
          .to raise_error(SystemExit)
          .and output(/only available on the primary node/).to_stderr
      end
    end
  end

  describe 'gitlab:geo:logical_replication:publication:delete' do
    let(:task_name) { 'gitlab:geo:logical_replication:publication:delete' }

    context 'when running on a primary site' do
      before do
        stub_primary_site
        allow(ApplicationRecord.connection).to receive(:execute)
      end

      it 'drops the publication' do
        run_rake_task(task_name)

        expect(ApplicationRecord.connection).to have_received(:execute)
          .with("DROP PUBLICATION geo_publication;")
      end

      context 'when the publication does not exist' do
        before do
          allow(statement_invalid).to receive(:cause).and_return(PG::UndefinedObject.new)
          allow(ApplicationRecord.connection).to receive(:execute).and_raise(statement_invalid)
        end

        it 'reports the publication does not exist and does not raise' do
          expect { run_rake_task(task_name) }
            .to output(/publication does not exist/).to_stdout
        end
      end

      context 'when an unexpected database error occurs' do
        before do
          allow(statement_invalid).to receive(:cause).and_return(StandardError.new)
          allow(ApplicationRecord.connection).to receive(:execute).and_raise(statement_invalid)
        end

        it 're-raises the error' do
          expect { run_rake_task(task_name) }.to raise_error(ActiveRecord::StatementInvalid)
        end
      end
    end

    context 'when running on a secondary site' do
      before do
        stub_secondary_site
      end

      it 'aborts' do
        expect { run_rake_task(task_name) }
          .to raise_error(SystemExit)
          .and output(/only available on the primary node/).to_stderr
      end
    end
  end

  describe 'gitlab:geo:logical_replication:publication:set_tables' do
    let(:task_name) { 'gitlab:geo:logical_replication:publication:set_tables' }
    let(:db_tables) { %w[projects users ar_internal_metadata schema_migrations] }
    let(:current_publication_tables) { [] }

    context 'when running on a primary site' do
      before do
        stub_primary_site
        allow(ApplicationRecord.connection).to receive(:execute) do |sql|
          if sql.match?(/SELECT.*pg_publication/m)
            instance_double(PG::Result, values: current_publication_tables.map { |t| [t] })
          end
        end
        allow(ApplicationRecord.connection).to receive(:tables).and_return(db_tables)
      end

      context 'when no tables are in the publication yet' do
        it 'adds every non-excluded table', :aggregate_failures do
          run_rake_task(task_name)

          expect(ApplicationRecord.connection).to have_received(:execute)
            .with('ALTER PUBLICATION geo_publication ADD TABLE "projects"')
          expect(ApplicationRecord.connection).to have_received(:execute)
            .with('ALTER PUBLICATION geo_publication ADD TABLE "users"')
        end

        it 'does not add excluded tables', :aggregate_failures do
          run_rake_task(task_name)

          expect(ApplicationRecord.connection).not_to have_received(:execute)
            .with(/ADD TABLE "schema_migrations"/)
          expect(ApplicationRecord.connection).not_to have_received(:execute)
            .with(/ADD TABLE "ar_internal_metadata"/)
        end
      end

      context 'when a table is already in the publication' do
        let(:current_publication_tables) { %w[projects] }

        it 'does not add it again' do
          run_rake_task(task_name)

          expect(ApplicationRecord.connection).not_to have_received(:execute)
            .with(/ADD TABLE "projects"/)
        end

        it 'still adds tables not yet in the publication', :aggregate_failures do
          run_rake_task(task_name)

          expect(ApplicationRecord.connection).to have_received(:execute)
            .with('ALTER PUBLICATION geo_publication ADD TABLE "users"')
        end
      end

      context 'when an excluded table is currently in the publication' do
        let(:current_publication_tables) { %w[schema_migrations] }

        it 'removes the excluded table' do
          run_rake_task(task_name)

          expect(ApplicationRecord.connection).to have_received(:execute)
            .with('ALTER PUBLICATION geo_publication DROP TABLE "schema_migrations"')
        end
      end

      context 'when an excluded table is not in the publication' do
        let(:current_publication_tables) { [] }

        it 'does not issue a DROP TABLE for it' do
          run_rake_task(task_name)

          expect(ApplicationRecord.connection).not_to have_received(:execute)
            .with(/DROP TABLE "schema_migrations"/)
        end
      end
    end

    context 'when running on a secondary site' do
      before do
        stub_secondary_site
      end

      it 'aborts via the :create prerequisite' do
        expect { run_rake_task(task_name) }
          .to raise_error(SystemExit)
          .and output(/only available on the primary node/).to_stderr
      end
    end
  end

  describe 'gitlab:geo:logical_replication:subscription:refresh' do
    let(:task_name) { 'gitlab:geo:logical_replication:subscription:refresh' }

    context 'when running on a secondary site' do
      before do
        stub_secondary_site
        allow(ApplicationRecord.connection).to receive(:execute)
      end

      it 'refreshes the subscription' do
        run_rake_task(task_name)

        expect(ApplicationRecord.connection).to have_received(:execute)
          .with("ALTER SUBSCRIPTION geo_subscription REFRESH PUBLICATION")
      end

      context 'when it errors' do
        before do
          allow(ApplicationRecord.connection).to receive(:execute)
            .and_raise(ActiveRecord::StatementInvalid.new("I am a spec error"))
        end

        it 'prints out an error message' do
          expect do
            run_rake_task(task_name)
          end.to raise_error(SystemExit, "Error refreshing the subscription: I am a spec error")
        end
      end
    end

    context 'when running on a primary site' do
      before do
        stub_primary_site
      end

      it 'aborts' do
        expect { run_rake_task(task_name) }
          .to raise_error(SystemExit)
          .and output(/only available on secondary nodes/).to_stderr
      end
    end
  end
end
