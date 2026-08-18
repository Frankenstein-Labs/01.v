# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::Ingestion::IngestReportService, feature_category: :dependency_management do
  let_it_be(:num_components) { 283 }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :public, group: group) }
  let_it_be(:tracked_context) { create(:security_project_tracked_context, project: project) }

  let!(:pipeline) { build_stubbed(:ci_pipeline, project: project) }
  let!(:sbom_report) { create(:ci_reports_sbom_report, num_components: num_components) }

  let(:sequencer) { ::Ingestion::Sequencer.new }
  let(:source_sequencer) { ::Ingestion::Sequencer.new(start: num_components + 1) }

  before do
    allow(::Security::ProjectTrackedContexts::FindOrCreateService).to receive(:from_pipeline).with(pipeline)
      .and_return(
        instance_double(
          ::Security::ProjectTrackedContexts::FindOrCreateService,
          execute: ServiceResponse.success(payload: { tracked_context: tracked_context })
        )
      )
  end

  subject(:execute) { described_class.execute(pipeline, sbom_report) }

  describe '#execute' do
    shared_examples_for 'logging the dependency graph scheduling status' do |message|
      before do
        allow(::Gitlab::AppLogger).to receive(:info)
      end

      context 'when the project belongs to a group' do
        it 'logs the expected message' do
          execute

          expect(::Gitlab::AppLogger).to have_received(:info).with(
            message: message,
            project: project.name,
            project_id: project.id,
            namespace: group.name,
            namespace_id: group.id,
            cache_key: graph_cache_key.key
          )
        end
      end

      context 'when the project belongs to a namespace' do
        let(:project) { create(:project, :public) }

        it 'logs the expected message' do
          execute

          expect(::Gitlab::AppLogger).to have_received(:info).with(
            message: message,
            project: project.name,
            project_id: project.id,
            namespace: project.namespace.name,
            namespace_id: project.namespace.id,
            cache_key: graph_cache_key.key
          )
        end
      end
    end

    before do
      allow(::Sbom::Ingestion::IngestReportSliceService).to receive(:execute)
        .and_wrap_original do |_, _, occurrence_maps|
        {
          occurrence_ids: occurrence_maps.map { sequencer.next },
          source_ids: occurrence_maps.map { source_sequencer.next }
        }
      end
    end

    it 'executes IngestReportSliceService in batches' do
      full_batches, remainder = num_components.divmod(described_class::BATCH_SIZE)

      expect(::Sbom::Ingestion::IngestReportSliceService).to receive(:execute)
        .with(pipeline, an_object_having_attributes(size: described_class::BATCH_SIZE)).exactly(full_batches).times
      expect(::Sbom::Ingestion::IngestReportSliceService).to receive(:execute)
        .with(pipeline, an_object_having_attributes(size: remainder)).once

      result = execute
      all_occurrence_ids = result.flat_map { |batch| batch[:occurrence_ids] }
      all_source_ids = result.flat_map { |batch| batch[:source_ids] }

      expect(all_occurrence_ids).to match_array(sequencer.range)
      expect(all_source_ids).to match_array(source_sequencer.range)
    end

    it 'enqueues Sbom::BuildDependencyGraphWorker' do
      expect(::Sbom::BuildDependencyGraphWorker).to receive(:perform_async).with(pipeline.project_id)

      execute
    end

    context 'when dependency_paths feature flag is disabled' do
      before do
        stub_feature_flags(dependency_paths: false)
      end

      it 'does not enqueue any jobs' do
        expect(::Sbom::BuildDependencyGraphWorker).not_to receive(:perform_async)

        execute
      end
    end

    context 'when this report has already been ingested' do
      let(:graph_cache_key) { instance_double(Sbom::Ingestion::DependencyGraphCacheKey, key: "key_value") }

      before do
        allow(Rails.cache)
          .to receive(:read)
          .with("key_value")
          .and_return({ pipeline_id: pipeline.id })

        allow(Sbom::Ingestion::DependencyGraphCacheKey)
          .to receive(:new)
          .with(pipeline.project, sbom_report)
          .and_return(graph_cache_key)
      end

      it 'does not recreate the graph' do
        expect(::Sbom::BuildDependencyGraphWorker).not_to receive(:perform_async)
        execute
      end

      it 'does not update the cache' do
        expect(Rails.cache).not_to receive(:write)
        execute
      end

      it_behaves_like 'logging the dependency graph scheduling status', 'Graph already built'
    end

    context 'when this report has not been ingested' do
      let(:graph_cache_key) { instance_double(Sbom::Ingestion::DependencyGraphCacheKey, key: "key_value") }

      before do
        allow(Rails.cache)
          .to receive(:read)
          .with("key_value")
          .and_return(nil)

        allow(Sbom::Ingestion::DependencyGraphCacheKey)
          .to receive(:new)
          .with(pipeline.project, sbom_report)
          .and_return(graph_cache_key)
      end

      it 'recreates the graph' do
        expect(::Sbom::BuildDependencyGraphWorker).to receive(:perform_async).with(project.id)
        execute
      end

      it 'updates the cache' do
        expect(Rails.cache)
          .to receive(:write)
          .with(graph_cache_key.key, { pipeline_id: pipeline.id }, expires_in: described_class::CACHE_EXPIRATION_TIME)
        execute
      end

      it_behaves_like 'logging the dependency graph scheduling status', 'Building dependency graph'
    end
  end
end
