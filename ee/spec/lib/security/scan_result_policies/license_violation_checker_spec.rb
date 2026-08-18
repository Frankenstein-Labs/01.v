# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::LicenseViolationChecker, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }

  let(:case5) do
    [
      ['GPL v3', 'GNU 3', 'A'],
      ['MIT', 'MIT License', 'B'],
      ['GPL v3', 'GNU 3', 'C'],
      ['Apache 2', 'Apache License 2', 'D']
    ]
  end

  let(:case4) { [['GPL v3', 'GNU 3', 'A'], ['MIT', 'MIT License', 'B'], ['GPL v3', 'GNU 3', 'C']] }
  let(:case3) { [['GPL v3', 'GNU 3', 'A'], ['MIT', 'MIT License', 'B']] }
  let(:case2) { [['GPL v3', 'GNU 3', 'A']] }
  let(:case1) { [] }

  let(:license_name_spdx_map) { { 'GNU 3' => 'GPL v3', 'MIT License' => 'MIT' } }

  describe 'possible combinations' do
    using RSpec::Parameterized::TableSyntax

    let(:violation1) { { 'GNU 3' => %w[A] } }
    let(:violation2) { { 'GNU 3' => %w[A C] } }
    let(:violation3) { { 'GNU 3' => %w[C] } }
    let(:violation4) { { 'Apache License 2' => %w[D] } }

    subject(:service) { described_class.new(project, pipeline_report, target_branch_report) }

    context 'with software_licenses' do
      include_context 'for license_checker'

      with_them do
        let_it_be(:target_branch_report) { create(:ci_reports_license_scanning_report) }
        let_it_be(:pipeline_report) { create(:ci_reports_license_scanning_report) }

        let(:match_on_inclusion_license) { policy_state == :denied }
        let(:license_states) { states }
        let(:license_name) { policy_license[1] }
        let(:scan_result_policy_read) do
          create(:scan_result_policy_read, project: project, license_states: license_states,
            match_on_inclusion_license: match_on_inclusion_license)
        end

        let(:approval_policy_source) do
          Security::ApprovalPolicySource.new(
            project: project, action_idx: 0, scan_result_policy_read: scan_result_policy_read
          )
        end

        before do
          target_branch.each do |ld|
            target_branch_report.add_license(id: ld[0], name: ld[1]).add_dependency(name: ld[2])
          end

          pipeline_branch.each do |ld|
            pipeline_report.add_license(id: ld[0], name: ld[1]).add_dependency(name: ld[2])
          end

          create(:software_license_policy, policy_state,
            project: project,
            scan_result_policy_read: scan_result_policy_read,
            software_license_spdx_identifier: license_name_spdx_map[license_name]
          )
        end

        it 'syncs approvals_required' do
          result = service.execute(approval_policy_source)

          expect(result).to eq(violated_licenses)
        end
      end
    end

    context 'with custom_software_licenses' do
      include_context 'for license_checker'

      with_them do
        let_it_be(:target_branch_report) { create(:ci_reports_license_scanning_report) }
        let_it_be(:pipeline_report) { create(:ci_reports_license_scanning_report) }

        let(:match_on_inclusion_license) { policy_state == :denied }
        let(:license_states) { states }

        let(:custom_license) { create(:custom_software_license, name: policy_license[1]) }
        let(:scan_result_policy_read) do
          create(:scan_result_policy_read, project: project, license_states: license_states,
            match_on_inclusion_license: match_on_inclusion_license)
        end

        let(:approval_policy_source) do
          Security::ApprovalPolicySource.new(
            project: project, action_idx: 0, scan_result_policy_read: scan_result_policy_read
          )
        end

        before do
          target_branch.each do |ld|
            target_branch_report.add_license(id: ld[0], name: ld[1]).add_dependency(name: ld[2])
          end

          pipeline_branch.each do |ld|
            pipeline_report.add_license(id: ld[0], name: ld[1]).add_dependency(name: ld[2])
          end

          create(:software_license_policy, policy_state,
            project: project,
            custom_software_license: custom_license,
            software_license_spdx_identifier: nil,
            scan_result_policy_read: scan_result_policy_read
          )
        end

        subject(:service_result) { service.execute(approval_policy_source) }

        it 'syncs approvals_required' do
          expect(service_result).to eq(violated_licenses)
        end
      end

      context 'with software licenses and custom_software_licenses' do
        include_context 'for license_checker'

        with_them do
          let_it_be(:target_branch_report) { create(:ci_reports_license_scanning_report) }
          let_it_be(:pipeline_report) { create(:ci_reports_license_scanning_report) }

          let(:match_on_inclusion_license) { policy_state == :denied }
          let(:license_states) { states }

          let(:catalog_license?) { policy_license[0].present? }

          let(:scan_result_policy_read) do
            create(:scan_result_policy_read, project: project, license_states: license_states,
              match_on_inclusion_license: match_on_inclusion_license)
          end

          let(:approval_policy_source) do
            Security::ApprovalPolicySource.new(
              project: project, action_idx: 0, scan_result_policy_read: scan_result_policy_read
            )
          end

          before do
            target_branch.each do |ld|
              target_branch_report.add_license(id: ld[0], name: ld[1]).add_dependency(name: ld[2])
            end

            pipeline_branch.each do |ld|
              pipeline_report.add_license(id: ld[0], name: ld[1]).add_dependency(name: ld[2])
            end

            if catalog_license?
              create(:software_license_policy, policy_state,
                project: project,
                custom_software_license: nil,
                scan_result_policy_read: scan_result_policy_read,
                software_license_spdx_identifier: policy_license[0]
              )
            else
              create(:software_license_policy, policy_state,
                project: project,
                custom_software_license: create(:custom_software_license, name: policy_license[1]),
                software_license_spdx_identifier: nil,
                scan_result_policy_read: scan_result_policy_read
              )
            end
          end

          it 'syncs approvals_required' do
            result = service.execute(approval_policy_source)

            expect(result).to eq(violated_licenses)
          end
        end
      end
    end

    context 'when backed by approval_policy_rule' do
      let_it_be(:target_branch_report) { create(:ci_reports_license_scanning_report) }
      let_it_be(:pipeline_report) { create(:ci_reports_license_scanning_report) }

      let(:approval_policy_rule) do
        create(:approval_policy_rule, :license_finding,
          content: {
            'type' => 'license_finding',
            'branches' => [],
            'match_on_inclusion_license' => true,
            'license_types' => ['GPL v3'],
            'license_states' => %w[detected]
          })
      end

      let(:scan_result_policy_read) do
        create(:scan_result_policy_read, project: project,
          license_states: %w[detected], match_on_inclusion_license: true,
          approval_policy_rule: approval_policy_rule)
      end

      let(:approval_policy_source) do
        Security::ApprovalPolicySource.new(
          project: project,
          action_idx: 0,
          scan_result_policy_read: scan_result_policy_read,
          approval_policy_rule: approval_policy_rule
        )
      end

      subject(:service) { described_class.new(project, pipeline_report, target_branch_report) }

      before do
        target_branch_report.add_license(id: 'GPL v3', name: 'GNU 3').add_dependency(name: 'A')

        create(:software_license_policy, :denied,
          project: project,
          approval_policy_rule: approval_policy_rule,
          scan_result_policy_read: scan_result_policy_read,
          software_license_spdx_identifier: 'GPL v3')
      end

      it 'queries by approval_policy_rule_id when flag is enabled' do
        result = service.execute(approval_policy_source)

        expect(result).to eq({ 'GNU 3' => ['A'] })
      end

      context 'when flag is disabled' do
        before do
          stub_feature_flags(deprecate_scan_result_policies: false)
        end

        it 'falls back to for_scan_result_policy_read' do
          result = service.execute(approval_policy_source)

          expect(result).to eq({ 'GNU 3' => ['A'] })
        end
      end
    end

    context 'when backed by approval_policy_rule with custom_software_license' do
      let_it_be(:target_branch_report) { create(:ci_reports_license_scanning_report) }
      let_it_be(:pipeline_report) { create(:ci_reports_license_scanning_report) }

      let(:approval_policy_rule) do
        create(:approval_policy_rule, :license_finding,
          content: {
            'type' => 'license_finding',
            'branches' => [],
            'match_on_inclusion_license' => true,
            'license_types' => ['Custom License'],
            'license_states' => %w[detected]
          })
      end

      let(:scan_result_policy_read) do
        create(:scan_result_policy_read, project: project,
          license_states: %w[detected], match_on_inclusion_license: true,
          approval_policy_rule: approval_policy_rule)
      end

      let(:approval_policy_source) do
        Security::ApprovalPolicySource.new(
          project: project,
          action_idx: 0,
          scan_result_policy_read: scan_result_policy_read,
          approval_policy_rule: approval_policy_rule
        )
      end

      subject(:service) { described_class.new(project, pipeline_report, target_branch_report) }

      before do
        target_branch_report.add_license(id: nil, name: 'Custom License').add_dependency(name: 'A')

        create(:software_license_policy, :denied,
          project: project,
          approval_policy_rule: approval_policy_rule,
          scan_result_policy_read: scan_result_policy_read,
          custom_software_license: create(:custom_software_license, name: 'Custom License'),
          software_license_spdx_identifier: nil)
      end

      it 'queries by approval_policy_rule_id when flag is enabled' do
        result = service.execute(approval_policy_source)

        expect(result).to eq({ 'Custom License' => ['A'] })
      end

      context 'when flag is disabled' do
        before do
          stub_feature_flags(deprecate_scan_result_policies: false)
        end

        it 'falls back to for_scan_result_policy_read' do
          result = service.execute(approval_policy_source)

          expect(result).to eq({ 'Custom License' => ['A'] })
        end
      end
    end

    context 'when backed by approval_policy_rule with software and custom_software_licenses' do
      let_it_be(:target_branch_report) { create(:ci_reports_license_scanning_report) }
      let_it_be(:pipeline_report) { create(:ci_reports_license_scanning_report) }

      let(:approval_policy_rule) do
        create(:approval_policy_rule, :license_finding,
          content: {
            'type' => 'license_finding',
            'branches' => [],
            'match_on_inclusion_license' => true,
            'license_types' => ['GPL v3', 'Custom License'],
            'license_states' => %w[detected]
          })
      end

      let(:scan_result_policy_read) do
        create(:scan_result_policy_read, project: project,
          license_states: %w[detected], match_on_inclusion_license: true,
          approval_policy_rule: approval_policy_rule)
      end

      let(:approval_policy_source) do
        Security::ApprovalPolicySource.new(
          project: project,
          action_idx: 0,
          scan_result_policy_read: scan_result_policy_read,
          approval_policy_rule: approval_policy_rule
        )
      end

      subject(:service) { described_class.new(project, pipeline_report, target_branch_report) }

      before do
        target_branch_report.add_license(id: 'GPL v3', name: 'GNU 3').add_dependency(name: 'A')
        target_branch_report.add_license(id: nil, name: 'Custom License').add_dependency(name: 'B')

        create(:software_license_policy, :denied,
          project: project,
          approval_policy_rule: approval_policy_rule,
          scan_result_policy_read: scan_result_policy_read,
          software_license_spdx_identifier: 'GPL v3')

        create(:software_license_policy, :denied,
          project: project,
          approval_policy_rule: approval_policy_rule,
          scan_result_policy_read: scan_result_policy_read,
          custom_software_license: create(:custom_software_license, name: 'Custom License'),
          software_license_spdx_identifier: nil)
      end

      it 'queries by approval_policy_rule_id when flag is enabled' do
        result = service.execute(approval_policy_source)

        expect(result).to eq({ 'GNU 3' => ['A'], 'Custom License' => ['B'] })
      end

      context 'when flag is disabled' do
        before do
          stub_feature_flags(deprecate_scan_result_policies: false)
        end

        it 'falls back to for_scan_result_policy_read' do
          result = service.execute(approval_policy_source)

          expect(result).to eq({ 'GNU 3' => ['A'], 'Custom License' => ['B'] })
        end
      end
    end
  end
end
