# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LooseForeignKeys::CleanerService, feature_category: :database do
  let(:schema) { ApplicationRecord.connection.current_schema }

  subject(:cleaner_service) do
    described_class.new(
      loose_foreign_key_definition: loose_fk_definition,
      connection: ApplicationRecord.connection,
      deleted_parent_records: deleted_records)
  end

  describe 'query generation' do
    context 'when condition defined in LFK' do
      let(:note) { create(:note_on_vulnerability) }
      let(:deleted_records) do
        [
          LooseForeignKeys::DeletedRecord.new(fully_qualified_table_name: "#{schema}.vulnerabilities",
            primary_key_value: note.noteable_id)
        ]
      end

      let(:loose_fk_definition) do
        ActiveRecord::ConnectionAdapters::ForeignKeyDefinition.new(
          'notes',
          'vulnerabilities',
          {
            column: 'noteable_id',
            on_delete: :async_nullify,
            gitlab_schema: :gitlab_main,
            conditions: [
              {
                column: "noteable_type",
                value: "Vulnerability"
              }
            ]
          }
        )
      end

      it 'generates a lateral query for nullifying the rows' do
        expected_query =
          'UPDATE "notes" SET "noteable_id" = NULL WHERE ("notes"."id") IN (' \
            'SELECT "lateral_rows"."id" FROM (VALUES (' \
            "#{note.noteable_id})) AS parent(\"noteable_id\"), " \
            'LATERAL (' \
            'SELECT "notes"."id" FROM "notes" ' \
            'WHERE "notes"."noteable_id" = "parent"."noteable_id" ' \
            "AND \"notes\".\"noteable_type\" = 'Vulnerability' " \
            'LIMIT 500) lateral_rows LIMIT 500)'
        expect(ApplicationRecord.connection).to receive(:execute).with(expected_query).and_call_original

        cleaner_service.execute

        note.reload
        expect(note.noteable_id).to be_nil
      end

      it 'generates a lateral query for deleting the rows' do
        loose_fk_definition.options[:on_delete] = :async_delete

        expected_query =
          'DELETE FROM "notes" WHERE ("notes"."id") IN (' \
            'SELECT "lateral_rows"."id" FROM (VALUES (' \
            "#{note.noteable_id})) AS parent(\"noteable_id\"), " \
            'LATERAL (' \
            'SELECT "notes"."id" FROM "notes" ' \
            'WHERE "notes"."noteable_id" = "parent"."noteable_id" ' \
            "AND \"notes\".\"noteable_type\" = 'Vulnerability' " \
            'LIMIT 1000) lateral_rows LIMIT 1000)'
        expect(ApplicationRecord.connection).to receive(:execute).with(expected_query).and_call_original

        cleaner_service.execute

        expect(Note.exists?(id: note.id)).to be(false)
      end

      context 'when updating target column', :aggregate_failures do
        let(:target_column) { 'note' }
        let(:target_value) { 'A note' }
        let(:update_query) do
          'UPDATE "notes" ' \
            "SET \"#{target_column}\" = '#{target_value}' " \
            'WHERE ("notes"."id") IN (' \
            'SELECT "lateral_rows"."id" FROM (VALUES (' \
            "#{note.noteable_id})) AS parent(\"noteable_id\"), " \
            'LATERAL (' \
            'SELECT "notes"."id" FROM "notes" ' \
            'WHERE "notes"."noteable_id" = "parent"."noteable_id" ' \
            "AND \"notes\".\"noteable_type\" = 'Vulnerability' " \
            "AND \"notes\".\"#{target_column}\" != '#{target_value}' " \
            'LIMIT 500) lateral_rows LIMIT 500)'
        end

        before do
          loose_fk_definition.options[:on_delete] = :update_column_to
          loose_fk_definition.options[:target_column] = target_column
          loose_fk_definition.options[:target_value] = target_value
        end

        it 'performs an UPDATE query' do
          expect(ApplicationRecord.connection).to receive(:execute).with(update_query).and_call_original

          cleaner_service.execute

          note.reload
          expect(note[target_column]).to eq(target_value)
        end
      end
    end
  end
end
