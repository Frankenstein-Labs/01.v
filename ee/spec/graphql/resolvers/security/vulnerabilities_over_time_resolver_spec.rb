# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Security::VulnerabilitiesOverTimeResolver, :elastic_delete_by_query, :sidekiq_inline, feature_category: :vulnerability_management do
  include GraphqlHelpers

  subject(:resolved_metrics) do
    context = { current_user: current_user }
    context[:report_type] = report_type_filter if defined?(report_type_filter)
    context[:project_id] = project_id_filter if defined?(project_id_filter)
    resolve(described_class, obj: operate_on, args: args, ctx: context, lookahead: lookahead)
  end

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, namespace: group) }
  let_it_be(:project_2) { create(:project, namespace: group) }
  let_it_be(:project_3) { create(:project, namespace: group) }
  let_it_be(:project_4) { create(:project, namespace: group) }
  let_it_be(:current_user) { create(:user) }

  let_it_be(:vulnerabilities) do
    dates = ['2019-10-15T00:00:00Z', '2019-10-16T00:00:00Z', '2019-10-17T00:00:00Z']
    severity_report_pairs = [
      { severity: :low, report_type: :sast },
      { severity: :medium, report_type: :dast },
      { severity: :high, report_type: :dependency_scanning },
      { severity: :critical, report_type: :sast }
    ]

    dates.flat_map do |date|
      severity_report_pairs.map do |config|
        create(
          :vulnerability,
          :with_finding,
          severity: config[:severity],
          report_type: config[:report_type],
          project: project,
          created_at: date
        )
      end
    end
  end

  let_it_be(:additional_project_vulnerabilities) do
    [
      create(:vulnerability, :with_finding, severity: :critical, report_type: :sast, project: project_2,
        created_at: '2019-10-15T00:00:00Z'),
      create(:vulnerability, :with_finding, severity: :high, report_type: :dast, project: project_2,
        created_at: '2019-10-16T00:00:00Z'),
      create(:vulnerability, :with_finding, severity: :medium, report_type: :container_scanning, project: project_3,
        created_at: '2019-10-15T00:00:00Z'),
      create(:vulnerability, :with_finding, severity: :low, report_type: :secret_detection, project: project_4,
        created_at: '2019-10-17T00:00:00Z')
    ]
  end

  let(:lookahead) { positive_lookahead }

  before do
    allow(lookahead).to receive(:selects?).and_return(true)
  end

  describe '#resolve' do
    let(:start_date) { Date.new(2019, 10, 15) }
    let(:end_date) { Date.new(2019, 10, 21) }
    let(:args) { { start_date: start_date, end_date: end_date } }

    before do
      stub_licensed_features(security_dashboard: true)
      stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
    end

    shared_examples 'returns vulnerability metrics' do
      context 'when the current user has access' do
        before_all do
          group.add_maintainer(current_user)
        end

        before do
          Elastic::ProcessBookkeepingService.track!(*vulnerabilities, *additional_project_vulnerabilities)
          ensure_elasticsearch_index!
        end

        it 'returns vulnerability metrics data' do
          expect(resolved_metrics).to be_a(Gitlab::Graphql::Pagination::ArrayConnection)
          expect(resolved_metrics.items).not_to be_empty

          all_severities = resolved_metrics.items.flat_map do |item|
            item[:by_severity]&.map do |s|
              s[:severity]
            end
          end.compact.uniq
          all_report_types = resolved_metrics.items.flat_map do |item|
            item[:by_report_type]&.map do |rt|
              rt[:report_type]
            end
          end.compact.uniq

          expect(all_severities).to include('low', 'medium', 'high', 'critical')
          expect(all_report_types).to include('sast', 'dast', 'dependency_scanning')
        end

        context 'with filter arguments' do
          let(:args) do
            {
              start_date: start_date,
              end_date: end_date,
              severity: ['critical']
            }
          end

          it 'returns filtered vulnerability metrics' do
            expect(resolved_metrics).to be_a(Gitlab::Graphql::Pagination::ArrayConnection)
            expect(resolved_metrics.items).not_to be_empty
          end

          context 'with report_type filter' do
            let(:args) do
              {
                start_date: start_date,
                end_date: end_date
              }
            end

            it 'returns vulnerability metrics filtered by report type' do
              expect(resolved_metrics).to be_a(Gitlab::Graphql::Pagination::ArrayConnection)
              expect(resolved_metrics.items).not_to be_empty

              resolved_metrics.items.each do |item|
                expect(item[:by_report_type]).to be_present
                report_types = item[:by_report_type].map { |rt| rt[:report_type] }
                expect(report_types).to include('sast', 'dast')
              end
            end
          end
        end

        context 'when filtering on page-level' do
          context 'with single report type filtering' do
            let(:report_type_filter) { ['sast'] }

            let(:args) do
              {
                start_date: start_date,
                end_date: end_date
              }
            end

            it 'returns vulnerability metrics filtered by single report type' do
              expect(resolved_metrics).to be_a(Gitlab::Graphql::Pagination::ArrayConnection)
              expect(resolved_metrics.items).not_to be_empty

              resolved_metrics.items.each do |item|
                next unless item[:by_report_type].present?

                report_types = item[:by_report_type].map { |rt| rt[:report_type] }
                expect(report_types).to all(eq('sast'))
              end
            end
          end

          context 'with multiple report types filtering' do
            let(:report_type_filter) { %w[sast dast] }

            let(:args) do
              {
                start_date: start_date,
                end_date: end_date
              }
            end

            it 'returns vulnerability metrics filtered by multiple report types' do
              expect(resolved_metrics).to be_a(Gitlab::Graphql::Pagination::ArrayConnection)
              expect(resolved_metrics.items).not_to be_empty

              resolved_metrics.items.each do |item|
                next unless item[:by_report_type].present?

                report_types = item[:by_report_type].map { |rt| rt[:report_type] }
                expect(report_types).to match_array(report_type_filter)
              end
            end
          end

          context 'when filtering on a single project' do
            let(:project_id_filter) { [project.id] }

            let(:args) do
              {
                start_date: start_date,
                end_date: end_date
              }
            end

            it 'returns vulnerability metrics filtered by single project' do
              expect(resolved_metrics).to be_a(Gitlab::Graphql::Pagination::ArrayConnection)
              expect(resolved_metrics.items).not_to be_empty

              has_severity_data = resolved_metrics.items.any? do |item|
                item[:by_severity].present? && item[:by_severity].any?
              end
              has_report_type_data = resolved_metrics.items.any? do |item|
                item[:by_report_type].present? && item[:by_report_type].any?
              end

              expect(has_severity_data || has_report_type_data).to be true
            end
          end

          context 'with multiple projects filtering' do
            let(:project_id_filter) { [project.id, project_2.id, project_3.id, project_4.id] }

            let(:args) do
              {
                start_date: start_date,
                end_date: end_date
              }
            end

            it 'returns vulnerability metrics filtered by multiple projects' do
              expect(resolved_metrics).to be_a(Gitlab::Graphql::Pagination::ArrayConnection)
              expect(resolved_metrics.items).not_to be_empty

              has_severity_data = resolved_metrics.items.any? do |item|
                item[:by_severity].present? && item[:by_severity].any?
              end
              has_report_type_data = resolved_metrics.items.any? do |item|
                item[:by_report_type].present? && item[:by_report_type].any?
              end

              expect(has_severity_data || has_report_type_data).to be true
            end
          end
        end

        context 'when filtering on panel-level' do
          context 'with single severity filtering' do
            let(:args) do
              {
                start_date: start_date,
                end_date: end_date,
                severity: ['critical']
              }
            end

            it 'returns vulnerability metrics filtered by single severity' do
              expect(resolved_metrics).to be_a(Gitlab::Graphql::Pagination::ArrayConnection)
              expect(resolved_metrics.items).not_to be_empty

              resolved_metrics.items.each do |item|
                next unless item[:by_severity].present?

                severities = item[:by_severity].map { |s| s[:severity] }
                expect(severities).to all(eq('critical'))
              end
            end
          end

          context 'with multiple severities filtering' do
            let(:args) do
              {
                start_date: start_date,
                end_date: end_date,
                severity: %w[critical high medium]
              }
            end

            it 'returns vulnerability metrics filtered by multiple severities' do
              expect(resolved_metrics).to be_a(Gitlab::Graphql::Pagination::ArrayConnection)
              expect(resolved_metrics.items).not_to be_empty

              resolved_metrics.items.each do |item|
                next unless item[:by_severity].present?

                severities = item[:by_severity].map { |s| s[:severity] }
                expect(severities).to all(be_in(%w[critical high medium]))
              end
            end
          end
        end

        context 'when combining multiple filters' do
          context 'with mixed page and panel level filters' do
            let(:report_type_filter) { ['sast'] }

            let(:args) do
              {
                start_date: start_date,
                end_date: end_date,
                project_id: [project.to_global_id.to_s],
                severity: ['critical']
              }
            end

            it 'returns vulnerability metrics with combined filters applied' do
              expect(resolved_metrics).to be_a(Gitlab::Graphql::Pagination::ArrayConnection)
              expect(resolved_metrics.items).not_to be_empty

              resolved_metrics.items.each do |item|
                if item[:by_severity].present?
                  severities = item[:by_severity].map { |s| s[:severity] }
                  expect(severities).to all(eq('critical'))
                end

                if item[:by_report_type].present?
                  report_types = item[:by_report_type].map { |rt| rt[:report_type] }
                  expect(report_types).to all(eq('sast'))
                end
              end
            end
          end
        end
      end
    end

    shared_examples 'returns empty array' do
      it 'returns an empty array connection' do
        expect(resolved_metrics).to be_a(Gitlab::Graphql::Pagination::ArrayConnection)
        expect(resolved_metrics.items).to be_empty
      end
    end

    context 'when operated on a group' do
      let(:operate_on) { group }

      it_behaves_like 'returns vulnerability metrics'

      context 'when the current user does not have access' do
        it_behaves_like 'returns resource not available'
      end

      context 'when security_dashboard feature flag is disabled' do
        before do
          stub_licensed_features(security_dashboard: false)
        end

        it_behaves_like 'returns resource not available'
      end

      context 'when validating advanced vulnerability management' do
        before_all do
          group.add_developer(current_user)
        end

        it_behaves_like 'validates advanced vulnerability management'
      end

      it 'maps parameters as expected' do
        group.add_developer(current_user)

        context = {
          current_user: current_user,
          report_type: :sast,
          project_id: project.id,
          tracked_ref_ids: 123
        }
        args = {
          severity: :high,
          start_date: start_date,
          end_date: end_date
        }
        expected_params = {
          created_after: start_date,
          created_before: end_date,
          project_id: project.id,
          report_type: :sast,
          security_project_tracked_context_id: 123,
          severity: ['high']
        }

        expect(Search::AdvancedFinders::Security::Vulnerability::CountOverTimeFinder)
          .to receive(:new)
          .with(operate_on, expected_params.merge({ group_by: 'severity' }))
          .and_call_original

        expect(Search::AdvancedFinders::Security::Vulnerability::CountOverTimeFinder)
          .to receive(:new)
          .with(operate_on, expected_params.merge({ group_by: 'report_type' }))
          .and_call_original

        resolve(described_class, obj: operate_on, args: args, ctx: context, lookahead: lookahead)
      end
    end

    context 'when operated on a project' do
      let(:operate_on) { project }

      it_behaves_like 'returns vulnerability metrics'

      context 'when the current user does not have access' do
        it_behaves_like 'returns resource not available'
      end

      context 'when security_dashboard feature flag is disabled' do
        before do
          stub_licensed_features(security_dashboard: false)
        end

        it_behaves_like 'returns resource not available'
      end

      context 'when validating advanced vulnerability management' do
        before_all do
          project.add_developer(current_user)
        end

        it_behaves_like 'validates advanced vulnerability management'
      end

      it 'maps parameters as expected' do
        project.add_developer(current_user)

        context = {
          current_user: current_user,
          report_type: :sast,
          project_id: project.id,
          tracked_ref_ids: 123
        }
        args = {
          severity: :high,
          start_date: start_date,
          end_date: end_date
        }
        expected_params = {
          created_after: start_date,
          created_before: end_date,
          project_id: project.id,
          report_type: :sast,
          security_project_tracked_context_id: 123,
          severity: ['high']
        }

        expect(Search::AdvancedFinders::Security::Vulnerability::CountOverTimeFinder)
          .to receive(:new)
          .with(operate_on, expected_params.merge({ group_by: 'severity' }))
          .and_call_original

        expect(Search::AdvancedFinders::Security::Vulnerability::CountOverTimeFinder)
          .to receive(:new)
          .with(operate_on, expected_params.merge({ group_by: 'report_type' }))
          .and_call_original

        resolve(described_class, obj: operate_on, args: args, ctx: context, lookahead: lookahead)
      end
    end

    context 'when operated on an instance security dashboard' do
      let(:operate_on) { InstanceSecurityDashboard.new(current_user) }

      before_all do
        group.add_maintainer(current_user)
      end

      before do
        stub_licensed_features(security_dashboard: true)
        stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
      end

      it 'skips authorization check for instance security dashboard' do
        expect(described_class).not_to receive(:authorize!)
      end
    end
  end

  describe '#validate_date_range' do
    let(:operate_on) { group }

    before_all do
      group.add_maintainer(current_user)
    end

    before do
      stub_licensed_features(security_dashboard: true)
      stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
      Elastic::ProcessBookkeepingService.track!(*vulnerabilities)
      ensure_elasticsearch_index!
    end

    context 'when start_date is after end_date' do
      let(:start_date) { Date.new(2019, 10, 21) }
      let(:end_date) { Date.new(2019, 10, 15) }
      let(:args) { { start_date: start_date, end_date: end_date } }

      it 'returns an ArgumentError' do
        expect(resolved_metrics).to be_a(Gitlab::Graphql::Errors::ArgumentError)
        expect(resolved_metrics.message).to eq('start date cannot be after end date')
      end
    end

    context 'when date range exceeds maximum allowed days' do
      let(:start_date) { Date.current }
      let(:end_date) { start_date + (described_class::MAX_DATE_RANGE_DAYS + 1).days }
      let(:args) { { start_date: start_date, end_date: end_date } }

      it 'returns an ArgumentError' do
        expect(resolved_metrics).to be_a(Gitlab::Graphql::Errors::ArgumentError)
        expect(resolved_metrics.message).to eq("maximum date range is #{described_class::MAX_DATE_RANGE_DAYS} days")
      end
    end
  end
end
