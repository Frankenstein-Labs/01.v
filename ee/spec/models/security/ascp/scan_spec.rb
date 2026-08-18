# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Ascp::Scan, feature_category: :static_application_security_testing do
  describe 'associations' do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:base_scan).class_name('Security::Ascp::Scan').optional }
  end

  describe 'validations' do
    subject { build(:security_ascp_scan) }

    it { is_expected.to validate_presence_of(:project) }
    it { is_expected.to validate_presence_of(:scan_sequence) }
    it { is_expected.to validate_presence_of(:commit_sha) }
    it { is_expected.to define_enum_for(:scan_type).with_values(full: 0, incremental: 1) }
    it { is_expected.to validate_uniqueness_of(:scan_sequence).scoped_to(:project_id) }

    context 'when scan_type is incremental' do
      it 'requires base_scan_id' do
        scan = build(:security_ascp_scan, scan_type: :incremental, base_scan: nil)

        expect(scan).not_to be_valid
        expect(scan.errors[:base_scan_id]).to include("can't be blank")
      end

      it 'is valid when base_scan is present' do
        base_scan = create(:security_ascp_scan, :full)
        scan = build(:security_ascp_scan, scan_type: :incremental, base_scan: base_scan)

        expect(scan).to be_valid
      end
    end

    context 'when scan_type is full' do
      it 'does not require base_scan_id' do
        scan = build(:security_ascp_scan, scan_type: :full, base_scan: nil)

        expect(scan).to be_valid
      end
    end
  end

  describe 'scopes' do
    let_it_be(:project) { create(:project) }

    describe '.by_project' do
      it 'returns scans for the given project' do
        scan = create(:security_ascp_scan, project: project)
        create(:security_ascp_scan)

        expect(described_class.by_project(project.id)).to contain_exactly(scan)
      end
    end

    describe '.full_scans' do
      it 'returns only full scans' do
        full = create(:security_ascp_scan, :full, project: project)
        create(:security_ascp_scan, :incremental, project: project, base_scan: full)

        expect(described_class.by_project(project.id).full_scans).to contain_exactly(full)
      end
    end

    describe '.incremental_scans' do
      it 'returns only incremental scans' do
        full = create(:security_ascp_scan, :full, project: project)
        incremental = create(:security_ascp_scan, :incremental, project: project, base_scan: full)

        expect(described_class.by_project(project.id).incremental_scans).to contain_exactly(incremental)
      end
    end

    describe '.ordered' do
      it 'orders by scan_sequence descending' do
        scan1 = create(:security_ascp_scan, project: project, scan_sequence: 1)
        scan3 = create(:security_ascp_scan, project: project, scan_sequence: 3)
        scan2 = create(:security_ascp_scan, project: project, scan_sequence: 2)

        expect(described_class.ordered).to eq([scan3, scan2, scan1])
      end
    end
  end

  describe '#full? and #incremental?' do
    it 'returns true for full scans' do
      scan = build(:security_ascp_scan, :full)
      expect(scan.full?).to be true
      expect(scan.incremental?).to be false
    end

    it 'returns true for incremental scans' do
      scan = build(:security_ascp_scan, :incremental)
      expect(scan.full?).to be false
      expect(scan.incremental?).to be true
    end
  end

  context 'with loose foreign key on ascp_scans.project_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:project) }
      let_it_be(:model) { create(:security_ascp_scan, project: parent) }
    end
  end
end
