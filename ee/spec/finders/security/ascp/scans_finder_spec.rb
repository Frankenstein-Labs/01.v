# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Ascp::ScansFinder, feature_category: :static_application_security_testing do
  let_it_be(:project) { create(:project) }
  let_it_be(:full_scan) { create(:security_ascp_scan, :full, project: project) }
  let_it_be(:incremental_scan) do
    create(:security_ascp_scan, :incremental, project: project, base_scan: full_scan)
  end

  describe '#execute' do
    subject(:finder) { described_class.new(project: project, params: params) }

    context 'without filters' do
      let(:params) { {} }

      it 'returns all scans ordered by sequence descending' do
        result = finder.execute
        expect(result).to eq([incremental_scan, full_scan])
      end
    end

    context 'with scan_type filter' do
      context 'when filtering for full scans' do
        let(:params) { { scan_type: 'full' } }

        it 'returns only full scans' do
          expect(finder.execute).to contain_exactly(full_scan)
        end
      end

      context 'when filtering for incremental scans' do
        let(:params) { { scan_type: 'incremental' } }

        it 'returns only incremental scans' do
          expect(finder.execute).to contain_exactly(incremental_scan)
        end
      end
    end
  end
end
