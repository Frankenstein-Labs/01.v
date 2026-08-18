# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::GroupedFindingsEvaluator, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:pipeline) { create(:ci_pipeline, project: project) }
  let_it_be(:sast_scan) { create(:security_scan, :latest_successful, scan_type: :sast, pipeline: pipeline) }
  let_it_be(:ds_scan) do
    create(:security_scan, :latest_successful, scan_type: :dependency_scanning, pipeline: pipeline)
  end

  let_it_be(:cs_scan) { create(:security_scan, :latest_successful, scan_type: :container_scanning, pipeline: pipeline) }

  let_it_be(:sast_finding_high) do
    create(:security_finding, scan: sast_scan, severity: :high)
  end

  let_it_be(:sast_finding_low) do
    create(:security_finding, scan: sast_scan, severity: :low)
  end

  let_it_be(:ds_finding) do
    create(:security_finding, scan: ds_scan, severity: :critical)
  end

  let_it_be(:cs_finding) do
    create(:security_finding, scan: cs_scan, severity: :high)
  end

  let(:evaluator) { described_class.new(project, pipeline, params) }
  let(:empty_config_extra_params) { { severity_levels: %w[high] } }

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

        sast_result = results.find { |r| r.uuids.include?(sast_finding_high.uuid) }
        ds_result = results.find { |r| r.uuids.include?(ds_finding.uuid) }

        expect(sast_result.vulnerabilities_allowed).to eq(1)
        expect(sast_result.vulnerability_states).to eq(%w[detected])

        expect(ds_result.vulnerabilities_allowed).to eq(0)
        expect(ds_result.vulnerability_states).to eq(%w[confirmed])
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
        expect(results.first.uuids).to include(sast_finding_high.uuid, cs_finding.uuid)
        expect(results.first.vulnerabilities_allowed).to eq(2)
      end
    end

    context 'with a malicious scanner_configuration' do
      let(:params) do
        {
          related_pipeline_ids: [pipeline.id],
          scanner_configurations: [
            {
              type: 'dependency_scanning',
              severity_levels: %w[critical],
              vulnerability_states: %w[detected],
              vulnerabilities_allowed: 1,
              is_malicious: true
            }
          ]
        }
      end

      context 'when the security_policies_malware_attribute flag is disabled' do
        before do
          stub_feature_flags(security_policies_malware_attribute: false)
        end

        it 'returns only the standard result', :aggregate_failures do
          results = grouped_results

          expect(results.length).to eq(1)
          expect(results.first.vulnerabilities_allowed).to eq(1)
          expect(results.first.vulnerability_states).to eq(%w[detected])
        end

        it 'never queries with malicious: true' do
          allow(Security::ScanResultPolicies::FindingsFinder).to receive(:new).and_call_original

          grouped_results

          expect(Security::ScanResultPolicies::FindingsFinder).not_to have_received(:new)
            .with(project, pipeline, hash_including(malicious: true))
        end
      end

      it 'returns an additional malicious GroupResult with vulnerabilities_allowed: 0', :aggregate_failures do
        results = grouped_results

        expect(results.length).to eq(2)

        malicious_result = results.first
        standard_result = results.last

        expect(malicious_result.vulnerabilities_allowed).to eq(0)
        expect(malicious_result.vulnerability_states).to be_nil

        expect(standard_result.vulnerabilities_allowed).to eq(1)
        expect(standard_result.vulnerability_states).to eq(%w[detected])
      end

      it 'queries the malicious findings without severity/state filters' do
        allow(Security::ScanResultPolicies::FindingsFinder).to receive(:new).and_call_original

        grouped_results

        expect(Security::ScanResultPolicies::FindingsFinder).to have_received(:new)
          .with(project, pipeline, {
            scanners: ['dependency_scanning'],
            malicious: true,
            related_pipeline_ids: [pipeline.id]
          })
      end
    end

    context 'when no scanner is malicious' do
      let(:params) do
        {
          scanner_configurations: [
            { type: 'sast', severity_levels: %w[high], vulnerabilities_allowed: 2 }
          ]
        }
      end

      it 'returns only the standard result', :aggregate_failures do
        results = grouped_results

        expect(results.length).to eq(1)
        expect(results.first.vulnerabilities_allowed).to eq(2)
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
