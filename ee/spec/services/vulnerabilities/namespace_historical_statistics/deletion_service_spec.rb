# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::NamespaceHistoricalStatistics::DeletionService, feature_category: :vulnerability_management do
  describe '.execute' do
    let(:mock_service_object) { instance_double(described_class, execute: true) }

    before do
      allow(described_class).to receive(:new).and_return(mock_service_object)
    end

    it 'instantiates the service object and calls `execute`' do
      described_class.execute

      expect(mock_service_object).to have_received(:execute)
    end
  end

  describe '#execute' do
    let_it_be(:group) { create(:group, traversal_ids: [1]) }
    let_it_be(:other_group) { create(:group, traversal_ids: [1, 2, 3]) }

    subject(:delete_namespace_historical_statistics) { described_class.new.execute }

    before do
      create(:vulnerability_namespace_historical_statistic, date: 10.days.ago, namespace: group)
      create(:vulnerability_namespace_historical_statistic, date: 20.days.ago, namespace: group)
      create(:vulnerability_namespace_historical_statistic, date: 15.days.ago, namespace: other_group)
      create(:vulnerability_namespace_historical_statistic, date: 25.days.ago, namespace: other_group)
    end

    context 'when there is no historical statistics older than 365 days' do
      it 'does not delete historical statistics' do
        expect { delete_namespace_historical_statistics }
          .not_to change { Vulnerabilities::NamespaceHistoricalStatistic.count }
      end
    end

    context 'when there is a historical statistic entry that was created 364 days ago' do
      before do
        create(:vulnerability_namespace_historical_statistic, date: 364.days.ago, namespace: group)
      end

      it 'does not delete historical statistics' do
        expect { delete_namespace_historical_statistics }.not_to change {
                                                                   Vulnerabilities::NamespaceHistoricalStatistic.count
                                                                 }
      end

      context 'and there are more than one entries that are older than 365 days' do
        before do
          create(:vulnerability_namespace_historical_statistic, namespace: group, traversal_ids: [1],
            date: 366.days.ago)
          create(:vulnerability_namespace_historical_statistic, namespace: group, traversal_ids: [1, 2],
            date: 367.days.ago)
          create(:vulnerability_namespace_historical_statistic, namespace: group, traversal_ids: [3, 4, 5],
            date: 368.days.ago)
          create(:vulnerability_namespace_historical_statistic, namespace: other_group, traversal_ids: [11],
            date: 366.days.ago)
          create(:vulnerability_namespace_historical_statistic, namespace: other_group, traversal_ids: [11, 22],
            date: 367.days.ago)
          create(:vulnerability_namespace_historical_statistic, namespace: other_group, traversal_ids: [33, 44, 55],
            date: 368.days.ago)
        end

        it 'deletes historical statistics older than 365 days', :aggregate_failures do
          expect { delete_namespace_historical_statistics }.to change {
                                                                 Vulnerabilities::NamespaceHistoricalStatistic.count
                                                               }.by(-6)
          expect(Vulnerabilities::NamespaceHistoricalStatistic.pluck(:date)).to all(be >= 365.days.ago.to_date)
        end
      end
    end
  end
end
