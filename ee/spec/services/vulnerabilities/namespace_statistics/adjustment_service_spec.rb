# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::NamespaceStatistics::AdjustmentService, feature_category: :vulnerability_management do
  let_it_be(:root_group) { create(:group) }
  let_it_be(:group) { create(:group, parent: root_group) }
  let_it_be(:sub_group) { create(:group, parent: group) }
  let_it_be(:group_project) { create(:project, namespace: group) }
  let_it_be_with_reload(:sub_group_project) { create(:project, namespace: sub_group) }

  def group_statistics(group)
    statistic = Vulnerabilities::NamespaceStatistic
                  .find_by(namespace_id: group.id)
    return unless statistic

    statistic.reload.as_json(except: [:id, :created_at, :updated_at, :age_average, :age_standard_deviation,
      :risk_score])
  end

  describe '.execute' do
    let(:namespace_ids) { [1, 2, 3] }
    let(:mock_service_object) { instance_double(described_class, execute: true) }

    subject(:execute_for_namespace_ids) { described_class.execute(namespace_ids) }

    before do
      allow(described_class).to receive(:new).and_return(mock_service_object)
    end

    it 'instantiates the service object for given namespace ids and calls `execute` on them', :aggregate_failures do
      execute_for_namespace_ids

      expect(described_class).to have_received(:new).with([1, 2, 3])
      expect(mock_service_object).to have_received(:execute)
    end
  end

  describe '#execute' do
    let(:namespace_ids) { [sub_group.id, root_group.id, group.id] }

    subject(:adjust_statistics) { described_class.new(namespace_ids).execute }

    context 'when more than 1000 namespaces ids are provided' do
      let(:namespace_ids) { (1..1001).to_a }

      it 'raises error' do
        expect { adjust_statistics }.to raise_error do |error|
          expect(error.class).to eql(described_class::TooManyNamespacesError)
          expect(error.message).to eql("Cannot adjust namespace statistics for more than 1000 namespaces")
        end
      end
    end

    context 'with empty namespace_ids array' do
      let(:namespace_ids) { [] }

      it 'does not create new namespace_statistics records' do
        expect { adjust_statistics }.not_to change { Vulnerabilities::NamespaceStatistic.count }
      end
    end

    context 'when a namespace has no projects' do
      let(:empty_group) { create(:group) }
      let(:namespace_ids) { [empty_group.id] }

      it 'creates new empty namespace_statistics records' do
        expect { adjust_statistics }.to change { Vulnerabilities::NamespaceStatistic.count }.by(1)
      end

      it 'returns empty diff' do
        expect(adjust_statistics).to eq([])
      end
    end

    context 'when there are no vulnerability_statistic record for the groups projects' do
      it 'creates new empty namespace_statistics records' do
        expect { adjust_statistics }.to change { Vulnerabilities::NamespaceStatistic.count }.by(3)
      end

      it 'returns empty diff' do
        expect(adjust_statistics).to eq([])
      end
    end

    context 'when there are vulnerability_statistic records for the groups projects' do
      let!(:group_project_statistics) do
        create(:vulnerability_statistic, project: group_project, total: 2, critical: 1, high: 1)
      end

      let!(:sub_group_project_statistics) do
        create(:vulnerability_statistic, project: sub_group_project, total: 2, critical: 1, high: 1)
      end

      let(:expected_single_project_statistics) do
        {
          'total' => 2,
          'critical' => 1,
          'high' => 1,
          'medium' => 0,
          'low' => 0,
          'info' => 0,
          'unknown' => 0
        }
      end

      let(:expected_ancestor_statistics) do
        {
          'total' => 4,
          'critical' => 2,
          'high' => 2,
          'medium' => 0,
          'low' => 0,
          'info' => 0,
          'unknown' => 0
        }
      end

      context 'when there is no vulnerability_namespace_statistic record for a group' do
        it 'creates a new record for each namespace' do
          expect { adjust_statistics }.to change { Vulnerabilities::NamespaceStatistic.count }.by(3)
        end

        it 'sets the correct values for the parent group' do
          adjust_statistics

          expect(group_statistics(sub_group)).to eq(expected_single_project_statistics.merge({
            'namespace_id' => sub_group.id,
            'traversal_ids' => sub_group.traversal_ids
          }))
        end

        it 'sets the correct values for the ancestor groups' do
          adjust_statistics

          expect(group_statistics(group)).to eq(expected_ancestor_statistics.merge({
            'namespace_id' => group.id,
            'traversal_ids' => group.traversal_ids
          }))

          expect(group_statistics(root_group)).to eq(expected_ancestor_statistics.merge({
            'namespace_id' => root_group.id,
            'traversal_ids' => root_group.traversal_ids
          }))
        end

        it 'returns the correct diffs' do
          diffs = adjust_statistics
          expect(diffs.size).to eq(3)

          sub_group_diff = diffs.find { |d| d['namespace_id'] == sub_group.id }
          group_diff = diffs.find { |d| d['namespace_id'] == group.id }
          root_group_diff = diffs.find { |d| d['namespace_id'] == root_group.id }

          expect(sub_group_diff).to include(
            expected_single_project_statistics.merge({ 'namespace_id' => sub_group.id })
          )

          expect(group_diff).to include(
            expected_ancestor_statistics.merge({ 'namespace_id' => group.id })
          )

          expect(root_group_diff).to include(
            expected_ancestor_statistics.merge({ 'namespace_id' => root_group.id })
          )
        end
      end

      context 'when there is already a vulnerability_namespace_statistic record for a group' do
        let!(:root_group_statistics) do
          create(:vulnerability_namespace_statistic, namespace: root_group, total: 4, info: 3, unknown: 1)
        end

        it 'sets the correct values for the group' do
          adjust_statistics

          expect(group_statistics(root_group)).to eq(expected_ancestor_statistics.merge({
            'namespace_id' => root_group.id,
            'traversal_ids' => root_group.traversal_ids
          }))
        end

        it 'returns the correct diffs' do
          diffs = adjust_statistics
          expect(diffs.size).to eq(3)

          sub_group_diff = diffs.find { |d| d['namespace_id'] == sub_group.id }
          group_diff = diffs.find { |d| d['namespace_id'] == group.id }
          root_group_diff = diffs.find { |d| d['namespace_id'] == root_group.id }

          expect(group_diff).to include(expected_ancestor_statistics.merge({ 'namespace_id' => group.id }))
          expect(sub_group_diff).to include(
            expected_single_project_statistics.merge({ 'namespace_id' => sub_group.id })
          )

          expect(root_group_diff).to include(
            'namespace_id' => root_group.id,
            'total' => 0,            # 4 (new) - 4 (old) = 0
            'critical' => 2,         # 2 (new) - 0 (old) = 2
            'high' => 2,             # 2 (new) - 0 (old) = 2
            'medium' => 0,
            'low' => 0,
            'info' => -3,            # 0 (new) - 3 (old) = -3
            'unknown' => -1          # 0 (new) - 1 (old) = -1
          )
        end

        context 'when a group traversal_ids is outdated' do
          before do
            root_group_statistics.update!(traversal_ids: [22, 22, 22])
          end

          it 'sets the correct namespace_ids for the group' do
            adjust_statistics

            expect(group_statistics(root_group)).to eq(expected_ancestor_statistics.merge({
              'namespace_id' => root_group.id,
              'traversal_ids' => root_group.traversal_ids
            }))
          end
        end
      end

      context 'when there are vulnerability_statistic for an archived project' do
        before do
          sub_group_project.update!(archived: true)
          sub_group_project_statistics.update!(archived: true)
        end

        it 'excludes the statistics from archived projects' do
          adjust_statistics

          expect(group_statistics(sub_group)).to eq({
            'namespace_id' => sub_group.id,
            'traversal_ids' => sub_group.traversal_ids,
            'total' => 0,
            'critical' => 0,
            'high' => 0,
            'medium' => 0,
            'low' => 0,
            'info' => 0,
            'unknown' => 0
          })

          expect(group_statistics(group)).to eq(expected_single_project_statistics.merge({
            'namespace_id' => group.id,
            'traversal_ids' => group.traversal_ids
          }))

          expect(group_statistics(root_group)).to eq(expected_single_project_statistics.merge({
            'namespace_id' => root_group.id,
            'traversal_ids' => root_group.traversal_ids
          }))
        end
      end

      describe 'logging and event tracking' do
        let(:service) { described_class.new([group.id]) }
        let(:logger) { instance_spy(Gitlab::AppLogger) }

        before do
          stub_const('Gitlab::AppLogger', logger)
          allow(service).to receive(:track_internal_event)
        end

        context 'when there are changes' do
          it 'logs the changes' do
            service.execute

            expect(logger).to have_received(:warn).with(
              hash_including(
                message: 'Namespace vulnerability statistics adjusted',
                namespace_id: group.id,
                changes: hash_including(
                  'total' => 4,
                  'critical' => 2,
                  'high' => 2,
                  'medium' => 0,
                  'low' => 0,
                  'info' => 0,
                  'unknown' => 0
                )
              )
            )
          end

          it 'tracks the event' do
            service.execute

            expect(service).to have_received(:track_internal_event).with(
              'activate_namespace_statistics_adjustment_service',
              feature_enabled_by_namespace_ids: [group.id]
            )
          end
        end

        context 'when there are no changes' do
          let(:empty_group) { create(:group) }
          let(:service) { described_class.new([empty_group.id]) }

          it 'does not log or track events' do
            service.execute

            expect(logger).not_to have_received(:warn)
            expect(service).not_to have_received(:track_internal_event)
          end
        end

        context 'when multiple namespaces have changes' do
          let(:namespace_ids) { [root_group.id, group.id, sub_group.id] }
          let(:service) { described_class.new(namespace_ids) }

          it 'logs changes for each namespace' do
            service.execute

            expect(logger).to have_received(:warn).exactly(3).times
          end

          it 'tracks events for all namespaces in a single call' do
            service.execute

            expect(service).to have_received(:track_internal_event).once.with(
              'activate_namespace_statistics_adjustment_service',
              feature_enabled_by_namespace_ids: match_array(namespace_ids)
            )
          end
        end
      end
    end
  end
end
