# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::NamespaceTraversalSqlBuilder, feature_category: :security_asset_inventories do
  let(:subject_class) do
    Class.new do
      include Security::NamespaceTraversalSqlBuilder

      # Expose private methods for testing
      public :pluck_namespace_ids_and_traversal_ids,
        :with_namespace_data,
        :namespaces_and_traversal_ids_query_values
    end
  end

  let(:instance) { subject_class.new }

  describe '#pluck_namespace_ids_and_traversal_ids' do
    let_it_be(:group1) { create(:group) }
    let_it_be(:group2) { create(:group) }

    it 'returns an array of [id, traversal_ids] pairs' do
      result = instance.pluck_namespace_ids_and_traversal_ids(
        Namespace.where(id: [group1.id, group2.id])
      )

      expect(result).to contain_exactly(
        [group1.id, group1.traversal_ids],
        [group2.id, group2.traversal_ids]
      )
    end

    it 'returns an empty array for an empty relation' do
      result = instance.pluck_namespace_ids_and_traversal_ids(Namespace.none)

      expect(result).to be_empty
    end
  end

  describe '#with_namespace_data' do
    let_it_be(:group) { create(:group) }
    let_it_be(:deleted_group) { create(:group, state: :deletion_in_progress) }
    let_it_be(:project_namespace) { create(:project_namespace) }

    context 'when namespace_ids_batch is nil' do
      it 'returns nil' do
        expect(instance.with_namespace_data(nil)).to be_nil
      end
    end

    context 'when namespace_ids_batch is empty' do
      it 'returns nil' do
        expect(instance.with_namespace_data([])).to be_nil
      end
    end

    context 'when namespace_ids_batch contains valid group namespace ids' do
      it 'returns a SQL VALUES string containing the namespace id and traversal_ids' do
        result = instance.with_namespace_data([group.id])

        expect(result).to include(
          group.id.to_s,
          "ARRAY#{group.traversal_ids}::bigint[]"
        )
      end
    end

    context 'when namespace_ids_batch contains only deleted namespaces' do
      it 'returns nil' do
        result = instance.with_namespace_data([deleted_group.id])

        expect(result).to be_nil
      end
    end

    context 'when namespace_ids_batch contains only project namespaces' do
      it 'returns nil' do
        result = instance.with_namespace_data([project_namespace.id])

        expect(result).to be_nil
      end
    end

    context 'when namespace_ids_batch contains non-existent ids' do
      it 'returns nil' do
        result = instance.with_namespace_data([non_existing_record_id])

        expect(result).to be_nil
      end
    end
  end

  describe '#namespaces_and_traversal_ids_query_values' do
    it 'returns a SQL VALUES string with namespace_id, traversal_ids, and next_traversal_ids' do
      namespace_values = [[1, [10, 20, 30]]]

      result = instance.namespaces_and_traversal_ids_query_values(namespace_values)

      expect(result).to include('1', 'ARRAY[10, 20, 30]::bigint[]', 'ARRAY[10, 20, 31]::bigint[]')
    end

    it 'handles multiple namespaces' do
      namespace_values = [[1, [10, 20]], [2, [10, 30]]]

      result = instance.namespaces_and_traversal_ids_query_values(namespace_values)

      expect(result).to include(
        '1', 'ARRAY[10, 20]::bigint[]', 'ARRAY[10, 21]::bigint[]',
        '2', 'ARRAY[10, 30]::bigint[]', 'ARRAY[10, 31]::bigint[]'
      )
    end
  end
end
