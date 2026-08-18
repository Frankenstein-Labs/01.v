# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::NamespaceStatistics::UpdateService, feature_category: :vulnerability_management do
  let_it_be(:root_group) { create(:group) }
  let_it_be(:subgroup1) { create(:group, parent: root_group) }
  let_it_be(:subgroup2) { create(:group, parent: subgroup1) }

  describe '.execute' do
    let(:mock_service_object) { instance_double(described_class, execute: true) }

    before do
      allow(described_class).to receive(:new).and_return(mock_service_object)
    end

    it 'instantiates the service object and calls `execute`' do
      described_class.execute nil

      expect(mock_service_object).to have_received(:execute)
    end
  end

  describe '#execute' do
    context 'when diffs are not provided' do
      context 'when diffs is nil' do
        let(:diffs) { nil }

        subject(:namespace_statistics_update_service) { described_class.execute(diffs) }

        it 'does not change the db' do
          expect { namespace_statistics_update_service }
            .to not_change { Vulnerabilities::NamespaceStatistic.count }.from(0)
        end
      end

      context 'when diffs are an empty array' do
        let(:diffs) { [] }

        subject(:namespace_statistics_update_service) { described_class.execute(diffs) }

        it 'does not change the db' do
          expect { namespace_statistics_update_service }
            .to not_change { Vulnerabilities::NamespaceStatistic.count }.from(0)
        end
      end

      context 'when diffs are empty hashes or nils' do
        let(:diffs) { [{}, nil, {}, nil] }

        subject(:namespace_statistics_update_service) { described_class.execute(diffs) }

        it 'does not change the db' do
          expect { namespace_statistics_update_service }
            .to not_change { Vulnerabilities::NamespaceStatistic.count }.from(0)
        end
      end
    end

    context 'when diffs are provided' do
      let(:diffs) do
        [
          {
            "namespace_id" => subgroup1.id,
            "traversal_ids" => "{#{subgroup1.traversal_ids.join(',')}}",
            "total" => 3,
            "critical" => 1,
            "high" => 1,
            "medium" => 1,
            "low" => 0,
            "info" => 0,
            "unknown" => 0
          },
          {
            "namespace_id" => subgroup2.id,
            "traversal_ids" => "{#{subgroup2.traversal_ids.join(',')}}",
            "total" => 3,
            "critical" => 0,
            "high" => 0,
            "medium" => 0,
            "low" => 1,
            "info" => 1,
            "unknown" => 1
          }
        ]
      end

      subject(:namespace_statistics_update_service) { described_class.execute(diffs) }

      context 'when there are no statistics in the table' do
        it 'inserts new rows to the table' do
          expect { namespace_statistics_update_service }.to change { Vulnerabilities::NamespaceStatistic.count }
            .from(0).to(3)

          expect(Vulnerabilities::NamespaceStatistic.find_by_namespace_id(root_group.id).attributes).to include({
            "total" => 6,
            "critical" => 1,
            "high" => 1,
            "medium" => 1,
            "low" => 1,
            "info" => 1,
            "unknown" => 1
          })
          expect(Vulnerabilities::NamespaceStatistic.find_by_namespace_id(subgroup1.id).attributes).to include({
            "total" => 6,
            "critical" => 1,
            "high" => 1,
            "medium" => 1,
            "low" => 1,
            "info" => 1,
            "unknown" => 1
          })
          expect(Vulnerabilities::NamespaceStatistic.find_by_namespace_id(subgroup2.id).attributes).to include({
            "total" => 3,
            "critical" => 0,
            "high" => 0,
            "medium" => 0,
            "low" => 1,
            "info" => 1,
            "unknown" => 1
          })
        end
      end

      context 'when all statistics exists in the table' do
        let_it_be(:root_group_statistics) do
          create(
            :vulnerability_namespace_statistic,
            namespace: root_group,
            total: 4,
            info: 3,
            unknown: 1
          )
        end

        let_it_be(:subgroup1_statistics) do
          create(
            :vulnerability_namespace_statistic,
            namespace: subgroup1,
            total: 3,
            info: 3
          )
        end

        let_it_be(:subgroup2_statistics) do
          create(
            :vulnerability_namespace_statistic,
            namespace: subgroup2,
            total: 3,
            info: 3
          )
        end

        it 'upserts new counts to the table' do
          expect { namespace_statistics_update_service }.to not_change { Vulnerabilities::NamespaceStatistic.count }
            .from(3)

          expect(root_group_statistics.reload.attributes).to include({
            "total" => 10,
            "critical" => 1,
            "high" => 1,
            "medium" => 1,
            "low" => 1,
            "info" => 4,
            "unknown" => 2
          })
          expect(subgroup1_statistics.reload.attributes).to include({
            "total" => 9,
            "critical" => 1,
            "high" => 1,
            "medium" => 1,
            "low" => 1,
            "info" => 4,
            "unknown" => 1
          })
          expect(subgroup2_statistics.reload.attributes).to include({
            "total" => 6,
            "critical" => 0,
            "high" => 0,
            "medium" => 0,
            "low" => 1,
            "info" => 4,
            "unknown" => 1
          })
        end
      end

      context 'when some statistics exists in the table' do
        let_it_be(:root_group_statistics) do
          create(
            :vulnerability_namespace_statistic,
            namespace: root_group,
            total: 4,
            info: 3,
            unknown: 1
          )
        end

        let_it_be(:subgroup1_statistics) do
          create(
            :vulnerability_namespace_statistic,
            namespace: subgroup1,
            total: 3,
            info: 3
          )
        end

        it 'inserts missing statistics and upserts new counts to the table' do
          expect { namespace_statistics_update_service }.to change { Vulnerabilities::NamespaceStatistic.count }
            .from(2).to(3)

          expect(root_group_statistics.reload.attributes).to include({
            "total" => 10,
            "critical" => 1,
            "high" => 1,
            "medium" => 1,
            "low" => 1,
            "info" => 4,
            "unknown" => 2
          })
          expect(subgroup1_statistics.reload.attributes).to include({
            "total" => 9,
            "critical" => 1,
            "high" => 1,
            "medium" => 1,
            "low" => 1,
            "info" => 4,
            "unknown" => 1
          })
          expect(Vulnerabilities::NamespaceStatistic.find_by_namespace_id(subgroup2.id).attributes).to include({
            "total" => 3,
            "critical" => 0,
            "high" => 0,
            "medium" => 0,
            "low" => 1,
            "info" => 1,
            "unknown" => 1
          })
        end
      end
    end
  end
end
