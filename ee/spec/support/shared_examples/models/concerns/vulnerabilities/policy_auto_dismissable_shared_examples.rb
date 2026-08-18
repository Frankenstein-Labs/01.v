# frozen_string_literal: true

RSpec.shared_examples_for 'policy auto-dismissable' do
  let_it_be(:project, freeze: false) { create(:project) }
  let(:feature_licensed) { true }

  before do
    stub_licensed_features(security_orchestration_policies: feature_licensed)
  end

  describe '#matches_auto_dismiss_policy?' do
    context 'when matches_auto_dismiss_policy is set' do
      it 'returns the precomputed value when true' do
        finding = matching_finding.dup
        finding.matches_auto_dismiss_policy = true
        expect(finding.matches_auto_dismiss_policy?).to be true
      end

      it 'returns the precomputed value when false' do
        finding = matching_finding.dup
        finding.matches_auto_dismiss_policy = false
        expect(finding.matches_auto_dismiss_policy?).to be false
      end
    end

    context 'when the property is not set via preloading' do
      it 'returns nil' do
        expect(matching_finding.matches_auto_dismiss_policy?).to be_nil
        expect(non_matching_finding.matches_auto_dismiss_policy?).to be_nil
      end
    end
  end

  describe '.preload_auto_dismissal_checks!' do
    shared_examples_for 'does not process auto-dismiss' do
      it 'sets matches_auto_dismiss_policy to nil for all findings without processing', :aggregate_failures do
        expect(Security::Findings::PolicyAutoDismissalChecker).not_to receive(:new)

        result = described_class.preload_auto_dismissal_checks!(project, [matching_finding, non_matching_finding])
        expect(result).to match_array([matching_finding, non_matching_finding])

        expect(matching_finding.matches_auto_dismiss_policy).to be_nil
        expect(non_matching_finding.matches_auto_dismiss_policy).to be_nil
      end
    end

    context 'when the feature is not licensed' do
      let(:feature_licensed) { false }

      it_behaves_like 'does not process auto-dismiss'
    end

    context 'when findings list is empty' do
      it 'returns the empty list' do
        result = described_class.preload_auto_dismissal_checks!(project, [])
        expect(result).to eq([])
      end
    end

    context 'when there are no auto-dismiss policies' do
      it 'sets matches_auto_dismiss_policy to false for all findings' do
        described_class.preload_auto_dismissal_checks!(project, [matching_finding, non_matching_finding])

        expect(matching_finding.matches_auto_dismiss_policy).to be false
        expect(non_matching_finding.matches_auto_dismiss_policy).to be false
      end
    end

    context 'when there are auto-dismiss policies' do
      let_it_be(:policy, freeze: false) do
        create(:security_policy, :vulnerability_management_policy, :auto_dismiss, linked_projects: [project])
      end

      let_it_be(:rule, freeze: false) do
        create(:vulnerability_management_policy_rule, :detected_file_path,
          security_policy: policy, **policy_rule_attributes)
      end

      before do
        described_class.preload_auto_dismissal_checks!(project, [matching_finding, non_matching_finding])
      end

      it 'sets matches_auto_dismiss_policy to true for matching findings' do
        expect(matching_finding.matches_auto_dismiss_policy).to be true
      end

      it 'sets matches_auto_dismiss_policy to false for non-matching findings' do
        expect(non_matching_finding.matches_auto_dismiss_policy).to be false
      end
    end
  end
end
