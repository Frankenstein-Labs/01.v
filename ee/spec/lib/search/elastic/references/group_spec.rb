# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::References::Group, :elastic_helpers, feature_category: :global_search do
  let_it_be(:parent_group) { create(:group) }
  let_it_be(:group) { create(:group, parent: parent_group, description: 'Test group description') }
  let(:reference) { described_class.new(group.id, group.es_parent) }

  describe '#as_indexed_json', :freeze_time do
    let(:expected_hash) do
      {
        type: described_class::DOC_TYPE,
        schema_version: described_class::SCHEMA_VERSION,
        id: group.id,
        name: group.name,
        path: group.path,
        full_name: group.full_name,
        full_path: group.full_path,
        description: group.description,
        parent_id: group.parent_id,
        traversal_ids: group.elastic_namespace_ancestry,
        visibility_level: group.visibility_level,
        created_at: be_within(0.1.seconds).of(group.created_at),
        updated_at: be_within(0.1.seconds).of(group.updated_at),
        archived: group.archived?,
        organization_id: group.organization_id
      }
    end

    subject(:indexed_json) { reference.as_indexed_json }

    it 'serializes the group as a hash' do
      expect(indexed_json.symbolize_keys).to match(expected_hash)
    end

    context 'when group has no parent' do
      let(:root_group) { create(:group, description: 'Root group') }
      let(:reference) { described_class.new(root_group.id, root_group.es_parent) }

      it 'includes nil parent_id' do
        expect(indexed_json[:parent_id]).to be_nil
      end
    end

    context 'when group has no description' do
      let(:group_without_description) { create(:group, description: nil) }
      let(:reference) { described_class.new(group_without_description.id, group_without_description.es_parent) }

      it 'includes nil description' do
        expect(indexed_json[:description]).to be_nil
      end
    end
  end

  describe '.preload_indexing_data' do
    let_it_be(:group2) { create(:group, parent: parent_group) }
    let_it_be(:group3) { create(:group, parent: parent_group) }

    def build_ref(ref_group)
      described_class.new(ref_group.id, ref_group.es_parent)
    end

    it 'preloads the database records onto the references' do
      ref = build_ref(group)

      expect(::Group).to receive(:preload_indexing_data).and_call_original

      described_class.preload_indexing_data([ref])

      expect(ref.database_record).to be_present
    end

    it 'does not have N+1 queries when serializing multiple references' do
      control_refs = [build_ref(group)]

      control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
        described_class.preload_indexing_data(control_refs)
        control_refs.each(&:as_indexed_json)
      end

      refs = [
        build_ref(group),
        build_ref(group2),
        build_ref(group3)
      ]

      expect do
        described_class.preload_indexing_data(refs)
        refs.each(&:as_indexed_json)
      end.not_to exceed_all_query_limit(control)
    end
  end

  describe '.serialize' do
    it 'returns serialized string from class method' do
      expect(described_class.serialize(group))
        .to eq("Group|#{group.id}|#{group.es_parent}")
    end
  end

  describe '#serialize' do
    it 'returns serialized string from instance method' do
      expect(reference.serialize)
        .to eq("Group|#{group.id}|#{group.es_parent}")
    end
  end

  describe '.instantiate' do
    it 'instantiates from a serialized string' do
      new_ref = described_class.instantiate(reference.serialize)

      expect(new_ref.identifier).to eq(group.id)
      expect(new_ref.routing).to eq(group.es_parent)
    end
  end

  describe '#klass' do
    it 'returns the class name' do
      expect(reference.klass).to eq('Group')
    end
  end

  describe '#index_name' do
    it 'returns correct environment based index name from class method' do
      expect(described_class.index).to eq('gitlab-test-groups')
    end

    it 'returns correct environment based index name from instance method' do
      expect(reference.index_name).to eq('gitlab-test-groups')
    end
  end

  describe '.model_klass' do
    it 'returns Group' do
      expect(described_class.model_klass).to eq(::Group)
    end
  end

  describe '#operation' do
    context 'when the database record exists' do
      it 'returns :index' do
        expect(reference.operation).to eq(:index)
      end
    end

    context 'when the database record does not exist' do
      it 'returns :delete' do
        ref = described_class.new(non_existing_record_id, 'root_namespace_1')

        expect(ref.operation).to eq(:delete)
      end
    end
  end
end
