# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dependencies::DependencyListExport::Part, feature_category: :dependency_management do
  describe 'associations' do
    it { is_expected.to belong_to(:dependency_list_export).class_name('Dependencies::DependencyListExport') }
    it { is_expected.to belong_to(:organization).class_name('Organizations::Organization') }
    it { is_expected.to belong_to(:first_record).class_name('Sbom::Occurrence') }
    it { is_expected.to belong_to(:last_record).class_name('Sbom::Occurrence') }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:start_id) }
    it { is_expected.to validate_presence_of(:end_id) }
  end

  describe '#retrieve_upload' do
    let(:export_part) { create(:dependency_list_export_part, :exported) }
    let(:relative_path) { export_part.file.url[1..] }

    subject { export_part.retrieve_upload(export_part, relative_path) }

    it { is_expected.to be_present }
  end

  describe '#sbom_occurrences' do
    let(:group) { create(:group) }
    let(:project) { create(:project, group: group) }
    let(:export) { create(:dependency_list_export, exportable: group, project: nil) }
    let(:occurrence) { create(:sbom_occurrence, project: project) }
    let(:archived_occurrence) { create(:sbom_occurrence, project: project, archived: true) }
    let(:export_part) do
      create(:dependency_list_export_part,
        dependency_list_export: export,
        start_id: occurrence.id,
        end_id: archived_occurrence.id)
    end

    subject(:sbom_occurrences) { export_part.sbom_occurrences }

    before do
      # Creating another occurrence which is not in the range of occurrences of export part
      create(:sbom_occurrence, project: project)
    end

    it 'returns only the related sbom_occurrences for the export part' do
      expect(sbom_occurrences).to contain_exactly(occurrence)
    end
  end

  context 'with loose foreign key on dependency_list_export_parts.organization_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:organization) }
      let_it_be(:model) { create(:dependency_list_export_part, organization: parent) }

      before do
        parent.users.delete_all
      end
    end
  end

  describe '#uploads_sharding_key' do
    it 'returns organization_id' do
      organization = build_stubbed(:organization)
      export_part = build_stubbed(:dependency_list_export_part, organization: organization)

      expect(export_part.uploads_sharding_key).to eq(organization_id: organization.id)
    end
  end
end
