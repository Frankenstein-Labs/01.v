# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::AnalyzerGroupStatusFinder, feature_category: :security_asset_inventories do
  describe '#execute' do
    let(:empty_group) { create(:group) }
    let(:sast_group) { create(:group) }
    let!(:sast_status) { create(:analyzer_namespace_status, namespace: sast_group, success: 1) }

    context 'with no statuses recorded' do
      it 'returns all analyzer statuses' do
        expect(execute(empty_group).count).to eq(Enums::Security.analyzer_types.count)
      end
    end

    context 'with existing statuses' do
      it 'returns the existing statuses along with the placeholder statuses' do
        sast_group_result = execute(sast_group)

        expect(sast_group_result.count).to eq(Enums::Security.analyzer_types.count)
        expect(sast_group_result.sum(&:success)).to eq(1)
      end
    end

    def execute(group)
      described_class.new(group).execute
    end
  end
end
