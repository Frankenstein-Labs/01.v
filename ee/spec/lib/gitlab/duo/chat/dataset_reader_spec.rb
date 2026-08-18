# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Duo::Chat::DatasetReader, feature_category: :duo_chat do
  let(:dataset_dir) { Rails.root.join('ee/spec/fixtures/duo_chat_fixtures') }

  describe '.new' do
    it 'reads the metadata from the files' do
      reader = described_class.new(dataset_dir)
      expect(reader.total_rows).to eq(2)
      expect(reader.send(:file_names)).to match_array(['data1.jsonl', 'data2.jsonl'])
    end
  end

  describe '#read' do
    let(:reader) { described_class.new(dataset_dir) }

    it 'yields rows based on the actual files' do
      rows = []
      reader.read { |row| rows << row }

      expect(rows.size).to eq(reader.total_rows)

      expect(rows[0].ref).to eq('ref1')
      expect(rows[0].query).to eq('query1')
      expect(rows[0].resource.type).to eq('issue')

      expect(rows[1].ref).to eq('ref2')
      expect(rows[1].query).to eq('query2')
      expect(rows[1].resource.type).to eq('epic')
    end
  end

  describe described_class::DataRow do
    let(:row) { described_class.new(ref: 'ref', query: 'query', resource: 'resource') }

    it 'has accessors' do
      expect(row.ref).to eq('ref')
      expect(row.query).to eq('query')
      expect(row.resource).to eq('resource')
    end
  end
end
