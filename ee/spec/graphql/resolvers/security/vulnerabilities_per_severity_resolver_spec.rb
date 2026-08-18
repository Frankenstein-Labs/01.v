# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Security::VulnerabilitiesPerSeverityResolver, :elastic_delete_by_query, :sidekiq_inline, feature_category: :vulnerability_management do
  include GraphqlHelpers

  subject(:resolved_metrics) do
    context = { current_user: current_user }
    context[:report_type] = report_type_filter if defined?(report_type_filter)
    context[:project_id] = project_id_filter if defined?(project_id_filter)
    args = if defined?(custom_args)
             custom_args
           else
             { start_date: Date.parse('2019-10-15'),
               end_date: Date.parse('2019-10-17') }
           end

    resolve(described_class, obj: operate_on, args: args, ctx: context)
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
      { severity: :critical, report_type: :sast },
      { severity: :critical, report_type: :dast },
      { severity: :low, report_type: :sast },
      { severity: :medium, report_type: :dependency_scanning },
      { severity: :high, report_type: :sast },
      { severity: :high, report_type: :dependency_scanning }
    ]

    dates.flat_map do |date|
      severity_report_pairs.map do |config|
        create(
          :vulnerability,
          :with_read,
          report_type: config[:report_type],
          project: project,
          created_at: date,
          detected_at: date,
          severity: config[:severity]
        )
      end
    end
  end

  # `freeze: false` is required here: this `let_it_be` subject is a mutable
  # Array that examples append to (`<<`); freezing it raises FrozenError.
  # Keep the opt-out (see gitlab-org/gitlab#602925).
  let_it_be(:additional_project_vulnerabilities, freeze: false) do
    [
      create(:vulnerability, :with_read, severity: :critical, report_type: :sast, project: project_2,
        created_at: '2019-10-15', detected_at: '2019-10-15'),
      create(:vulnerability, :with_read, severity: :low, report_type: :dast, project: project_2,
        created_at: '2019-10-15', detected_at: '2019-10-15')
    ]
  end

  describe '#resolve' do
    let(:start_date) { Date.new(2019, 10, 15) }
    let(:end_date) { Date.new(2019, 10, 21) }

    before do
      stub_licensed_features(security_dashboard: true)
      stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
    end

    shared_examples 'counts vulnerabilities from specified projects' do
      it 'only counts vulnerabilities from specified projects' do
        expect(resolved_metrics).not_to be_empty
        expect(resolved_metrics['critical'][:count]).to eq(6)
        expect(resolved_metrics['low'][:count]).to eq(3)
        expect(resolved_metrics['medium'][:count]).to eq(3)
        expect(resolved_metrics['high'][:count]).to eq(6)
      end
    end

    shared_examples 'counts only open vulnerabilities' do
      # `freeze: false` is required here: this `let_it_be` subject is mutated
      # in-memory across examples in a way that survives both
      # `let_it_be_with_reload` and `let_it_be_with_refind` (e.g. a memoized
      # association/collection or a non-persisted attribute). Keeping it unfrozen
      # is the only correct cure (see gitlab-org/gitlab#602925).
      let_it_be(:additional_project_vulnerabilities, freeze: false) do
        additional_project_vulnerabilities << create(:vulnerability, :with_read, project: project, state: :resolved,
          report_type: :sast, severity: :critical, created_at: '2019-10-17', detected_at: '2019-10-17')

        additional_project_vulnerabilities << create(:vulnerability, :with_read, project: project, state: :resolved,
          report_type: :dast, severity: :critical, created_at: '2019-10-17', detected_at: '2019-10-17',
          resolved_on_default_branch: true)
      end

      it 'does not include the closed and resolved on default branch vulnerability' do
        expect(resolved_metrics.values.sum do |v|
          v[:count]
        end).to eq(
          operate_on.vulnerabilities.active.with_resolution(false).count)
      end
    end

    context 'when operated on a group' do
      let(:operate_on) { group }

      context 'when the current user has access' do
        before_all do
          group.add_maintainer(current_user)
        end

        before do
          Elastic::ProcessBookkeepingService.track!(*vulnerabilities, *additional_project_vulnerabilities)
          ensure_elasticsearch_index!
        end

        it 'returns vulnerability metrics data' do
          expect(resolved_metrics).not_to be_empty
          expect(resolved_metrics['critical'][:count]).to eq(7)
          expect(resolved_metrics['low'][:count]).to eq(4)
          expect(resolved_metrics['medium'][:count]).to eq(3)
          expect(resolved_metrics['high'][:count]).to eq(6)
        end

        it 'includes mean and median age for each severity', :aggregate_failures do
          expect(resolved_metrics['critical'][:mean_age]).to be_a(Float).and be > 0
          expect(resolved_metrics['critical'][:median_age]).to be_a(Float).and be > 0
          expect(resolved_metrics['low'][:mean_age]).to be_a(Float).and be > 0
          expect(resolved_metrics['low'][:median_age]).to be_a(Float).and be > 0
        end

        it_behaves_like 'counts only open vulnerabilities'

        context 'without date parameters' do
          let(:custom_args) { {} }

          it 'returns vulnerability metrics data for all vulnerabilities' do
            expect(resolved_metrics).not_to be_empty
            expect(resolved_metrics['critical'][:count]).to eq(7)
            expect(resolved_metrics['low'][:count]).to eq(4)
            expect(resolved_metrics['medium'][:count]).to eq(3)
            expect(resolved_metrics['high'][:count]).to eq(6)
          end
        end

        context 'with only start_date provided' do
          let(:custom_args) { { start_date: Date.parse('2019-10-16') } }

          it 'raises ArgumentError' do
            expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ArgumentError,
              "both start_date and end_date must be either nil or both must be present") do
              resolved_metrics
            end
          end
        end

        context 'with only end_date provided' do
          let(:custom_args) { { end_date: Date.parse('2019-10-16') } }

          it 'raises ArgumentError' do
            expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ArgumentError,
              "both start_date and end_date must be either nil or both must be present") do
              resolved_metrics
            end
          end
        end

        context 'when start_date is > end_date' do
          let(:custom_args) { { start_date: Date.parse('2019-10-17'), end_date: Date.parse('2019-10-16') } }

          it 'raises ArgumentError' do
            expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ArgumentError,
              "start date cannot be after end date") do
              resolved_metrics
            end
          end
        end

        context 'with project filtering' do
          let(:project_id_filter) { [project.id] }

          it_behaves_like 'counts vulnerabilities from specified projects'
        end

        context 'with report type filter' do
          let(:report_type_filter) { %w[sast] }

          it 'only counts vulnerabilities with filtered report types' do
            expect(resolved_metrics).not_to be_empty
            expect(resolved_metrics['critical'][:count]).to eq(4)
            expect(resolved_metrics['low'][:count]).to eq(3)
            expect(resolved_metrics['medium'][:count]).to eq(0)
            expect(resolved_metrics['high'][:count]).to eq(3)
          end
        end
      end

      context 'when the current user does not have access' do
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
          start_date: start_date,
          end_date: end_date
        }
        expected_params = {
          project_id: project.id,
          created_after: start_date,
          created_before: end_date,
          report_type: :sast,
          security_project_tracked_context_id: 123,
          has_resolution: false,
          state: %w[detected confirmed]
        }

        expect(Search::AdvancedFinders::Security::Vulnerability::CountBySeverityFinder)
          .to receive(:new)
          .with(operate_on, expected_params)
          .and_call_original

        resolve(described_class, obj: operate_on, args: args, ctx: context)
      end
    end

    context 'when operated on a project' do
      let(:operate_on) { project }

      context 'when the current user has access' do
        before_all do
          group.add_maintainer(current_user)
        end

        before do
          Elastic::ProcessBookkeepingService.track!(*vulnerabilities, *additional_project_vulnerabilities)
          ensure_elasticsearch_index!
        end

        it_behaves_like 'counts vulnerabilities from specified projects'

        it_behaves_like 'counts only open vulnerabilities'

        context 'with report type filter' do
          let(:report_type_filter) { %w[sast] }

          it 'only counts vulnerabilities with filtered report types' do
            expect(resolved_metrics).not_to be_empty
            expect(resolved_metrics['critical'][:count]).to eq(3)
            expect(resolved_metrics['low'][:count]).to eq(3)
            expect(resolved_metrics['medium'][:count]).to eq(0)
            expect(resolved_metrics['high'][:count]).to eq(3)
          end
        end
      end

      context 'when the current user does not have access' do
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
          start_date: start_date,
          end_date: end_date
        }
        expected_params = {
          project_id: project.id,
          created_after: start_date,
          created_before: end_date,
          report_type: :sast,
          security_project_tracked_context_id: 123,
          has_resolution: false,
          state: %w[detected confirmed]
        }

        expect(Search::AdvancedFinders::Security::Vulnerability::CountBySeverityFinder)
          .to receive(:new)
          .with(operate_on, expected_params)
          .and_call_original

        resolve(described_class, obj: operate_on, args: args, ctx: context)
      end
    end

    context 'when security_dashboard feature flag is disabled' do
      let(:operate_on) { group }

      before_all do
        group.add_maintainer(current_user)
      end

      before do
        stub_licensed_features(security_dashboard: false)
      end

      it_behaves_like 'returns resource not available'
    end
  end
end
