# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::NamespaceStatistics::RecalculateNamespaceStatisticsWorker, feature_category: :vulnerability_management do
  let_it_be_with_reload(:group) { create(:group) }
  let(:worker) { described_class.new }

  describe '#perform' do
    subject(:perform) { worker.perform(group.id) }

    context 'when group exists' do
      it 'calls the recalculate service' do
        expect(Vulnerabilities::NamespaceStatistics::RecalculateService).to receive(:execute).with(group)

        perform
      end
    end

    context 'when group does not exist' do
      it 'does not call the recalculate service' do
        expect(Vulnerabilities::NamespaceStatistics::RecalculateService).not_to receive(:execute)

        worker.perform(non_existing_record_id)
      end
    end
  end
end
