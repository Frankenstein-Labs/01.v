# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::Concerns::SchemaVersionedReference, feature_category: :global_search do
  let(:test_class) do
    klass = Class.new do
      include ::Search::Elastic::Concerns::SchemaVersionedReference

      def public_set_field(fields, name, &block)
        set_field(fields, name, &block)
      end

      def public_internal_es_fields
        internal_es_fields
      end

      def public_fetch_schema_version
        fetch_schema_version
      end

      def public_waiting_on_migration?(field)
        waiting_on_migration?(field)
      end
    end

    klass.const_set(:DOC_TYPE, 'test_doc_type')
    klass.const_set(:FIELDS_WITH_MIGRATIONS, { 'gated_field' => :some_migration }.freeze)
    klass.const_set(:SCHEMA_VERSIONS, { 26_02 => :some_migration, 26_01 => nil }.freeze)
    klass
  end

  let(:test_object) { test_class.new }

  describe '#fetch_schema_version' do
    context 'when the migration for the latest schema version has finished' do
      before do
        allow(::Elastic::DataMigrationService).to receive(:migration_has_finished?)
          .with(:some_migration).and_return(true)
      end

      it 'returns the latest schema version' do
        expect(test_object.public_fetch_schema_version).to eq(26_02)
      end
    end

    context 'when the migration for the latest schema version has not finished' do
      before do
        allow(::Elastic::DataMigrationService).to receive(:migration_has_finished?)
          .with(:some_migration).and_return(false)
      end

      it 'returns the highest schema version that does not require a migration' do
        expect(test_object.public_fetch_schema_version).to eq(26_01)
      end
    end
  end

  describe '#internal_es_fields' do
    before do
      allow(::Elastic::DataMigrationService).to receive(:migration_has_finished?)
        .with(:some_migration).and_return(true)
    end

    it 'returns the type and schema version with indifferent access', :aggregate_failures do
      fields = test_object.public_internal_es_fields

      expect(fields[:type]).to eq('test_doc_type')
      expect(fields['type']).to eq('test_doc_type')
      expect(fields[:schema_version]).to eq(26_02)
    end
  end

  describe '#waiting_on_migration?' do
    context 'when the field has no associated migration' do
      it 'returns false' do
        expect(test_object.public_waiting_on_migration?('unmapped_field')).to be(false)
      end
    end

    context 'when the field has an associated migration that has finished' do
      before do
        allow(::Elastic::DataMigrationService).to receive(:migration_has_finished?)
          .with(:some_migration).and_return(true)
      end

      it 'returns false' do
        expect(test_object.public_waiting_on_migration?('gated_field')).to be(false)
      end
    end

    context 'when the field has an associated migration that has not finished' do
      before do
        allow(::Elastic::DataMigrationService).to receive(:migration_has_finished?)
          .with(:some_migration).and_return(false)
      end

      it 'returns true' do
        expect(test_object.public_waiting_on_migration?('gated_field')).to be(true)
      end
    end

    context 'when the including class does not define FIELDS_WITH_MIGRATIONS' do
      let(:test_class) do
        klass = Class.new do
          include ::Search::Elastic::Concerns::SchemaVersionedReference

          def public_waiting_on_migration?(field)
            waiting_on_migration?(field)
          end
        end

        klass.const_set(:DOC_TYPE, 'test_doc_type')
        klass.const_set(:SCHEMA_VERSIONS, { 26_01 => nil }.freeze)
        klass
      end

      it 'returns false' do
        expect(test_object.public_waiting_on_migration?('any_field')).to be(false)
      end
    end
  end

  describe '#set_field' do
    context 'when the field is not waiting on a migration' do
      it 'sets the field to the value yielded by the block' do
        fields = {}

        test_object.public_set_field(fields, 'unmapped_field') { 'value' }

        expect(fields).to eq({ 'unmapped_field' => 'value' })
      end
    end

    context 'when the field is waiting on a migration' do
      before do
        allow(::Elastic::DataMigrationService).to receive(:migration_has_finished?)
          .with(:some_migration).and_return(false)
      end

      it 'does not set the field' do
        fields = {}

        test_object.public_set_field(fields, 'gated_field') { 'value' }

        expect(fields).to eq({})
      end
    end
  end
end
