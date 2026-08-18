# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Findings::PolicyAutoDismissalChecker, feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:scan) { create(:security_scan, project: project) }

  subject(:checker) { described_class.new(project) }

  before do
    stub_licensed_features(security_orchestration_policies: true)
  end

  describe '#check' do
    context 'when there are no policies' do
      it 'returns false' do
        finding = create(:security_finding, :with_finding_data, scan: scan)

        result = checker.check(finding)

        expect(result).to be false
      end
    end

    context 'when there are policies but no rules' do
      let_it_be(:policy) do
        create(:security_policy, :vulnerability_management_policy, :auto_dismiss, linked_projects: [project])
      end

      it 'returns false' do
        finding = create(:security_finding, :with_finding_data, scan: scan)

        result = checker.check(finding)

        expect(result).to be false
      end
    end

    context 'when there are policies with detected rules' do
      let_it_be(:policy) do
        create(:security_policy, :vulnerability_management_policy, :auto_dismiss, linked_projects: [project])
      end

      let_it_be(:rule) do
        create(:vulnerability_management_policy_rule, :detected_file_path,
          security_policy: policy,
          file_path: 'test/**/*'
        )
      end

      subject(:check) { checker.check(finding) }

      context 'when finding matches the rule' do
        let(:finding) do
          create(:security_finding, :with_finding_data, scan: scan,
            location: { file: 'test/spec/example_spec.rb' })
        end

        it { is_expected.to be true }

        context 'when feature is not licensed' do
          before do
            stub_licensed_features(security_orchestration_policies: false)
          end

          it { is_expected.to be false }
        end
      end

      context 'when finding does not match the rule' do
        let(:finding) do
          create(:security_finding, :with_finding_data, scan: scan, location: { file: 'src/main.rb' })
        end

        it { is_expected.to be false }
      end

      context 'with multiple rules' do
        let_it_be(:rule2) do
          create(:vulnerability_management_policy_rule, :detected_identifier,
            security_policy: policy, identifier: 'CWE-99')
        end

        context 'when any rule matches' do
          let(:finding) do
            create(:security_finding, :with_finding_data, scan: scan,
              location: { file: 'test/spec/example_spec.rb' },
              identifiers: [create(:ci_reports_security_identifier, name: 'CWE-79').to_hash])
          end

          it { is_expected.to be true }
        end

        context 'when no rules match' do
          let(:finding) do
            create(:security_finding, :with_finding_data, scan: scan,
              location: { file: 'src/main.c' },
              identifiers: [create(:ci_reports_security_identifier, name: 'CWE-78').to_hash])
          end

          it { is_expected.to be false }
        end
      end
    end
  end

  describe '#check_batch' do
    context 'when there are no policies' do
      it 'returns an empty hash' do
        findings = [create(:security_finding, :with_finding_data, scan: scan)]

        result = checker.check_batch(findings)

        expect(result).to eq({})
      end
    end

    context 'when there are policies but no rules' do
      let_it_be(:policy) do
        create(:security_policy, :vulnerability_management_policy, :auto_dismiss, linked_projects: [project])
      end

      it 'returns a hash with all findings mapped to false' do
        finding1 = create(:security_finding, :with_finding_data, scan: scan)
        finding2 = create(:security_finding, :with_finding_data, scan: scan)
        findings = [finding1, finding2]

        result = checker.check_batch(findings)

        expect(result).to eq({
          finding1.uuid => false,
          finding2.uuid => false
        })
      end
    end

    context 'when there are policies with detected rules' do
      let_it_be(:policy) do
        create(:security_policy, :vulnerability_management_policy, :auto_dismiss, linked_projects: [project])
      end

      let_it_be(:rule) do
        create(:vulnerability_management_policy_rule, :detected_file_path,
          security_policy: policy,
          file_path: 'test/**/*'
        )
      end

      it 'returns a hash mapping finding UUIDs to match results' do
        matching_finding = create(:security_finding, :with_finding_data, scan: scan,
          location: { file: 'test/spec/example_spec.rb' })
        non_matching_finding = create(:security_finding, :with_finding_data, scan: scan,
          location: { file: 'src/main.rb' })

        findings = [matching_finding, non_matching_finding]

        result = checker.check_batch(findings)

        expect(result).to eq({
          matching_finding.uuid => true,
          non_matching_finding.uuid => false
        })
      end
    end

    context 'with empty findings array' do
      it 'returns an empty hash' do
        result = checker.check_batch([])

        expect(result).to eq({})
      end
    end
  end
end
