# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Security::VulnerabilitiesByIdentifierResolver, :elastic_delete_by_query, :elastic_helpers, :sidekiq_inline, feature_category: :vulnerability_management do
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
  let_it_be(:current_user) { create(:user) }

  let_it_be(:vulnerability_read_1) do
    vulnerability = create(:vulnerability, severity: :low, project: project)
    create(:vulnerability_read, vulnerability: vulnerability, identifier_names: ['CWE-79'], severity: :low,
      project: project)
  end

  let_it_be(:vulnerability_read_2) do
    vulnerability = create(:vulnerability, severity: :medium, project: project)
    create(:vulnerability_read, vulnerability: vulnerability, identifier_names: ['CWE-89'], severity: :medium,
      project: project)
  end

  let_it_be(:vulnerability_read_3) do
    vulnerability = create(:vulnerability, severity: :high, project: project)
    create(:vulnerability_read, vulnerability: vulnerability, identifier_names: ['CWE-79'], severity: :high,
      project: project)
  end

  let_it_be(:vulnerability_read_critical) do
    vulnerability = create(:vulnerability, severity: :critical, project: project)
    create(:vulnerability_read, vulnerability: vulnerability, identifier_names: ['CWE-79'], severity: :critical,
      project: project)
  end

  let_it_be(:vulnerability_read_4) do
    vulnerability = create(:vulnerability, severity: :critical, project: project_2)
    create(:vulnerability_read, vulnerability: vulnerability, identifier_names: ['CWE-200'], severity: :critical,
      project: project_2)
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

    shared_examples 'returns vulnerability identifier metrics' do
      context 'when the current user has access' do
        before_all do
          group.add_maintainer(current_user)
        end

        before do
          Elastic::ProcessBookkeepingService.track!(
            vulnerability_read_1, vulnerability_read_2, vulnerability_read_3,
            vulnerability_read_critical, vulnerability_read_4
          )
          ensure_elasticsearch_index!
        end

        it 'returns top CWE identifier metrics', :aggregate_failures do
          expect(resolved_metrics).to be_an(Array)
          expect(resolved_metrics).not_to be_empty

          cwe_names = resolved_metrics.pluck(:name)
          expect(cwe_names).to include('CWE-79', 'CWE-89')
        end

        it 'returns CWEs sorted by count with correct structure', :aggregate_failures do
          cwe_79 = resolved_metrics.find { |r| r[:name] == 'CWE-79' }
          expect(cwe_79).to be_present
          expect(cwe_79[:count]).to eq(3)
          expect(cwe_79[:url]).to eq('https://cwe.mitre.org/data/definitions/79.html')
          expect(cwe_79[:by_severity]).to be_an(Array)
        end

        it 'returns by_severity breakdown with downcased severity values', :aggregate_failures do
          cwe_79 = resolved_metrics.find { |r| r[:name] == 'CWE-79' }
          severities = cwe_79[:by_severity].pluck(:severity)
          expect(severities).to all(satisfy { |s| s == s.downcase })
          expect(cwe_79[:by_severity].find { |s| s[:severity] == 'low' }[:count]).to eq(1)
          expect(cwe_79[:by_severity].find { |s| s[:severity] == 'high' }[:count]).to eq(1)
          expect(cwe_79[:by_severity].find { |s| s[:severity] == 'critical' }[:count]).to eq(1)
        end

        context 'with severity filter argument' do
          let(:args) { { severity: ['critical'] } }

          it 'returns only CWEs matching the severity filter', :aggregate_failures do
            expect(resolved_metrics).to be_an(Array)
            expect(resolved_metrics).not_to be_empty

            resolved_metrics.each do |item|
              severities_with_counts = item[:by_severity].select { |s| s[:count] > 0 }.pluck(:severity)
              expect(severities_with_counts).to all(eq('critical'))
            end
          end
        end

        context 'when filtering on page-level' do
          context 'with single report type filtering' do
            let(:report_type_filter) { ['sast'] }

            it 'returns identifier metrics filtered by report type', :aggregate_failures do
              expect(resolved_metrics).to be_an(Array)
              expect(resolved_metrics).not_to be_empty
            end
          end

          context 'with multiple report types filtering' do
            let(:report_type_filter) { %w[sast dast] }

            it 'returns identifier metrics filtered by multiple report types', :aggregate_failures do
              expect(resolved_metrics).to be_an(Array)
              expect(resolved_metrics).not_to be_empty
            end
          end

          context 'when filtering on a single project' do
            let(:project_id_filter) { [project.id] }

            it 'returns identifier metrics for the given project', :aggregate_failures do
              expect(resolved_metrics).to be_an(Array)
              expect(resolved_metrics).not_to be_empty

              cwe_names = resolved_metrics.pluck(:name)
              expect(cwe_names).to include('CWE-79', 'CWE-89')
              expect(cwe_names).not_to include('CWE-200')
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

      it_behaves_like 'returns vulnerability identifier metrics'

      context 'when the current user has access' do
        before_all do
          group.add_maintainer(current_user)
        end

        before do
          Elastic::ProcessBookkeepingService.track!(
            vulnerability_read_1, vulnerability_read_2, vulnerability_read_3,
            vulnerability_read_critical, vulnerability_read_4
          )
          ensure_elasticsearch_index!
        end

        it 'includes CWEs from all projects in the group', :aggregate_failures do
          cwe_names = resolved_metrics.pluck(:name)
          expect(cwe_names).to include('CWE-79', 'CWE-89', 'CWE-200')
        end

        context 'with multiple projects filtering' do
          let(:project_id_filter) { [project.id, project_2.id] }

          it 'returns identifier metrics for all given projects', :aggregate_failures do
            expect(resolved_metrics).to be_an(Array)
            expect(resolved_metrics).not_to be_empty

            cwe_names = resolved_metrics.pluck(:name)
            expect(cwe_names).to include('CWE-79', 'CWE-89', 'CWE-200')
          end
        end
      end

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

        expect(Search::AdvancedFinders::Security::Vulnerability::TopCwesFinder)
          .to receive(:new)
          .with(operate_on, expected_params)
          .and_call_original

        resolve(described_class, obj: operate_on, args: args, ctx: context, lookahead: lookahead)
      end
    end

    context 'when operated on a project' do
      let(:operate_on) { project }

      it_behaves_like 'returns vulnerability identifier metrics'

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

        expect(Search::AdvancedFinders::Security::Vulnerability::TopCwesFinder)
          .to receive(:new)
          .with(operate_on, expected_params)
          .and_call_original

        resolve(described_class, obj: operate_on, args: args, ctx: context, lookahead: lookahead)
      end
    end

    context 'when transforming finder results' do
      let(:operate_on) { group }
      let(:finder_double) { instance_double(::Search::AdvancedFinders::Security::Vulnerability::TopCwesFinder) }

      before_all do
        group.add_maintainer(current_user)
      end

      before do
        allow(::Search::AdvancedFinders::Security::Vulnerability::TopCwesFinder)
          .to receive(:new).and_return(finder_double)
      end

      context 'when the finder returns no results' do
        before do
          allow(finder_double).to receive(:execute).and_return([])
        end

        it 'returns an empty array' do
          expect(resolved_metrics).to eq([])
        end
      end

      context 'when a result has a valid cwe key' do
        before do
          allow(finder_double).to receive(:execute).and_return([
            { "cwe" => "cwe-79", "count" => 1, "by_severity" => [] }
          ])
        end

        it 'returns the correct MITRE CWE url' do
          expect(resolved_metrics.first[:url]).to eq('https://cwe.mitre.org/data/definitions/79.html')
        end
      end

      context 'when a result has nil by_severity' do
        before do
          allow(finder_double).to receive(:execute).and_return([
            { "cwe" => "cwe-79", "count" => 1, "by_severity" => nil }
          ])
        end

        it 'returns an empty array for by_severity' do
          expect(resolved_metrics.first[:by_severity]).to eq([])
        end
      end
    end

    context 'when operated on an instance security dashboard' do
      let(:operate_on) { nil }

      before_all do
        group.add_maintainer(current_user)
      end

      it 'skips authorization check for instance security dashboard' do
        allow_next_instance_of(described_class) do |resolver|
          allow(resolver).to receive(:resolve_vulnerabilities_for_instance_security_dashboard?)
            .and_return(false)
        end

        expect(described_class).not_to receive(:authorize!)
      end
    end
  end
end
