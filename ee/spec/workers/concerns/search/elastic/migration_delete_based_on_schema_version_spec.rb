# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Elastic::MigrationDeleteBasedOnSchemaVersion, :elastic, feature_category: :global_search do
  context 'when methods are not implemented' do
    let(:migration_class) do
      Class.new do
        include ::Search::Elastic::MigrationDeleteBasedOnSchemaVersion
      end
    end

    subject(:migration) { migration_class.new }

    describe '#schema_version' do
      it 'raises a NotImplementedError' do
        expect { migration.schema_version }.to raise_error(NotImplementedError)
      end
    end

    describe '#es_document_type' do
      it 'raises a NotImplementedError' do
        expect { migration.es_document_type }.to raise_error(NotImplementedError)
      end
    end
  end
end
