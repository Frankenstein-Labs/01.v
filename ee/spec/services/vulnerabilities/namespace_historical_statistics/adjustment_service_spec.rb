# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::NamespaceHistoricalStatistics::AdjustmentService, feature_category: :vulnerability_management do
  let_it_be(:root_group) { create(:group) }
  let_it_be(:group) { create(:group, parent: root_group) }
  let_it_be(:sub_group) { create(:group, parent: group) }
  let_it_be(:project) { create(:project, namespace: sub_group) }
  let_it_be(:project_settings) { create(:project_setting, project: project, has_vulnerabilities: true) }

  describe '.execute' do
    let(:project_ids) { [1, 2, 3] }
    let(:mock_service_object) { instance_double(described_class, execute: true) }

    subject(:execute_for_project_ids) { described_class.execute(project_ids) }

    before do
      allow(described_class).to receive(:new).and_return(mock_service_object)
    end

    it 'instantiates the service object for given project ids and calls `execute` on them', :aggregate_failures do
      execute_for_project_ids

      expect(described_class).to have_received(:new).with([1, 2, 3])
      expect(mock_service_object).to have_received(:execute)
    end
  end

  describe '#execute' do
    let(:statistics) do
      Vulnerabilities::NamespaceHistoricalStatistic.last.reload.as_json(except: [:id, :project_id, :created_at,
        :updated_at])
    end

    let(:project_ids) { [project.id] }

    let(:expected_statistics) do
      {
        'migrating' => false,
        'total' => 2,
        'critical' => 1,
        'high' => 1,
        'medium' => 0,
        'low' => 0,
        'info' => 0,
        'unknown' => 0,
        'letter_grade' => 'f',
        'date' => Date.current.to_s,
        'namespace_id' => sub_group.id,
        'traversal_ids' => sub_group.traversal_ids
      }
    end

    subject(:adjust_statistics) { described_class.new(project_ids).execute }

    context 'when more than 1000 projects is provided' do
      let(:project_ids) { (1..1001).to_a }

      it 'raises error' do
        expect { adjust_statistics }.to raise_error do |error|
          expect(error.class).to eql(described_class::TooManyProjectsError)
          expect(error.message).to eql('Cannot adjust namespace statistics for more than 1000 projects')
        end
      end
    end

    context 'when there is no vulnerability_statistic record for project' do
      it 'does not create a new record in database' do
        expect { adjust_statistics }.not_to change { Vulnerabilities::NamespaceHistoricalStatistic.count }
      end
    end

    context 'when there is vulnerability_statistic record for project' do
      let!(:vulnerability_statistic) do
        create(:vulnerability_statistic, project: project, total: 2, critical: 1, high: 1)
      end

      context 'when there is no vulnerability_namespace_historical_statistic record for the group' do
        it 'creates a new record' do
          expect { adjust_statistics }.to change { Vulnerabilities::NamespaceHistoricalStatistic.count }.by(1)
        end

        it 'sets the correct values for the record' do
          adjust_statistics

          expect(statistics).to eq(expected_statistics)
        end
      end

      context 'when there is already a vulnerability_historical_statistic record for project' do
        let!(:vulnerability_historical_statistic) { create(:vulnerability_historical_statistic, project: project) }

        it 'does not create a new record in database' do
          expect { adjust_statistics }.not_to change { Vulnerabilities::Statistic.count }
        end

        it 'sets the correct values for the record' do
          adjust_statistics

          expect(statistics).to eq(expected_statistics)
        end
      end
    end

    context 'when there is vulnerability_statistic record for multiple projects under the same group' do
      let_it_be(:project_2) { create(:project, namespace: sub_group) }
      let_it_be(:project_settings_2) { create(:project_setting, project: project_2, has_vulnerabilities: true) }

      let!(:vulnerability_statistic_1) do
        create(:vulnerability_statistic, project: project, total: 2, critical: 1, high: 1)
      end

      let!(:vulnerability_statistic_2) do
        create(:vulnerability_statistic, project: project_2, total: 2, critical: 1, high: 0)
      end

      let(:project_ids) { [project.id, project_2.id] }
      let(:expected_statistics) do
        {
          'migrating' => false,
          'total' => 3,
          'critical' => 2,
          'high' => 1,
          'medium' => 0,
          'low' => 0,
          'info' => 0,
          'unknown' => 0,
          'letter_grade' => 'f',
          'date' => Date.current.to_s,
          'namespace_id' => sub_group.id,
          'traversal_ids' => sub_group.traversal_ids
        }
      end

      context 'when in the same batch' do
        it 'creates a new single record for the group' do
          expect { adjust_statistics }.to change { Vulnerabilities::NamespaceHistoricalStatistic.count }.by(1)
        end

        it 'aggregates the values correctly' do
          adjust_statistics

          expect(statistics).to eq(expected_statistics)
        end
      end

      context 'when in different batches' do
        it 'creates a new single record for the group' do
          expect do
            described_class.new([project.id]).execute && described_class.new([project_2.id]).execute
          end.to change { Vulnerabilities::NamespaceHistoricalStatistic.count }.by(1)
        end

        it 'aggregates the values correctly' do
          described_class.new([project.id]).execute
          described_class.new([project_2.id]).execute

          expect(statistics).to eq(expected_statistics)
        end
      end

      context 'when project and namespace CTE has missing project entries compared to vulnerability_statistics' do
        let_it_be(:project_1) { create(:project, namespace: sub_group) }
        let_it_be(:project_2) { create(:project, namespace: sub_group) }

        let!(:vulnerability_statistic_1) do
          create(:vulnerability_statistic, project: project_1, total: 2, critical: 1, high: 1)
        end

        let!(:vulnerability_statistic_2) do
          create(:vulnerability_statistic, project: project_2, total: 3, critical: 1, high: 2)
        end

        let(:project_ids) { [project_1.id, project_2.id] }

        it 'only processes projects that have valid namespace_id' do
          allow_next_instance_of(described_class) do |instance|
            allow(instance).to receive(:with_values).and_return("VALUES (#{project_1.id}, #{sub_group.id})")
          end

          expect { adjust_statistics }.to change { Vulnerabilities::NamespaceHistoricalStatistic.count }.by(1)

          expect(statistics['total']).to eq(2)
          expect(statistics['critical']).to eq(1)
          expect(statistics['high']).to eq(1)
          expect(statistics['namespace_id']).to eq(sub_group.id)
        end
      end
    end
  end
end
