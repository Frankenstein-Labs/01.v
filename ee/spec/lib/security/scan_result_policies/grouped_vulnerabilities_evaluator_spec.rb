# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::GroupedVulnerabilitiesEvaluator, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }

  let_it_be(:sast_vulnerability_high) do
    create(:vulnerability, :with_finding, project: project, report_type: :sast, severity: :high)
  end

  let_it_be(:sast_vulnerability_low) do
    create(:vulnerability, :with_finding, project: project, report_type: :sast, severity: :low)
  end

  let_it_be(:ds_vulnerability) do
    create(:vulnerability, :with_finding, project: project, report_type: :dependency_scanning, severity: :critical)
  end

  let_it_be(:cs_vulnerability) do
    create(:vulnerability, :with_finding, project: project, report_type: :container_scanning, severity: :high)
  end

  let(:evaluator) { described_class.new(project, params) }
  let(:empty_config_extra_params) { { severity: %w[high] } }

  it_behaves_like 'grouped evaluator concern'

  describe '#grouped_results' do
    subject(:grouped_results) { evaluator.grouped_results }

    context 'with per-scanner vulnerability_states and vulnerabilities_allowed' do
      let(:params) do
        {
          scanner_configurations: [
            {
              type: 'sast',
              severity_levels: %w[high],
              vulnerability_states: %w[detected],
              vulnerabilities_allowed: 1
            },
            {
              type: 'dependency_scanning',
              severity_levels: %w[critical],
              vulnerability_states: %w[confirmed],
              vulnerabilities_allowed: 0
            }
          ]
        }
      end

      it 'returns GroupResult structs with per-group attributes' do
        results = grouped_results

        expect(results).to be_an(Array)
        expect(results.length).to eq(2)

        results.each do |result|
          expect(result).to be_a(described_class::GroupResult)
          expect(result.vulnerabilities).to be_a(ActiveRecord::Relation)
        end

        sast_result = results.find { |r| r.vulnerabilities_allowed == 1 }
        ds_result = results.find { |r| r.vulnerabilities_allowed == 0 }

        expect(sast_result).to be_present
        expect(ds_result).to be_present
      end
    end

    context 'when scanners share identical attributes' do
      let(:params) do
        {
          scanner_configurations: [
            { type: 'sast', severity_levels: %w[high], vulnerabilities_allowed: 2 },
            { type: 'container_scanning', severity_levels: %w[high], vulnerabilities_allowed: 2 }
          ]
        }
      end

      it 'groups them into a single result' do
        results = grouped_results

        expect(results.length).to eq(1)
        expect(results.first.vulnerabilities).to include(sast_vulnerability_high, cs_vulnerability)
        expect(results.first.vulnerabilities_allowed).to eq(2)
      end
    end

    context 'with mixed per-scanner and inherited attributes' do
      let(:params) do
        {
          scanner_configurations: [
            {
              type: 'sast',
              severity_levels: %w[high],
              vulnerability_states: %w[detected],
              vulnerabilities_allowed: 1
            },
            {
              type: 'dependency_scanning'
            }
          ],
          severity: %w[critical],
          state: %w[confirmed],
          vulnerabilities_allowed: 3
        }
      end

      it 'uses per-scanner overrides where present and top-level defaults otherwise' do
        results = grouped_results

        expect(results.length).to eq(2)

        sast_result = results.find { |r| r.vulnerabilities_allowed == 1 }
        ds_result = results.find { |r| r.vulnerabilities_allowed == 3 }

        expect(sast_result).to be_present
        expect(ds_result).to be_present
      end
    end

    context 'when grouped scanners is empty' do
      let(:params) do
        {
          scanner_configurations: [
            { type: 'sast', severity_levels: %w[high] }
          ]
        }
      end

      before do
        allow(evaluator).to receive(:group_scanners_by_attributes).and_return({})
      end

      it 'returns an empty array' do
        expect(grouped_results).to eq([])
      end
    end
  end
end
