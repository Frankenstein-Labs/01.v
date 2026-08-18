# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::Ingestion::IngestReportsService, feature_category: :dependency_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :public, :repository, group: group) }
  let_it_be(:pipeline) { build_stubbed(:ci_pipeline, project: project) }
  let_it_be(:reports) { create_list(:ci_reports_sbom_report, 4) }

  let(:wrapper) { instance_double('Gitlab::Ci::Reports::Sbom::Reports') }

  subject(:execute) { described_class.execute(pipeline) }

  before do
    allow(wrapper).to receive(:reports).and_return(reports)
    allow(pipeline).to receive(:sbom_reports).with(self_and_project_descendants: true).and_return(wrapper)
  end

  describe '#execute' do
    context 'when lease is taken' do
      include ExclusiveLeaseHelpers

      let(:lease_key) { Sbom::Ingestion.project_lease_key(pipeline.project.id) }

      before do
        stub_const("#{described_class}::LEASE_TRY_AFTER", 0.01)
        stub_exclusive_lease_taken(lease_key)
      end

      it 'does not permit parallel execution on the same project' do
        expect { execute }.to raise_error(Gitlab::ExclusiveLeaseHelpers::FailedToObtainLockError)
      end
    end

    context 'when a report is invalid' do
      let_it_be(:invalid_report) { create(:ci_reports_sbom_report, :invalid) }
      let_it_be(:reports) { [invalid_report] + create_list(:ci_reports_sbom_report, 4) }

      it 'does not process the invalid report' do
        execute

        error_messages = pipeline
          .sbom_report_ingestion_errors
          .flatten
          .pluck("message")

        expect(error_messages).to eq(invalid_report.errors.flatten)
      end
    end

    context 'when a report source is container_scanning_for_registry' do
      let_it_be(:registry_sources) { create(:ci_reports_sbom_source, :container_scanning_for_registry) }
      let_it_be(:reports) { [create(:ci_reports_sbom_report, source: registry_sources)] }

      it 'uses ContainerScanningForRegistry strategy' do
        expect_next_instance_of(Sbom::Ingestion::ExecutionStrategy::ContainerScanningForRegistry) do |instance|
          expect(instance).to receive(:execute)
        end

        execute
      end
    end

    context 'when there are no container_scanning_for_registry sources' do
      it 'uses Default strategy' do
        expect_next_instance_of(Sbom::Ingestion::ExecutionStrategy::Default) do |instance|
          expect(instance).to receive(:execute)
        end

        execute
      end
    end
  end
end
