# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::Ingestion::Tasks::IngestOccurrenceRefs, feature_category: :dependency_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:pipeline) { create(:ci_pipeline, project: project, ref: 'main') }
  let_it_be(:occurrence) { create(:sbom_occurrence, project: project, pipeline: pipeline) }
  let_it_be(:tracked_context) do
    create(:security_project_tracked_context,
      :tracked,
      project: project,
      context_name: pipeline.ref,
      context_type: :branch)
  end

  let(:occurrence_map) do
    build(:sbom_occurrence_map, security_project_tracked_context: tracked_context).tap do |map|
      map.occurrence_id = occurrence.id
      map.occurrence_changed = true
    end
  end

  let(:occurrence_maps) { [occurrence_map] }

  subject(:task) { described_class.new(pipeline, occurrence_maps) }

  describe '#execute' do
    it 'creates occurrence refs' do
      expect { task.execute }.to change { Sbom::OccurrenceRef.count }.by(1)

      ref = Sbom::OccurrenceRef.last
      expect(ref.sbom_occurrence_id).to eq(occurrence.id)
      expect(ref.security_project_tracked_context_id).to eq(tracked_context.id)
      expect(ref.pipeline).to eq(pipeline)
      expect(ref.project).to eq(project)
      expect(ref.commit_sha).to eq(pipeline.sha)
    end

    it 'flags the occurrence maps whose refs were created' do
      task.execute

      expect(occurrence_map.ref_created).to be(true)
    end

    context 'when multiple occurrence maps exist' do
      let(:occurrence2) { create(:sbom_occurrence, project: project, pipeline: pipeline) }
      let(:occurrence_map2) do
        build(:sbom_occurrence_map, security_project_tracked_context: tracked_context).tap do |map|
          map.occurrence_id = occurrence2.id
          map.occurrence_changed = true
        end
      end

      let(:occurrence_maps) { [occurrence_map, occurrence_map2] }

      it 'creates occurrence refs for all valid maps' do
        expect { task.execute }.to change { Sbom::OccurrenceRef.count }.by(2)

        refs = Sbom::OccurrenceRef.last(2)
        expect(refs.map(&:sbom_occurrence_id)).to match_array([occurrence.id, occurrence2.id])
        expect(refs.map(&:tracked_context)).to all(eq(tracked_context))
      end
    end

    context 'when an occurrence ref already exists for the (occurrence, tracked_context) pair' do
      let_it_be(:older_pipeline) { create(:ci_pipeline, project: project, ref: 'main') }

      let_it_be(:existing_ref) do
        create(:sbom_occurrence_ref,
          occurrence: occurrence,
          tracked_context: tracked_context,
          pipeline: older_pipeline,
          project: project,
          commit_sha: 'oldsha0000000000000000000000000000000000')
      end

      context 'and the occurrence changed in this run' do
        before do
          occurrence_map.occurrence_changed = true
        end

        it 'updates the existing ref instead of creating a new one', :aggregate_failures do
          expect { task.execute }.not_to change { Sbom::OccurrenceRef.count }

          existing_ref.reload
          expect(existing_ref.sbom_occurrence_id).to eq(occurrence.id)
          expect(existing_ref.security_project_tracked_context_id).to eq(tracked_context.id)
          expect(existing_ref.pipeline_id).to eq(pipeline.id)
          expect(existing_ref.project_id).to eq(project.id)
          expect(existing_ref.commit_sha).to eq(pipeline.sha)
        end
      end

      context 'and the occurrence did not change in this run' do
        before do
          occurrence_map.occurrence_changed = false
        end

        it 'does not modify the existing ref', :aggregate_failures do
          expect { task.execute }.not_to change { Sbom::OccurrenceRef.count }

          existing_ref.reload
          expect(existing_ref.pipeline_id).to eq(older_pipeline.id)
          expect(existing_ref.commit_sha).to eq('oldsha0000000000000000000000000000000000')
        end
      end
    end

    context 'when the occurrence did not change and no ref exists' do
      before do
        occurrence_map.occurrence_changed = false
      end

      it 'creates an occurrence ref for the new (occurrence, tracked_context) pair', :aggregate_failures do
        expect { task.execute }.to change { Sbom::OccurrenceRef.count }.by(1)

        ref = Sbom::OccurrenceRef.last
        expect(ref.sbom_occurrence_id).to eq(occurrence.id)
        expect(ref.security_project_tracked_context_id).to eq(tracked_context.id)
        expect(ref.pipeline_id).to eq(pipeline.id)
        expect(ref.project_id).to eq(project.id)
        expect(ref.commit_sha).to eq(pipeline.sha)
      end
    end

    context 'when some occurrence maps changed and others did not but have no existing ref' do
      let(:occurrence2) { create(:sbom_occurrence, project: project, pipeline: pipeline) }
      let(:occurrence_map2) do
        build(:sbom_occurrence_map, security_project_tracked_context: tracked_context).tap do |map|
          map.occurrence_id = occurrence2.id
          map.occurrence_changed = false
        end
      end

      let(:occurrence_maps) { [occurrence_map, occurrence_map2] }

      before do
        occurrence_map.occurrence_changed = true
      end

      it 'creates refs for both the changed map and the unchanged map without an existing ref' do
        expect { task.execute }.to change { Sbom::OccurrenceRef.count }.by(2)

        expect(Sbom::OccurrenceRef.pluck(:sbom_occurrence_id))
          .to match_array([occurrence.id, occurrence2.id])
      end
    end

    context 'when occurrence did not change and a ref exists for a different tracked_context' do
      let_it_be(:other_tracked_context) do
        create(:security_project_tracked_context,
          :tracked,
          project: project,
          context_name: 'other-branch',
          context_type: :branch)
      end

      let_it_be(:unrelated_ref) do
        create(:sbom_occurrence_ref,
          occurrence: occurrence,
          tracked_context: other_tracked_context,
          pipeline: pipeline,
          project: project,
          commit_sha: 'unrelated00000000000000000000000000000000')
      end

      before do
        occurrence_map.occurrence_changed = false
      end

      it 'creates a ref for the current tracked_context and leaves the unrelated ref untouched', :aggregate_failures do
        expect { task.execute }.to change { Sbom::OccurrenceRef.count }.by(1)

        new_ref = Sbom::OccurrenceRef.find_by(
          sbom_occurrence_id: occurrence.id,
          security_project_tracked_context_id: tracked_context.id
        )
        expect(new_ref).to be_present
        expect(new_ref.commit_sha).to eq(pipeline.sha)

        unrelated_ref.reload
        expect(unrelated_ref.commit_sha).to eq('unrelated00000000000000000000000000000000')
        expect(unrelated_ref.security_project_tracked_context_id).to eq(other_tracked_context.id)
      end
    end

    context 'when no occurrence maps exist' do
      let(:occurrence_maps) { [] }

      it 'does not create any occurrence refs' do
        expect { task.execute }.not_to change { Sbom::OccurrenceRef.count }
      end
    end
  end
end
