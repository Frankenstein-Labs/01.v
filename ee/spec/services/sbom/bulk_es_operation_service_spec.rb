# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::BulkEsOperationService, :elastic, feature_category: :dependency_management do
  let_it_be(:group) { create(:group, :nested) }
  let_it_be(:project) { create(:project, namespace: group) }
  let_it_be(:occurrence_refs) { create_list(:sbom_occurrence_ref, 2, project: project) }

  let(:relation) { Sbom::OccurrenceRef.id_in(occurrence_refs.map(&:id)) }

  subject(:service) { described_class.new(relation) }

  before do
    allow(::Search::Elastic::SbomOccurrenceRefIndexHelper).to receive(:indexing_allowed?).and_return(true)
    allow_next_found_instance_of(Sbom::OccurrenceRef) do |instance|
      allow(instance).to receive(:maintaining_elasticsearch?).and_return(true)
    end
  end

  describe '#execute' do
    context 'when indexing is allowed' do
      it 'tracks the eligible records' do
        expect(::Elastic::ProcessBookkeepingService).to receive(:track!) do |*args|
          expect(args).to match_array(occurrence_refs)
        end

        service.execute
      end

      it 'only tracks records where maintaining_elasticsearch? is true' do
        allow_next_found_instance_of(Sbom::OccurrenceRef) do |instance|
          allow(instance).to receive(:maintaining_elasticsearch?).and_return(false)
        end

        expect(::Elastic::ProcessBookkeepingService).to receive(:track!) do |*args|
          expect(args).to be_empty
        end

        service.execute
      end

      it 'avoids n+1 DB queries' do
        control = ActiveRecord::QueryRecorder.new do
          described_class.new(relation).execute
        end

        group_2 = create(:group, :nested)
        project_2 = create(:project, namespace: group_2)
        occurrence_refs_2 = create_list(:sbom_occurrence_ref, 2, project: project_2)

        new_relation = Sbom::OccurrenceRef.id_in((occurrence_refs + occurrence_refs_2).map(&:id))

        expect do
          described_class.new(new_relation).execute
        end.to issue_same_number_of_queries_as(control).allow_skip_cache_inconsistency
      end

      context 'when a bookkeeping service is given' do
        subject(:service) do
          described_class.new(relation, bookkeeping_service: ::Elastic::ProcessInitialBookkeepingService)
        end

        it 'tracks the eligible records with the given service' do
          expect(::Elastic::ProcessBookkeepingService).not_to receive(:track!)
          expect(::Elastic::ProcessInitialBookkeepingService).to receive(:track!) do |*args|
            expect(args).to match_array(occurrence_refs)
          end

          service.execute
        end
      end
    end

    context 'when indexing is not allowed' do
      before do
        allow(::Search::Elastic::SbomOccurrenceRefIndexHelper).to receive(:indexing_allowed?).and_return(false)
      end

      it 'does not track anything' do
        expect(::Elastic::ProcessBookkeepingService).not_to receive(:track!)

        service.execute
      end
    end
  end
end
