# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Orderable, feature_category: :api do
  let_it_be(:dummy_model_class) do
    Class.new(ActiveRecord::Base) do
      self.table_name = '_test_dummy_models'
      include Orderable
    end
  end

  context 'when primary_key is a single column' do
    before do
      allow(dummy_model_class).to receive(:primary_key).and_return('id')
    end

    describe '.supported_keyset_orderings' do
      it 'returns a hash with the primary key and asc/desc orderings' do
        expect(dummy_model_class.supported_keyset_orderings).to eq({ id: [:asc, :desc] })
      end
    end

    describe '.order_by_primary_key' do
      it 'orders by primary key in ascending order' do
        result = dummy_model_class.order_by_primary_key

        expect(result.to_sql).to include("ORDER BY \"_test_dummy_models\".\"id\"")
      end
    end

    describe '.keyset_order_by_primary_key' do
      shared_examples 'orders by primary key with given order' do |order|
        it 'orders by primary key' do
          result = if order
                     dummy_model_class.keyset_order_by_primary_key(order)
                   else
                     dummy_model_class.keyset_order_by_primary_key
                   end

          expect(result.to_sql).to include("ORDER BY \"_test_dummy_models\".\"id\" #{order&.upcase || 'ASC'}")
        end
      end

      it_behaves_like 'orders by primary key with given order'
      it_behaves_like 'orders by primary key with given order', 'asc'
      it_behaves_like 'orders by primary key with given order', 'desc'
    end
  end

  context 'when primary_key is an array of columns (composite primary key)' do
    before do
      allow(dummy_model_class).to receive(:primary_key).and_return(%w[id partition_id])
    end

    describe '.supported_keyset_orderings' do
      it 'returns a hash with each primary key and asc/desc orderings' do
        expect(dummy_model_class.supported_keyset_orderings).to eq({ id: [:asc, :desc],
                                                                     partition_id: [:asc, :desc] })
      end
    end

    describe '.order_by_primary_key' do
      it 'orders by primary key in ascending order' do
        expected_order = "ORDER BY \"_test_dummy_models\".\"id\", \"_test_dummy_models\".\"partition_id\""
        result = dummy_model_class.order_by_primary_key

        expect(result.to_sql).to include(expected_order)
      end
    end

    describe '.keyset_order_by_primary_key' do
      shared_examples 'orders by primary key with given order' do |order|
        it 'orders by primary key' do
          expected_order = order&.upcase || 'ASC'
          first_column_sql = "ORDER BY \"_test_dummy_models\".\"id\" #{expected_order},"
          second_column_sql = " \"_test_dummy_models\".\"partition_id\" #{expected_order}"

          result = if order
                     dummy_model_class.keyset_order_by_primary_key(order)
                   else
                     dummy_model_class.keyset_order_by_primary_key
                   end

          expect(result.to_sql).to include(first_column_sql + second_column_sql)
        end
      end

      it_behaves_like 'orders by primary key with given order'
      it_behaves_like 'orders by primary key with given order', 'asc'
      it_behaves_like 'orders by primary key with given order', 'desc'
    end
  end
end
