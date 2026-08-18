# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::AnalyzerNamespaceStatuses::RecalculateWorker, feature_category: :security_asset_inventories do
  let_it_be(:group) { create(:group) }
  let_it_be(:group_id) { group.id }

  subject(:run_worker) { described_class.new.perform(group_id) }

  describe '#perform' do
    before do
      allow(Security::AnalyzerNamespaceStatuses::RecalculateService).to receive(:execute)
    end

    context 'when there is no group associated with the id' do
      let(:group_id) { non_existing_record_id }

      it 'does not call the service layer logic' do
        run_worker

        expect(Security::AnalyzerNamespaceStatuses::RecalculateService).not_to have_received(:execute)
      end
    end

    context 'when there is a group associated with the id' do
      it 'calls the RecalculateService' do
        run_worker

        expect(Security::AnalyzerNamespaceStatuses::RecalculateService)
          .to have_received(:execute).with(group)
      end
    end
  end
end
