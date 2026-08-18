# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::Rake::FixAutoResolvedVulnerabilities, feature_category: :vulnerability_management do
  include MigrationsHelpers

  let(:args) { { namespace_id: namespace_id } }

  describe 'execute' do
    let(:batched_migration) { described_class::MIGRATION }
    let(:connection) { SecApplicationRecord.connection }

    def up
      described_class.new(args).execute
    end

    def down
      described_class.new(args, revert: true).execute
    end

    context 'when performing an instance migration' do
      let(:namespace_id) { 'instance' }

      it 'schedules migration' do
        up

        Gitlab::Database::SharedModel.using_connection(connection) do
          expect(batched_migration).to have_scheduled_batched_migration(
            table_name: :vulnerability_reads,
            column_name: :vulnerability_id,
            gitlab_schema: :gitlab_sec,
            job_arguments: [namespace_id]
          )
        end

        down

        Gitlab::Database::SharedModel.using_connection(connection) do
          expect(batched_migration).not_to have_scheduled_batched_migration
        end
      end
    end

    context 'when migrating a namespace' do
      let_it_be(:namespace) { create(:namespace) }
      let_it_be(:namespace_id) { namespace.id.to_s }

      it 'schedules migration with parsed namespace_id' do
        up

        Gitlab::Database::SharedModel.using_connection(connection) do
          expect(batched_migration).to have_scheduled_batched_migration(
            table_name: :vulnerability_reads,
            column_name: :vulnerability_id,
            gitlab_schema: :gitlab_sec,
            job_arguments: [namespace_id.to_i]
          )
        end

        down

        Gitlab::Database::SharedModel.using_connection(connection) do
          expect(batched_migration).not_to have_scheduled_batched_migration
        end
      end
    end

    describe 'validations' do
      context 'when namespace_id is not a number' do
        let(:namespace_id) { 'foo' }

        it 'prints error and exits' do
          expect { up }.to raise_error(SystemExit)
            .and output("'foo' is not a number.\n" \
              "Use `gitlab-rake 'gitlab:vulnerabilities:fix_auto_resolved_vulnerabilities[instance]'` " \
              "to perform an instance migration.\n").to_stderr
        end
      end

      context 'when namespace_id does not exist' do
        let(:namespace_id) { non_existing_record_id.to_s }

        it 'prints error and exits' do
          expect { up }.to raise_error(SystemExit)
            .and output("Namespace:#{namespace_id} not found.\n").to_stderr
        end
      end

      context 'when namespace is a subgroup' do
        let_it_be(:namespace) { create(:group, :nested) }
        let_it_be(:namespace_id) { namespace.id.to_s }

        it 'prints error and exits' do
          expect { up }.to raise_error(SystemExit)
            .and output("Namespace must be top-level.\n").to_stderr
        end
      end
    end
  end
end
