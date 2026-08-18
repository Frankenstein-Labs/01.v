# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Findings::PolicySeverityOverrideChecker, feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:scan) { create(:security_scan, project: project) }

  subject(:checker) { described_class.new(project) }

  describe '#check_with_policy' do
    context 'when there are no policies' do
      it 'returns nil' do
        finding = create(:security_finding, :with_finding_data, scan: scan, severity: :low)

        expect(checker.check_with_policy(finding)).to be_nil
      end
    end

    context 'when there are policies with detected rules' do
      let_it_be(:policy) do
        create(:security_policy, :vulnerability_management_policy, :severity_override,
          severity_override_operation: 'set', severity_override_value: 'critical',
          linked_projects: [project])
      end

      let_it_be(:rule) do
        create(:vulnerability_management_policy_rule, :detected_file_path,
          security_policy: policy, file_path: 'test/**/*')
      end

      context 'when finding matches the rule' do
        let(:finding) do
          create(:security_finding, :with_finding_data, scan: scan, severity: :low,
            location: { file: 'test/spec/example_spec.rb' })
        end

        it 'returns severity and the winning policy' do
          result = checker.check_with_policy(finding)

          expect(result).to eq({ severity: 'critical', policy: policy })
        end
      end

      context 'when finding does not match the rule' do
        let(:finding) do
          create(:security_finding, :with_finding_data, scan: scan, severity: :low,
            location: { file: 'src/main.rb' })
        end

        it 'returns nil' do
          expect(checker.check_with_policy(finding)).to be_nil
        end
      end

      context 'when new severity equals current severity' do
        let_it_be(:same_severity_policy) do
          create(:security_policy, :vulnerability_management_policy, :severity_override,
            severity_override_operation: 'set', severity_override_value: 'low',
            linked_projects: [project])
        end

        let_it_be(:same_severity_rule) do
          create(:vulnerability_management_policy_rule, :detected_file_path,
            security_policy: same_severity_policy, file_path: 'src/**/*')
        end

        let(:finding) do
          create(:security_finding, :with_finding_data, scan: scan, severity: :low,
            location: { file: 'src/main.rb' })
        end

        it 'returns nil when severity would not change' do
          expect(described_class.new(project).check_with_policy(finding)).to be_nil
        end
      end
    end

    context 'with increase operation' do
      let_it_be(:policy) do
        create(:security_policy, :vulnerability_management_policy, :severity_override,
          severity_override_operation: 'increase', linked_projects: [project])
      end

      let_it_be(:rule) do
        create(:vulnerability_management_policy_rule, :detected_file_path,
          security_policy: policy, file_path: 'test/**/*')
      end

      it 'increases severity by one level' do
        finding = create(:security_finding, :with_finding_data, scan: scan, severity: :medium,
          location: { file: 'test/spec/example_spec.rb' })

        result = checker.check_with_policy(finding)

        expect(result).to eq({ severity: 'high', policy: policy })
      end

      it 'returns nil when already at max severity' do
        finding = create(:security_finding, :with_finding_data, scan: scan, severity: :critical,
          location: { file: 'test/spec/example_spec.rb' })

        expect(checker.check_with_policy(finding)).to be_nil
      end
    end

    context 'with decrease operation' do
      let_it_be(:policy) do
        create(:security_policy, :vulnerability_management_policy, :severity_override,
          severity_override_operation: 'decrease', linked_projects: [project])
      end

      let_it_be(:rule) do
        create(:vulnerability_management_policy_rule, :detected_file_path,
          security_policy: policy, file_path: 'test/**/*')
      end

      it 'decreases severity by one level' do
        finding = create(:security_finding, :with_finding_data, scan: scan, severity: :high,
          location: { file: 'test/spec/example_spec.rb' })

        result = checker.check_with_policy(finding)

        expect(result).to eq({ severity: 'medium', policy: policy })
      end

      it 'returns nil when already at min severity' do
        finding = create(:security_finding, :with_finding_data, scan: scan, severity: :info,
          location: { file: 'test/spec/example_spec.rb' })

        expect(checker.check_with_policy(finding)).to be_nil
      end
    end

    context 'when increase and decrease policies conflict' do
      let_it_be(:increase_policy) do
        create(:security_policy, :vulnerability_management_policy, :severity_override,
          severity_override_operation: 'increase', linked_projects: [project])
      end

      let_it_be(:increase_rule) do
        create(:vulnerability_management_policy_rule, :detected_file_path,
          security_policy: increase_policy, file_path: 'test/**/*')
      end

      let_it_be(:decrease_policy) do
        create(:security_policy, :vulnerability_management_policy, :severity_override,
          severity_override_operation: 'decrease', linked_projects: [project])
      end

      let_it_be(:decrease_rule) do
        create(:vulnerability_management_policy_rule, :detected_file_path,
          security_policy: decrease_policy, file_path: 'test/**/*')
      end

      it 'picks the highest severity when both match' do
        finding = create(:security_finding, :with_finding_data, scan: scan, severity: :medium,
          location: { file: 'test/spec/example_spec.rb' })

        # increase > high, decrease > low; highest wins > high
        result = described_class.new(project).check_with_policy(finding)

        expect(result[:severity]).to eq('high')
      end

      it 'increase at max severity blocks a competing decrease' do
        finding = create(:security_finding, :with_finding_data, scan: scan, severity: :critical,
          location: { file: 'test/spec/example_spec.rb' })

        # increase on critical > critical (boundary), decrease on critical > high
        # critical wins the competition, but equals current severity > nil (no override)
        expect(described_class.new(project).check_with_policy(finding)).to be_nil
      end

      it 'decrease at min severity loses to competing increase' do
        finding = create(:security_finding, :with_finding_data, scan: scan, severity: :info,
          location: { file: 'test/spec/example_spec.rb' })

        # decrease on info > info (boundary), increase on info > low (unknown is skipped)
        # low wins > override to low
        result = described_class.new(project).check_with_policy(finding)

        expect(result[:severity]).to eq('low')
      end
    end

    context 'when finding severity is unknown' do
      context 'with increase operation' do
        let_it_be(:policy) do
          create(:security_policy, :vulnerability_management_policy, :severity_override,
            severity_override_operation: 'increase', linked_projects: [project])
        end

        let_it_be(:rule) do
          create(:vulnerability_management_policy_rule, :detected_file_path,
            security_policy: policy, file_path: 'test/**/*')
        end

        it 'returns nil because unknown severity cannot be increased' do
          finding = create(:security_finding, :with_finding_data, scan: scan, severity: :unknown,
            location: { file: 'test/spec/example_spec.rb' })

          expect(described_class.new(project).check_with_policy(finding)).to be_nil
        end
      end

      context 'with decrease operation' do
        let_it_be(:policy) do
          create(:security_policy, :vulnerability_management_policy, :severity_override,
            severity_override_operation: 'decrease', linked_projects: [project])
        end

        let_it_be(:rule) do
          create(:vulnerability_management_policy_rule, :detected_file_path,
            security_policy: policy, file_path: 'test/**/*')
        end

        it 'returns nil because unknown severity cannot be decreased' do
          finding = create(:security_finding, :with_finding_data, scan: scan, severity: :unknown,
            location: { file: 'test/spec/example_spec.rb' })

          expect(described_class.new(project).check_with_policy(finding)).to be_nil
        end
      end

      context 'with set operation' do
        let_it_be(:policy) do
          create(:security_policy, :vulnerability_management_policy, :severity_override,
            severity_override_operation: 'set', severity_override_value: 'critical',
            linked_projects: [project])
        end

        let_it_be(:rule) do
          create(:vulnerability_management_policy_rule, :detected_file_path,
            security_policy: policy, file_path: 'test/**/*')
        end

        it 'still allows setting severity explicitly' do
          finding = create(:security_finding, :with_finding_data, scan: scan, severity: :unknown,
            location: { file: 'test/spec/example_spec.rb' })

          result = described_class.new(project).check_with_policy(finding)

          expect(result).to eq({ severity: 'critical', policy: policy })
        end
      end
    end
  end

  describe '#calculate_severity' do
    let(:action) { instance_double(Security::VulnerabilityManagementPolicies::Action) }

    it 'returns current severity for unrecognized operations' do
      allow(action).to receive(:severity_override_operation).and_return('unknown')

      result = checker.send(:calculate_severity, 'high', action)

      expect(result).to eq(:high)
    end
  end

  describe '#policies_present?' do
    context 'when no severity override policies exist' do
      it 'returns false' do
        expect(checker.policies_present?).to be(false)
      end
    end

    context 'when severity override policies exist' do
      let_it_be(:policy) do
        create(:security_policy, :vulnerability_management_policy, :severity_override,
          severity_override_operation: 'set', severity_override_value: 'critical',
          linked_projects: [project])
      end

      it 'returns true' do
        expect(described_class.new(project).policies_present?).to be(true)
      end
    end
  end
end
