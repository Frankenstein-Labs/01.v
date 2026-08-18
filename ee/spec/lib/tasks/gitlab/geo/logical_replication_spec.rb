# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Tasks::Gitlab::Geo::LogicalReplication, feature_category: :geo_replication do
  subject(:instance) { Class.new.include(described_class).new }

  describe 'EXCLUDED_TABLES' do
    it 'excludes schema bookkeeping tables that should never be replicated' do
      expect(described_class::EXCLUDED_TABLES).to contain_exactly(
        'ar_internal_metadata',
        'detached_partitions',
        'schema_migrations'
      )
    end
  end

  describe '#publication_name' do
    context 'when the GEO_PUBLICATION env var is unset' do
      it 'defaults to "geo_publication"' do
        stub_env('GEO_PUBLICATION', nil)

        expect(instance.publication_name).to eq('geo_publication')
      end
    end

    context 'when the GEO_PUBLICATION env var is set' do
      it 'returns the value from the environment' do
        stub_env('GEO_PUBLICATION', 'my_custom_publication')

        expect(instance.publication_name).to eq('my_custom_publication')
      end
    end
  end

  describe '#publication_tables' do
    context 'when the publication name is empty' do
      it 'returns an empty array without querying the database' do
        expect(ApplicationRecord.connection).not_to receive(:execute)

        expect(instance.publication_tables('')).to eq([])
      end
    end

    context 'when the publication exists' do
      let(:result) { instance_double(PG::Result, values: [['projects'], ['users']]) }

      it 'returns the parent table names registered to the publication' do
        expect(ApplicationRecord.connection).to receive(:execute) do |sql|
          expect(sql).to match(/FROM pg_publication p/)
          expect(sql).to match(/JOIN pg_publication_rel pr ON pr\.prpubid = p\.oid/)
          expect(sql).to match(/JOIN pg_class c ON c\.oid = pr\.prrelid/)
          expect(sql).to include("p.pubname IN ('geo_publication')")

          result
        end

        expect(instance.publication_tables('geo_publication')).to eq(%w[projects users])
      end

      it 'quotes the publication name to guard against SQL injection' do
        expect(ApplicationRecord.connection).to receive(:execute) do |sql|
          expect(sql).to include("p.pubname IN ('o''hara''')")
          result
        end

        instance.publication_tables("o'hara'")
      end
    end

    context 'when the publication has no tables' do
      let(:result) { instance_double(PG::Result, values: []) }

      it 'returns an empty array' do
        allow(ApplicationRecord.connection).to receive(:execute).and_return(result)

        expect(instance.publication_tables('geo_publication')).to eq([])
      end
    end
  end

  describe '#alter_publication' do
    before do
      allow(ApplicationRecord.connection).to receive(:execute)
    end

    context 'when the action is "ADD"' do
      it 'issues an ALTER PUBLICATION ... ADD TABLE statement with a quoted identifier' do
        instance.alter_publication('ADD', 'projects')

        expect(ApplicationRecord.connection).to have_received(:execute)
          .with('ALTER PUBLICATION geo_publication ADD TABLE "projects"')
      end
    end

    context 'when the action is "DROP"' do
      it 'issues an ALTER PUBLICATION ... DROP TABLE statement with a quoted identifier' do
        instance.alter_publication('DROP', 'projects')

        expect(ApplicationRecord.connection).to have_received(:execute)
          .with('ALTER PUBLICATION geo_publication DROP TABLE "projects"')
      end
    end

    context 'when the action is anything else' do
      it 'raises ArgumentError and does not issue a query' do
        expect { instance.alter_publication('TRUNCATE', 'projects') }
          .to raise_error(ArgumentError, /action must be ADD or DROP/)

        expect(ApplicationRecord.connection).not_to have_received(:execute)
      end
    end
  end
end
