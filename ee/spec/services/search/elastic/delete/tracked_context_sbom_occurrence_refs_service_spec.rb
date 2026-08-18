# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::Delete::TrackedContextSbomOccurrenceRefsService, :elastic_helpers, feature_category: :dependency_management do
  describe '#index_name' do
    it 'returns the sbom occurrence ref index name' do
      service = described_class.new({})

      expect(service.send(:index_name)).to eq(::Search::Elastic::Types::Sbom::OccurrenceRef.index_name)
    end
  end

  describe '#build_query' do
    context 'when both project_id and security_project_tracked_context_id are provided' do
      it 'filters by project_id and security_project_tracked_context_id' do
        service = described_class.new(project_id: 1, security_project_tracked_context_id: 2)

        expect(service.send(:build_query)).to eq(
          query: {
            bool: {
              filter: [
                { term: { project_id: 1 } },
                { term: { security_project_tracked_context_id: 2 } }
              ]
            }
          }
        )
      end
    end

    context 'when project_id is missing' do
      it 'tracks and raises a dev exception' do
        service = described_class.new(security_project_tracked_context_id: 2)

        expect(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception)
          .with(an_instance_of(ArgumentError))

        expect(service.send(:build_query)).to be_nil
      end
    end

    context 'when security_project_tracked_context_id is missing' do
      it 'tracks and raises a dev exception' do
        service = described_class.new(project_id: 1)

        expect(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception)
          .with(an_instance_of(ArgumentError))

        expect(service.send(:build_query)).to be_nil
      end
    end
  end

  describe 'integration', :elastic_delete_by_query do
    let_it_be(:project) { create(:project) }
    let_it_be(:tracked_context) { create(:security_project_tracked_context, project: project) }
    let_it_be(:other_tracked_context) { create(:security_project_tracked_context, project: project) }

    let_it_be(:occurrence_refs) do
      create_list(:sbom_occurrence_ref, 2, project: project, tracked_context: tracked_context)
    end

    let_it_be(:other_occurrence_refs) do
      create_list(:sbom_occurrence_ref, 2, project: project, tracked_context: other_tracked_context)
    end

    let(:index_name) { ::Search::Elastic::Types::Sbom::OccurrenceRef.index_name }

    before do
      stub_ee_application_setting(elasticsearch_indexing: true)
      Elastic::ProcessBookkeepingService.track!(*occurrence_refs, *other_occurrence_refs)
      ensure_elasticsearch_index!
    end

    it 'deletes only the docs for the given tracked context' do
      expect(occurrence_ref_ids_in_index).to match_array((occurrence_refs + other_occurrence_refs).map(&:id))

      described_class.execute({
        project_id: project.id,
        security_project_tracked_context_id: tracked_context.id
      })

      es_helper.refresh_index(index_name: index_name)
      expect(occurrence_ref_ids_in_index).to match_array(other_occurrence_refs.map(&:id))
    end

    def occurrence_ref_ids_in_index
      es_client.search(index: index_name).dig('hits', 'hits').map { |hit| hit['_id'].to_i }
    end
  end
end
