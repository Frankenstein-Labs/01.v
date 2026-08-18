# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Ingestion::Tasks::MatchAscpComponents, feature_category: :static_application_security_testing do
  describe '#execute' do
    let_it_be(:pipeline) { create(:ci_pipeline) }
    let_it_be(:project) { pipeline.project }
    let_it_be(:tracked_context) do
      create(:security_project_tracked_context, :default, :tracked, project: project)
    end

    let_it_be(:non_default_tracked_context) do
      create(:security_project_tracked_context, :tracked, context_name: 'dev', project: project)
    end

    let_it_be(:new_map_1) { create(:finding_map, :new_record, pipeline: pipeline, tracked_context: tracked_context) }
    let_it_be(:new_map_2) { create(:finding_map, :new_record, pipeline: pipeline, tracked_context: tracked_context) }
    let_it_be(:existing_map) do
      create(:finding_map, :with_finding, pipeline: pipeline, tracked_context: tracked_context)
    end

    let_it_be(:non_default_map) do
      create(:finding_map, :new_record, pipeline: pipeline, tracked_context: non_default_tracked_context)
    end

    let_it_be(:new_map_without_file) do
      report_finding = create(:ci_reports_security_finding, original_data: { location: {} })
      create(:finding_map, :new_record, pipeline: pipeline, tracked_context: tracked_context,
        report_finding: report_finding)
    end

    let_it_be(:scan) { create(:security_ascp_scan, project: project) }

    let(:finding_maps) { [new_map_1, new_map_2, existing_map, non_default_map] }

    subject(:execute) { SecApplicationRecord.transaction { described_class.new(pipeline, finding_maps).execute } }

    before do
      stub_licensed_features(security_dashboard: true)
      allow(Vulnerabilities::UpdateAscpAssociationsBatchWorker).to receive(:perform_async)
    end

    it 'enqueues matching for new default-branch findings only' do
      execute

      expect(Vulnerabilities::UpdateAscpAssociationsBatchWorker).to have_received(:perform_async)
        .with(project.id, match_array([new_map_1.finding_id, new_map_2.finding_id]))
    end

    it 'enqueues a single job for the whole slice' do
      execute

      expect(Vulnerabilities::UpdateAscpAssociationsBatchWorker).to have_received(:perform_async).once
    end

    it 'schedules the job with the project context' do
      expect(Gitlab::ApplicationContext).to receive(:with_context).with(project: project).and_call_original

      execute

      expect(Vulnerabilities::UpdateAscpAssociationsBatchWorker).to have_received(:perform_async)
    end

    context 'when a new finding has no file location' do
      let(:finding_maps) { [new_map_1, new_map_without_file] }

      it 'enqueues only the findings that have a file location' do
        execute

        expect(Vulnerabilities::UpdateAscpAssociationsBatchWorker).to have_received(:perform_async)
          .with(project.id, [new_map_1.finding_id])
      end
    end

    context 'when no new finding has a file location' do
      let(:finding_maps) { [new_map_without_file] }

      it 'does not enqueue matching' do
        execute

        expect(Vulnerabilities::UpdateAscpAssociationsBatchWorker).not_to have_received(:perform_async)
      end
    end

    context 'when the project has no ASCP scan' do
      # The scan check short-circuits before the finding maps are read, so they
      # can be reused against a pipeline whose project has no scan.
      let_it_be(:pipeline_without_scan) { create(:ci_pipeline) }

      subject(:execute) do
        SecApplicationRecord.transaction { described_class.new(pipeline_without_scan, finding_maps).execute }
      end

      it 'does not enqueue matching' do
        execute

        expect(Vulnerabilities::UpdateAscpAssociationsBatchWorker).not_to have_received(:perform_async)
      end
    end

    context 'when the security_dashboard license is not available' do
      before do
        stub_licensed_features(security_dashboard: false)
      end

      it 'does not enqueue matching' do
        execute

        expect(Vulnerabilities::UpdateAscpAssociationsBatchWorker).not_to have_received(:perform_async)
      end
    end

    context 'when the feature flag is disabled' do
      before do
        stub_feature_flags(ascp_component_vulnerability_association: false)
      end

      it 'does not enqueue matching' do
        execute

        expect(Vulnerabilities::UpdateAscpAssociationsBatchWorker).not_to have_received(:perform_async)
      end
    end
  end
end
