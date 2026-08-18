# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::Delete::SbomOccurrenceRefsService, :elastic_helpers, feature_category: :dependency_management do
  describe '#index_name' do
    it 'returns the sbom occurrence ref index name' do
      service = described_class.new({})

      expect(service.send(:index_name)).to eq(::Search::Elastic::Types::Sbom::OccurrenceRef.index_name)
    end
  end

  describe 'integration', :elastic_delete_by_query do
    let_it_be(:old_group) { create(:group, :nested) }
    let_it_be(:project) { create(:project, namespace: old_group) }
    let_it_be(:occurrence_refs) { create_list(:sbom_occurrence_ref, 3, project: project) }
    let(:index_name) { ::Search::Elastic::Types::Sbom::OccurrenceRef.index_name }

    before do
      stub_ee_application_setting(elasticsearch_indexing: true)
      Elastic::ProcessBookkeepingService.track!(*occurrence_refs)
      ensure_elasticsearch_index!
    end

    context 'when project_id is provided' do
      it 'deletes all sbom occurrence refs' do
        expect(occurrence_ref_ids_in_index).to match_array(occurrence_refs.map(&:id))

        described_class.execute({
          project_id: project.id
        })

        es_helper.refresh_index(index_name: index_name)
        expect(occurrence_ref_ids_in_index).to be_empty
      end
    end

    context 'when project_id and traversal_id are provided' do
      it 'does not remove sbom occurrence refs that match the provided traversal_ids' do
        expect(occurrence_ref_ids_in_index).to match_array(occurrence_refs.map(&:id))

        described_class.execute({
          project_id: project.id,
          traversal_id: project.namespace.elastic_namespace_ancestry
        })

        es_helper.refresh_index(index_name: index_name)
        expect(occurrence_ref_ids_in_index).to match_array(occurrence_refs.map(&:id))
      end
    end

    def occurrence_ref_ids_in_index
      es_client.search(index: index_name).dig('hits', 'hits').map { |hit| hit['_id'].to_i }
    end
  end
end
