# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dependencies::CreateExportService, feature_category: :dependency_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :public, group: group) }
  let_it_be(:user) { create(:user) }

  let(:params) { {} }

  subject(:result) { described_class.new(project, user, params).execute }

  describe '#execute' do
    context 'when project is nil' do
      let_it_be(:project) { nil }

      it 'does not schedule a Dependencies::ExportWorker job' do
        expect(Dependencies::ExportWorker).not_to receive(:perform_async)

        result
      end

      it 'returns errors' do
        expect(result).not_to be_success
        expect(result.message).to eq(['Only one exportable is required'])
      end
    end

    it 'returns a new instance of dependency_list_export' do
      expect(result).to be_success

      export = result.payload[:dependency_list_export]

      expect(export).to be_a(Dependencies::DependencyListExport)
      expect(export.send_email).to be(false)
      expect(export.export_type).to eq('dependency_list')
    end

    context 'when send_email is true' do
      let(:params) { { send_email: true } }

      it 'sets column on model' do
        expect(result).to be_success

        expect(result.payload[:dependency_list_export].send_email).to be(true)
      end
    end

    describe 'export_type' do
      where(:export_type) { %i[dependency_list sbom json_array csv cyclonedx_1_6_json] }

      let(:params) { { export_type: export_type } }

      with_them do
        it 'creates export with correct type' do
          expect(result).to be_success

          expect(result.payload[:dependency_list_export].export_type).to eq(export_type.to_s)
        end
      end
    end

    it 'schedules a Dependencies::ExportWorker job' do
      expect(Dependencies::ExportWorker).to receive(:perform_async)

      result
    end

    context 'when export is for a project' do
      where(:export_type) { %i[dependency_list csv] }
      let(:params) { { export_type: export_type } }

      with_them do
        it "triggers an internal event" do
          expect { result }.to trigger_internal_events('create_dependency_list_export').with(
            namespace: group,
            project: project,
            user: user,
            additional_properties: {
              label: export_type.to_s,
              property: 'Project'
            }
          )
        end
      end
    end

    context 'when export is for a group' do
      where(:export_type) { %i[json_array csv] }
      let(:params) { { export_type: export_type } }

      subject(:result) { described_class.new(group, user, params).execute }

      with_them do
        it "triggers an internal event" do
          expect { result }.to trigger_internal_events('create_dependency_list_export').with(
            namespace: group,
            user: user,
            additional_properties: {
              label: export_type.to_s,
              property: 'Group'
            }
          )
        end
      end
    end

    context 'when export is for a pipeline' do
      let_it_be(:pipeline) { build_stubbed(:ci_pipeline, project: project) }

      let(:export_type) { :sbom }
      let(:params) { { export_type: export_type } }

      subject(:result) { described_class.new(pipeline, user, params).execute }

      it "triggers an internal event" do
        expect { result }.to trigger_internal_events('create_dependency_list_export').with(
          project: project,
          namespace: group,
          user: user,
          additional_properties: {
            label: export_type.to_s,
            property: 'Ci::Pipeline'
          }
        )
      end
    end
  end
end
