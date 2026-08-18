# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Security::VulnerabilitiesByAgeResolver, :elastic_delete_by_query, :sidekiq_inline, feature_category: :vulnerability_management do
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

  let_it_be(:current_day) { Time.current.beginning_of_day }
  let_it_be(:vulnerabilities) do
    dates = [current_day - 5.days, current_day - 20.days, current_day - 200.days]
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
          detected_at: date
        )
      end
    end
  end

  let_it_be(:additional_project_vulnerabilities) do
    [
      create(:vulnerability, :with_finding, severity: :critical, report_type: :sast, project: project_2,
        detected_at: current_day - 10.days),
      create(:vulnerability, :with_finding, severity: :high, report_type: :dast, project: project_2,
        detected_at: current_day - 45.days),
      create(:vulnerability, :with_finding, severity: :medium, report_type: :container_scanning, project: project_3,
        detected_at: current_day - 100.days),
      create(:vulnerability, :with_finding, severity: :low, report_type: :secret_detection, project: project_4,
        detected_at: current_day - 250.days)
    ]
  end

  let(:lookahead) { positive_lookahead }
  let(:args) { {} }

  before do
    allow(lookahead).to receive(:selects?).and_return(true)
  end

  describe '#resolve' do
    before do
      stub_licensed_features(security_dashboard: true)
      stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
    end

    shared_examples 'returns vulnerability age metrics' do
      context 'when the current user has access' do
        before_all do
          group.add_maintainer(current_user)
        end

        before do
          Elastic::ProcessBookkeepingService.track!(*vulnerabilities, *additional_project_vulnerabilities)
          ensure_elasticsearch_index!
        end

        it 'returns vulnerability age metrics data', :aggregate_failures do
          expect(resolved_metrics).to be_an(Array)
          expect(resolved_metrics).not_to be_empty

          age_bands = resolved_metrics.pluck(:name)
          expect(age_bands).to include('< 7 days', '15 - 30 days', '> 180 days')

          all_severities = resolved_metrics.flat_map do |item|
            item[:by_severity]&.pluck(:severity)
          end.compact.uniq
          all_report_types = resolved_metrics.flat_map do |item|
            item[:by_report_type]&.pluck(:report_type)
          end.compact.uniq

          expect(all_severities).to include('low', 'medium', 'high', 'critical')
          expect(all_report_types).to include('sast', 'dast', 'dependency_scanning')
        end

        context 'when only by_severity is requested' do
          before do
            allow(lookahead).to receive(:selects?).with(:by_severity).and_return(true)
            allow(lookahead).to receive(:selects?).with(:by_report_type).and_return(false)
          end

          it 'returns only severity data', :aggregate_failures do
            expect(resolved_metrics).to be_an(Array)
            expect(resolved_metrics).not_to be_empty

            resolved_metrics.each do |item|
              expect(item[:by_severity]).to be_present
              expect(item[:by_report_type]).to be_empty
            end
          end
        end

        context 'when only by_report_type is requested' do
          before do
            allow(lookahead).to receive(:selects?).with(:by_severity).and_return(false)
            allow(lookahead).to receive(:selects?).with(:by_report_type).and_return(true)
          end

          it 'returns only report type data', :aggregate_failures do
            expect(resolved_metrics).to be_an(Array)
            expect(resolved_metrics).not_to be_empty

            resolved_metrics.each do |item|
              expect(item[:by_severity]).to be_empty
              expect(item[:by_report_type]).to be_present
            end
          end
        end

        context 'with filter arguments' do
          let(:args) do
            {
              severity: ['critical']
            }
          end

          it 'returns filtered vulnerability age metrics', :aggregate_failures do
            expect(resolved_metrics).to be_an(Array)
            expect(resolved_metrics).not_to be_empty

            resolved_metrics.each do |item|
              next unless item[:by_severity].present?

              severities = item[:by_severity].pluck(:severity)
              expect(severities).to all(eq('critical'))
            end
          end
        end

        context 'when filtering on page-level' do
          context 'with single report type filtering' do
            let(:report_type_filter) { ['sast'] }
            let(:args) { {} }

            it 'returns vulnerability age metrics filtered by single report type', :aggregate_failures do
              expect(resolved_metrics).to be_an(Array)
              expect(resolved_metrics).not_to be_empty

              resolved_metrics.each do |item|
                next unless item[:by_report_type].present?

                report_types = item[:by_report_type].pluck(:report_type)
                expect(report_types).to all(eq('sast'))
              end
            end
          end

          context 'with multiple report types filtering' do
            let(:report_type_filter) { %w[sast dast] }
            let(:args) { {} }

            it 'returns vulnerability age metrics filtered by multiple report types', :aggregate_failures do
              expect(resolved_metrics).to be_an(Array)
              expect(resolved_metrics).not_to be_empty

              resolved_metrics.each do |item|
                next unless item[:by_report_type].present?

                report_types = item[:by_report_type].pluck(:report_type)
                expect(report_types).to match_array(report_type_filter)
              end
            end
          end

          context 'when filtering on a single project' do
            let(:project_id_filter) { [project.id] }
            let(:args) { {} }

            it 'returns vulnerability age metrics filtered by single project', :aggregate_failures do
              expect(resolved_metrics).to be_an(Array)
              expect(resolved_metrics).not_to be_empty

              has_severity_data = resolved_metrics.any? do |item|
                item[:by_severity].present? && item[:by_severity].any?
              end
              has_report_type_data = resolved_metrics.any? do |item|
                item[:by_report_type].present? && item[:by_report_type].any?
              end

              expect(has_severity_data || has_report_type_data).to be true
            end
          end

          context 'with multiple projects filtering' do
            let(:project_id_filter) { [project.id, project_2.id, project_3.id, project_4.id] }
            let(:args) { {} }

            it 'returns vulnerability age metrics filtered by multiple projects', :aggregate_failures do
              expect(resolved_metrics).to be_an(Array)
              expect(resolved_metrics).not_to be_empty

              has_severity_data = resolved_metrics.any? do |item|
                item[:by_severity].present? && item[:by_severity].any?
              end
              has_report_type_data = resolved_metrics.any? do |item|
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
                severity: ['critical']
              }
            end

            it 'returns vulnerability age metrics filtered by single severity', :aggregate_failures do
              expect(resolved_metrics).to be_an(Array)
              expect(resolved_metrics).not_to be_empty

              resolved_metrics.each do |item|
                next unless item[:by_severity].present?

                severities = item[:by_severity].pluck(:severity)
                expect(severities).to all(eq('critical'))
              end
            end
          end

          context 'with multiple severities filtering' do
            let(:args) do
              {
                severity: %w[critical high medium]
              }
            end

            it 'returns vulnerability age metrics filtered by multiple severities', :aggregate_failures do
              expect(resolved_metrics).to be_an(Array)
              expect(resolved_metrics).not_to be_empty

              resolved_metrics.each do |item|
                next unless item[:by_severity].present?

                severities = item[:by_severity].pluck(:severity)
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
                project_id: [project.to_global_id.to_s],
                severity: ['critical']
              }
            end

            it 'returns vulnerability age metrics with combined filters applied', :aggregate_failures do
              expect(resolved_metrics).to be_an(Array)
              expect(resolved_metrics).not_to be_empty

              resolved_metrics.each do |item|
                if item[:by_severity].present?
                  severities = item[:by_severity].pluck(:severity)
                  expect(severities).to all(eq('critical'))
                end

                if item[:by_report_type].present?
                  report_types = item[:by_report_type].pluck(:report_type)
                  expect(report_types).to all(eq('sast'))
                end
              end
            end
          end
        end

        context 'when checking age band distribution' do
          it 'groups vulnerabilities into correct age bands', :aggregate_failures do
            expect(resolved_metrics).to be_an(Array)

            age_bands = resolved_metrics.pluck(:name)

            # Should have at least the age bands where vulnerabilities exist
            expect(age_bands).to include('< 7 days')
            expect(age_bands).to include('15 - 30 days')
            expect(age_bands).to include('> 180 days')
          end

          it 'returns age bands with non-zero counts', :aggregate_failures do
            less_than_7 = resolved_metrics.find { |item| item[:name] == '< 7 days' }
            days_15_to_30 = resolved_metrics.find { |item| item[:name] == '15 - 30 days' }
            greater_than_180 = resolved_metrics.find { |item| item[:name] == '> 180 days' }

            expect(less_than_7).to be_present
            expect(days_15_to_30).to be_present
            expect(greater_than_180).to be_present

            # Verify they have actual vulnerability counts
            if less_than_7[:by_severity].present?
              total_count = less_than_7[:by_severity].sum { |s| s[:count] }
              expect(total_count).to be > 0
            end
          end
        end

        context 'when filtering by state' do
          let_it_be(:resolved_vulnerability) do
            create(
              :vulnerability,
              :with_finding,
              severity: :high,
              report_type: :sast,
              project: project,
              detected_at: current_day - 5.days,
              state: :resolved,
              resolved_at: current_day - 2.days
            )
          end

          before do
            Elastic::ProcessBookkeepingService.track!(resolved_vulnerability)
            ensure_elasticsearch_index!
          end

          it 'excludes resolved vulnerabilities by default' do
            resolved_metrics.each do |item|
              next unless item[:age_band] == '< 7 days' && item[:by_severity].present?

              high_severity = item[:by_severity].find { |s| s[:severity] == 'high' }
              # The count should not include the resolved vulnerability
              expect(high_severity[:count]).to eq(1) # Only the active high severity vulnerability
            end
          end
        end
      end
    end

    shared_examples 'returns resource not available' do
      it 'raises a resource not available error' do
        expect(resolved_metrics).to be_a(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end

    context 'when operated on a group' do
      let(:operate_on) { group }

      it_behaves_like 'returns vulnerability age metrics'

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
          severity: :high
        }
        expected_params = {
          project_id: project.id,
          report_type: :sast,
          security_project_tracked_context_id: 123,
          has_resolution: false,
          severity: ['high'],
          state: %w[detected confirmed]
        }

        expect(Search::AdvancedFinders::Security::Vulnerability::CountByAgeFinder)
          .to receive(:new)
          .with(operate_on, expected_params.merge({ group_by: 'severity' }))
          .and_call_original

        expect(Search::AdvancedFinders::Security::Vulnerability::CountByAgeFinder)
          .to receive(:new)
          .with(operate_on, expected_params.merge({ group_by: 'report_type' }))
          .and_call_original

        resolve(described_class, obj: operate_on, args: args, ctx: context, lookahead: lookahead)
      end
    end

    context 'when operated on a project' do
      let(:operate_on) { project }

      it_behaves_like 'returns vulnerability age metrics'

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
          severity: :high
        }
        expected_params = {
          project_id: project.id,
          report_type: :sast,
          security_project_tracked_context_id: 123,
          has_resolution: false,
          severity: ['high'],
          state: %w[detected confirmed]
        }

        expect(Search::AdvancedFinders::Security::Vulnerability::CountByAgeFinder)
          .to receive(:new)
          .with(operate_on, expected_params.merge({ group_by: 'severity' }))
          .and_call_original

        expect(Search::AdvancedFinders::Security::Vulnerability::CountByAgeFinder)
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

    context 'when neither by_severity nor by_report_type is requested' do
      before_all do
        group.add_maintainer(current_user)
      end

      before do
        allow(lookahead).to receive(:selects?).with(:by_severity).and_return(false)
        allow(lookahead).to receive(:selects?).with(:by_report_type).and_return(false)
      end

      let(:operate_on) { group }

      it 'returns empty array when no fields are selected' do
        expect(resolved_metrics).to eq([])
      end
    end
  end
end
