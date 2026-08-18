# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ClickHouseModel, feature_category: :value_stream_management do
  let(:model_class) do
    Class.new do
      include ActiveModel::Model
      include ClickHouseModel

      self.clickhouse_table_name = 'test_table'

      def to_clickhouse_csv_row
        { foo: 'bar' }
      end
    end
  end

  describe '#to_clickhouse_csv_row' do
    it 'raises NoMethodError' do
      expect do
        described_class.new.to_clickhouse_csv_row
      end.to raise_error(NoMethodError)
    end
  end

  describe '#store_to_clickhouse' do
    subject(:model) { model_class.new }

    it 'saves serialized record to clickhouse buffer' do
      expect(::ClickHouse::WriteBuffer).to receive(:add).with('test_table', { foo: 'bar' })

      model.store_to_clickhouse
    end
  end
end
