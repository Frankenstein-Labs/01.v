# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dependencies::ExportSerializers::Sbom::PipelineService, feature_category: :dependency_management do
  let_it_be(:pipeline) { create(:ee_ci_pipeline, :with_cyclonedx_report) }

  describe '#generate' do
    let(:dependency_list_export) { create(:dependency_list_export, project: nil, exportable: pipeline) }

    let(:service_class) { described_class.new(dependency_list_export, nil) }

    subject(:components) { Gitlab::Json.parse(service_class.generate)['components'] }

    before do
      stub_licensed_features(dependency_scanning: true)
    end

    context 'when the pipeline does not have cyclonedx reports' do
      let_it_be(:pipeline) { create(:ee_ci_pipeline) }

      it { is_expected.to be_empty }
    end

    context 'when the pipeline has cyclonedx reports' do
      it 'returns all the components' do
        expect(components.count).to be 441
      end

      it 'reports no validation errors during export' do
        expect(::Gitlab::AppLogger).not_to receive(:warn)
        service_class.generate
      end
    end

    context 'when a license_override_applicator is instantiated' do
      it 'passes the applicator to MergeReportsService' do
        expect(::Sbom::MergeReportsService).to receive(:new)
          .with(anything, hash_including(license_override_applicator: instance_of(Security::LicenseOverrideApplicator)))
          .and_call_original

        service_class.generate
      end
    end

    context 'when the merged report is not valid' do
      let(:invalid_report) do
        report = ::Gitlab::Ci::Reports::Sbom::Report.new
        report.sbom_attributes = { invalid: 'json' }
        report
      end

      before do
        allow_next_instance_of(::Sbom::MergeReportsService) do |service|
          allow(service).to receive(:execute).and_return(invalid_report)
        end
      end

      it 'logs a warning for invalid CycloneDX report' do
        expect(::Gitlab::AppLogger).to receive(:warn).with(
          hash_including(
            message: "SBoM report failed schema validation during export",
            errors: anything,
            pipeline_id: pipeline.id
          )
        )
        service_class.generate
      end

      it 'increments metric for invalid CycloneDX report' do
        counter = instance_double(Prometheus::Client::Counter)
        allow(Gitlab::Metrics).to receive(:counter).and_call_original

        expect(Gitlab::Metrics).to receive(:counter)
                                     .with(
                                       :sbom_schema_report_export_validation_failures_total,
                                       'Count of SBoM schema validation failures during report export'
                                     ).and_return(counter)

        expect(counter).to receive(:increment).with(
          project_id: pipeline.project_id,
          pipeline_id: pipeline.id
        )

        service_class.generate
      end

      it 'still returns the report' do
        expect(Gitlab::Json.parse(service_class.generate)).to include("components")
      end
    end
  end
end
