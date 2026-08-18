# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::OccurrenceRef, feature_category: :dependency_management do
  describe 'associations' do
    it { is_expected.to belong_to(:project).class_name('Project').inverse_of(:sbom_occurrence_refs) }

    it 'belongs to an occurrence' do
      is_expected.to belong_to(:occurrence)
        .class_name('Sbom::Occurrence')
        .with_foreign_key(:sbom_occurrence_id)
        .inverse_of(:occurrence_refs)
    end

    it 'belongs to a tracked context' do
      is_expected.to belong_to(:tracked_context)
        .class_name('Security::ProjectTrackedContext')
        .with_foreign_key(:security_project_tracked_context_id)
        .inverse_of(:sbom_occurrence_refs)
    end

    it { is_expected.to belong_to(:pipeline).class_name('Ci::Pipeline').inverse_of(:sbom_occurrence_refs).optional }

    describe '#pipeline' do
      it_behaves_like 'a partition-pruned pipeline association' do
        # .reload clears the :pipeline target cached by the attribute writer.
        let(:related_resource) { create(:sbom_occurrence_ref, pipeline: pipeline).reload }
      end
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:commit_sha) }
    it { is_expected.to validate_presence_of(:sbom_occurrence_id) }
    it { is_expected.to validate_presence_of(:security_project_tracked_context_id) }
    it { is_expected.to validate_presence_of(:project_id) }
    it { is_expected.to validate_length_of(:commit_sha).is_at_most(64) }
  end

  describe 'scopes' do
    describe '.by_occurrence' do
      let_it_be(:occurrence) { create(:sbom_occurrence) }
      let_it_be(:occurrence_ref) { create(:sbom_occurrence_ref, occurrence: occurrence) }

      it 'returns occurrence refs for the given occurrence ID' do
        expect(described_class.by_occurrence(occurrence.id)).to include(occurrence_ref)
      end
    end

    describe '.by_tracked_context' do
      let_it_be(:tracked_context) { create(:security_project_tracked_context) }
      let_it_be(:occurrence_ref) { create(:sbom_occurrence_ref, tracked_context: tracked_context) }

      it 'returns occurrence refs for the given tracked context ID' do
        expect(described_class.by_tracked_context(tracked_context.id)).to include(occurrence_ref)
      end
    end

    describe '.by_project' do
      let_it_be(:project) { create(:project) }
      let_it_be(:occurrence_ref) { create(:sbom_occurrence_ref, project: project) }

      it 'returns occurrence refs for the given project ID' do
        expect(described_class.by_project(project.id)).to include(occurrence_ref)
      end
    end
  end

  describe '.with_pipeline' do
    let_it_be(:pipeline) { create(:ci_pipeline) }
    let_it_be(:occurrence_ref) { create(:sbom_occurrence_ref, pipeline: pipeline) }

    it 'associates with the pipeline correctly' do
      expect(occurrence_ref.pipeline).to be_present
    end
  end

  describe 'loose foreign key on sbom_occurrence_refs.pipeline_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let!(:parent) { create(:ci_pipeline) }
      let!(:model) { create(:sbom_occurrence_ref, pipeline: parent) }
    end
  end

  context 'with loose foreign key on sbom_occurrence_refs.project_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:project) }
      let_it_be(:model) { create(:sbom_occurrence_ref, project: parent) }
    end
  end
end
