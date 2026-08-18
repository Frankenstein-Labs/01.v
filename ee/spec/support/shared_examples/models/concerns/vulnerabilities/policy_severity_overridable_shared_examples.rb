# frozen_string_literal: true

RSpec.shared_examples_for 'policy severity overridable' do
  let_it_be(:project, freeze: false) { create(:project) }
  let(:feature_licensed) { true }

  before do
    stub_licensed_features(security_orchestration_policies: feature_licensed)
  end

  describe '#auto_severity_override' do
    context 'when auto_severity_override is set' do
      it 'returns the precomputed value' do
        finding = matching_finding.dup
        finding.auto_severity_override = 'critical'
        expect(finding.auto_severity_override).to eq('critical')
      end
    end

    context 'when the property is not set via preloading' do
      it 'returns nil' do
        expect(matching_finding.auto_severity_override).to be_nil
        expect(non_matching_finding.auto_severity_override).to be_nil
      end
    end
  end

  describe '.preload_severity_override_checks!' do
    shared_examples_for 'does not process severity override' do
      it 'does not set auto_severity_override for any findings', :aggregate_failures do
        expect(Security::Findings::PolicySeverityOverrideChecker).not_to receive(:new)

        result = described_class.preload_severity_override_checks!(project, [matching_finding, non_matching_finding])
        expect(result).to match_array([matching_finding, non_matching_finding])

        expect(matching_finding.auto_severity_override).to be_nil
        expect(non_matching_finding.auto_severity_override).to be_nil
      end
    end

    context 'when the feature is not licensed' do
      let(:feature_licensed) { false }

      it_behaves_like 'does not process severity override'
    end

    context 'when findings list is empty' do
      it 'returns the empty list' do
        result = described_class.preload_severity_override_checks!(project, [])
        expect(result).to eq([])
      end
    end

    context 'when there are no severity override policies' do
      it 'does not set auto_severity_override for any findings', :aggregate_failures do
        described_class.preload_severity_override_checks!(project, [matching_finding, non_matching_finding])

        expect(matching_finding.auto_severity_override).to be_nil
        expect(non_matching_finding.auto_severity_override).to be_nil
      end
    end

    context 'when there are severity override policies' do
      let_it_be(:policy, freeze: false) do
        create(:security_policy, :vulnerability_management_policy, :severity_override,
          severity_override_operation: 'set', severity_override_value: 'critical',
          linked_projects: [project])
      end

      let_it_be(:rule, freeze: false) do
        create(:vulnerability_management_policy_rule, :detected_file_path,
          security_policy: policy, **policy_rule_attributes)
      end

      before do
        described_class.preload_severity_override_checks!(project, [matching_finding, non_matching_finding])
      end

      it 'sets auto_severity_override to the overridden severity for matching findings' do
        expect(matching_finding.auto_severity_override).to eq('critical')
      end

      it 'does not set auto_severity_override for non-matching findings' do
        expect(non_matching_finding.auto_severity_override).to be_nil
      end

      context 'when matching finding already has the target severity' do
        before do
          matching_finding.auto_severity_override = nil
          matching_finding.severity = :critical
          described_class.preload_severity_override_checks!(project, [matching_finding])
        end

        it 'does not set auto_severity_override (no-op override)' do
          expect(matching_finding.auto_severity_override).to be_nil
        end
      end
    end
  end
end
