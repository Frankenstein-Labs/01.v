# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::AnalyzerProjectStatus, feature_category: :security_asset_inventories do
  describe 'associations' do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:build).optional }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:analyzer_type) }
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_presence_of(:traversal_ids) }

    it { is_expected.to validate_numericality_of(:consecutive_absence_count).is_greater_than_or_equal_to(0) }
    it { is_expected.not_to allow_value(nil).for(:consecutive_absence_count) }
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:analyzer_type).with_values(Enums::Security.analyzer_types_for_status) }
    it { is_expected.to define_enum_for(:status).with_values(Enums::Security.analyzer_statuses) }
  end

  describe 'scopes' do
    let_it_be(:project) { create(:project) }
    let_it_be(:sast_analyzer) { create(:analyzer_project_status, project: project) }
    let_it_be(:dast_analyzer) { create(:analyzer_project_status, :dast, project: project) }
    let_it_be(:container_scanning_analyzer) { create(:analyzer_project_status, :container_scanning, project: project) }
    let_it_be(:another_analyzer_status) { create(:analyzer_project_status, :secret_detection) }
    let_it_be(:archived_project) { create(:project, archived: true) }
    let_it_be(:archived_sast_analyzer) { create(:analyzer_project_status, project: archived_project, archived: true) }

    describe '.by_projects' do
      subject { described_class.by_projects(project) }

      it 'returns analyzer statuses for the specified project only' do
        is_expected.to contain_exactly(sast_analyzer, dast_analyzer, container_scanning_analyzer)
      end
    end

    describe '.without_types' do
      subject { described_class.without_types(excluded_types) }

      context 'when excluding a single type' do
        let(:excluded_types) { :sast }

        it 'returns analyzers of all types except the excluded one' do
          is_expected.to include(dast_analyzer, container_scanning_analyzer, another_analyzer_status)
          is_expected.not_to include(sast_analyzer)
        end
      end

      context 'when excluding multiple types' do
        let(:excluded_types) { [:sast, :dast] }

        it 'returns analyzers of all types except the excluded ones' do
          is_expected.to include(container_scanning_analyzer, another_analyzer_status)
          is_expected.not_to include(sast_analyzer, dast_analyzer)
        end
      end

      context 'when not excluding any types' do
        let(:excluded_types) { [] }

        it 'returns all analyzers' do
          is_expected.to include(sast_analyzer, dast_analyzer, container_scanning_analyzer, another_analyzer_status)
        end
      end
    end

    describe '.unarchived' do
      subject { described_class.unarchived }

      it 'returns unarchived analyzer statuses only' do
        is_expected.to not_include(archived_sast_analyzer)
      end
    end
  end

  context 'with loose foreign key on analyzer_project_statuses.project_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:project) }
      let_it_be(:model) { create(:analyzer_project_status, project: parent) }
    end

    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:ci_build) }
      let_it_be(:model) { create(:analyzer_project_status, build: parent) }
    end
  end
end
