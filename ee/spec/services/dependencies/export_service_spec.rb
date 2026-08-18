# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dependencies::ExportService, feature_category: :dependency_management do
  include ::Sbom::Exporters::WriteBlob

  describe '.execute' do
    let(:dependency_list_export) { instance_double(Dependencies::DependencyListExport) }

    subject(:execute) { described_class.execute(dependency_list_export) }

    it 'instantiates a service object and sends execute message to it' do
      expect_next_instance_of(described_class, dependency_list_export) do |service_object|
        expect(service_object).to receive(:execute)
      end

      execute
    end
  end

  describe '#execute' do
    let(:created_status) { 0 }
    let(:running_status) { 1 }
    let(:finished_status) { 2 }
    let(:status) { created_status }
    let(:service_class) { described_class.new(dependency_list_export) }
    let(:export_content) { dependency_list_export.reload.file.read }

    subject(:execute) { described_class.new(dependency_list_export).execute }

    before do
      allow(Time).to receive(:current).and_return(Time.new(2023, 11, 14, 0, 0, 0, '+00:00'))
    end

    shared_examples_for 'writes export using exporter' do
      context 'when the export is not in `created` status' do
        let(:status) { running_status }

        it 'does not run the logic' do
          expect { execute }.not_to change { dependency_list_export.reload.file.file }.from(nil)
        end
      end

      context 'when the export is in `created` status' do
        let(:status) { created_status }

        before do
          allow(dependency_list_export).to receive(:schedule_export_deletion)
        end

        context 'when the export fails' do
          before do
            allow_next_instance_of(exporter_class, dependency_list_export, anything) do |instance|
              allow(instance).to receive(:generate).and_raise('Foo')
            end
          end

          it 'propagates the error, resets the status of the export, and does not schedule deletion job' do
            expect { execute }.to raise_error('Foo')
                             .and not_change { dependency_list_export.status }

            expect(dependency_list_export).not_to have_received(:schedule_export_deletion)
          end
        end

        context 'when the export succeeds' do
          before do
            allow_next_instance_of(exporter_class, dependency_list_export, anything) do |instance|
              allow(instance).to receive(:generate) { |&block| write_blob('"Foo"', &block) }
            end
          end

          it 'marks the export as finished' do
            expect { execute }.to change { dependency_list_export.status }.from(created_status).to(finished_status)
          end

          it 'attaches the file to export' do
            expect { execute }.to change { dependency_list_export.file.read }.from(nil).to('"Foo"')
            expect(dependency_list_export.file.filename).to eq(expected_filename)
          end

          it 'schedules the export deletion' do
            execute

            expect(dependency_list_export).to have_received(:schedule_export_deletion)
          end
        end
      end
    end

    context 'when the exportable is a project' do
      let_it_be(:project) { create(:project) }
      let_it_be(:container_scanning_occurrence) { create(:sbom_occurrence, :os_occurrence, project: project) }
      let_it_be(:registry_occurrence) { create(:sbom_occurrence, :registry_occurrence, project: project) }

      let(:export_type) { :dependency_list }
      let(:dependency_list_export) do
        create(:dependency_list_export, project: nil, exportable: project, status: status, export_type: export_type)
      end

      let(:filename_prefix) do
        [
          'project_',
          project.id,
          '_dependencies_',
          Time.current.utc.strftime('%FT%H%M')
        ].join
      end

      let(:expected_filename) do
        [
          filename_prefix,
          '.',
          'json'
        ].join
      end

      it 'does not include registry occurrences' do
        execute

        expect(export_content).to include(container_scanning_occurrence.name)
        expect(export_content).not_to include(registry_occurrence.name)
      end

      context 'with different export types' do
        using RSpec::Parameterized::TableSyntax

        where(:export_type, :exporter_class, :expected_extension) do
          :dependency_list    | ::Sbom::Exporters::DependencyListService     | 'json'
          :csv                | ::Sbom::Exporters::CsvService                | 'csv'
          :cyclonedx_1_6_json | ::Sbom::Exporters::Cyclonedx::V16JsonService | 'cdx.json'
        end

        with_them do
          it_behaves_like 'writes export using exporter' do
            let(:expected_filename) { "#{filename_prefix}.#{expected_extension}" }
          end
        end
      end
    end

    context 'when the exportable is a group' do
      let_it_be(:group) { create(:group) }
      let_it_be(:project) { create(:project, group: group) }
      let_it_be(:archived_project) { create(:project, :archived, group: group) }
      let_it_be(:occurrence) { create(:sbom_occurrence, project: project) }
      let_it_be(:archived_occurrence) { create(:sbom_occurrence, project: archived_project) }

      let(:export_type) { :json_array }

      let(:expected_filename) do
        [
          'group_',
          group.id,
          '_dependencies_',
          Time.current.utc.strftime('%FT%H%M'),
          '.',
          'json'
        ].join
      end

      let(:dependency_list_export) do
        create(:dependency_list_export, project: nil, exportable: group, status: status, export_type: export_type)
      end

      it 'does not include occurrences from archived projects' do
        execute

        expect(export_content).to include(occurrence.name)
        expect(export_content).not_to include(archived_occurrence.name)
      end

      it_behaves_like 'writes export using exporter' do
        let(:exporter_class) { ::Sbom::Exporters::JsonArrayService }
      end
    end

    context 'when the exportable is a pipeline' do
      let_it_be(:pipeline) { create(:ci_pipeline) }

      let(:expected_filename) do
        [
          'pipeline_',
          pipeline.id,
          '_dependencies_',
          Time.current.utc.strftime('%FT%H%M'),
          '.cdx.json'
        ].join
      end

      let(:dependency_list_export) do
        create(:dependency_list_export, {
          project: nil,
          exportable: pipeline,
          status: status,
          export_type: :sbom
        })
      end

      it_behaves_like 'writes export using exporter' do
        let(:exporter_class) { ::Dependencies::ExportSerializers::Sbom::PipelineService }
      end
    end
  end
end
