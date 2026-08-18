# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::PolicyDismissal, feature_category: :security_policy_management do
  describe 'associations' do
    it { is_expected.to belong_to(:project).required }
    it { is_expected.to belong_to(:merge_request).required }
    it { is_expected.to belong_to(:security_policy).optional }
    it { is_expected.to belong_to(:user).optional }
  end

  describe 'validations' do
    subject(:policy_dismissal) { create(:policy_dismissal) }

    it { is_expected.to allow_value(nil).for(:security_findings_uuids) }
    it { is_expected.to validate_length_of(:comment).is_at_most(255).allow_nil }
    it { is_expected.to validate_length_of(:license_occurrence_uuids).is_at_most(1000) }

    it { is_expected.to(validate_uniqueness_of(:merge_request_id).scoped_to(%i[security_policy_id])) }

    context 'when validating dismissal_types' do
      it 'is invalid if empty' do
        policy_dismissal.dismissal_types = []
        expect(policy_dismissal).not_to be_valid
        expect(policy_dismissal.errors[:dismissal_types]).to include(/must be an array with allowed values/)
      end

      it 'is invalid if includes unknown value' do
        policy_dismissal.dismissal_types = described_class::DISMISSAL_TYPES.values + [999]
        expect(policy_dismissal).not_to be_valid
        expect(policy_dismissal.errors[:dismissal_types]).to include(/must be an array with allowed values/)
      end

      it 'is valid if all values are allowed' do
        policy_dismissal.dismissal_types = described_class::DISMISSAL_TYPES.values.sample(2)
        expect(policy_dismissal).to be_valid
      end
    end

    context 'when validating licenses' do
      it { is_expected.not_to allow_value('string').for(:licenses) }
      it { is_expected.to allow_value({}).for(:licenses) }

      context 'with a single license' do
        it { is_expected.to allow_value({ 'MIT License' => ['rack'] }).for(:licenses) }
        it { is_expected.to allow_value({ 'MIT License' => %w[rack bundler] }).for(:licenses) }
        it { is_expected.not_to allow_value({ '' => ['rack'] }).for(:licenses) }
        it { is_expected.not_to allow_value([{ 'MIT License' => ['rack'] }]).for(:licenses) }
      end

      context 'with multiple licenses' do
        it { is_expected.to allow_value({ 'MIT License' => ['rack'], 'Ruby License' => ['json'] }).for(:licenses) }
        it { is_expected.not_to allow_value({ 'MIT License' => ['rack'], '' => ['json'] }).for(:licenses) }

        it 'allows multiple components per license' do
          is_expected.to allow_value({ 'MIT License' => %w[rack bundler],
                                       'Apache License 2.0' => %w[aws-sdk-s3 aws-sdk-core] }).for(:licenses)
        end
      end
    end
  end

  describe 'scopes' do
    describe '.for_projects' do
      subject(:policy_dismissal_for_projects) { described_class.for_projects(projects) }

      let_it_be(:project) { create(:project) }
      let_it_be(:security_policy_dismissal) { create(:policy_dismissal, project: project) }
      let_it_be(:other_project) { create(:project) }
      let_it_be(:other_security_policy_dismissal) { create(:policy_dismissal, project: other_project) }

      context 'when querying for a single project' do
        let(:projects) { [project] }

        it 'returns dismissals for the given project' do
          expect(policy_dismissal_for_projects).to contain_exactly(security_policy_dismissal)
        end

        context 'with multiple dismissals for the same project' do
          let_it_be(:second_security_policy_dismissal) { create(:policy_dismissal, project: project) }

          it 'returns dismissals for the given project' do
            expect(policy_dismissal_for_projects).to contain_exactly(security_policy_dismissal,
              second_security_policy_dismissal)
          end
        end
      end

      context 'when querying for multiple projects' do
        let_it_be(:third_project) { create(:project) }
        let_it_be(:third_security_policy_dismissal) { create(:policy_dismissal, project: third_project) }

        let(:projects) { [project, other_project] }

        it 'returns dismissals for the given projects' do
          expect(policy_dismissal_for_projects).to contain_exactly(security_policy_dismissal,
            other_security_policy_dismissal)
        end

        context 'with multiple dismissals for the same project' do
          let_it_be(:second_security_policy_dismissal_project) { create(:policy_dismissal, project: project) }
          let_it_be(:second_security_policy_dismissal_other_project) do
            create(:policy_dismissal, project: other_project)
          end

          it 'returns dismissals for the given projects' do
            expect(policy_dismissal_for_projects).to contain_exactly(security_policy_dismissal,
              other_security_policy_dismissal,
              second_security_policy_dismissal_project,
              second_security_policy_dismissal_other_project)
          end
        end
      end
    end

    describe '.for_merge_requests' do
      subject(:policy_dismissal_for_merge_requests) { described_class.for_merge_requests(merge_requests) }

      let_it_be(:merge_request) { create(:merge_request) }
      let_it_be(:security_policy_dismissal) { create(:policy_dismissal, merge_request: merge_request) }
      let_it_be(:other_merge_request) { create(:merge_request) }
      let_it_be(:other_security_policy_dismissal) { create(:policy_dismissal, merge_request: other_merge_request) }

      context 'when querying for a single merge_request' do
        let(:merge_requests) { [merge_request.id] }

        it 'returns dismissals for the given merge_request' do
          expect(policy_dismissal_for_merge_requests).to contain_exactly(security_policy_dismissal)
        end

        context 'with multiple dismissals for the same merge_request' do
          let_it_be(:second_security_policy_dismissal) { create(:policy_dismissal, merge_request: merge_request) }

          it 'returns dismissals for the given merge_request' do
            expect(policy_dismissal_for_merge_requests).to contain_exactly(security_policy_dismissal,
              second_security_policy_dismissal)
          end
        end
      end

      context 'when querying for multiple merge_requests' do
        let_it_be(:third_merge_request) { create(:merge_request) }
        let_it_be(:third_security_policy_dismissal) { create(:policy_dismissal, merge_request: third_merge_request) }

        let(:merge_requests) { [merge_request.id, other_merge_request.id] }

        it 'returns dismissals for the given merge_requests' do
          expect(policy_dismissal_for_merge_requests).to contain_exactly(security_policy_dismissal,
            other_security_policy_dismissal)
        end

        context 'with multiple dismissals for the same merge_request' do
          let_it_be(:second_security_policy_dismissal_merge_request) do
            create(:policy_dismissal, merge_request: merge_request)
          end

          let_it_be(:second_security_policy_dismissal_other_merge_request) do
            create(:policy_dismissal, merge_request: other_merge_request)
          end

          it 'returns dismissals for the given merge_requests' do
            expect(policy_dismissal_for_merge_requests).to contain_exactly(security_policy_dismissal,
              other_security_policy_dismissal,
              second_security_policy_dismissal_merge_request,
              second_security_policy_dismissal_other_merge_request)
          end
        end
      end
    end

    describe '.for_security_findings_uuids' do
      let_it_be(:dismissed_finding) { SecureRandom.uuid }
      let_it_be(:non_dismissed_finding) { SecureRandom.uuid }
      let_it_be(:dismissed_findings) { [dismissed_finding] }
      let_it_be(:uuids) { [dismissed_finding] }

      let_it_be(:security_policy_dismissal) { create(:policy_dismissal, security_findings_uuids: dismissed_findings) }

      subject(:policy_dismissal_for_uuids) { described_class.for_security_findings_uuids(uuids) }

      context 'when querying for a single UUID' do
        it 'returns dismissals that contain the finding UUID' do
          expect(policy_dismissal_for_uuids).to contain_exactly(security_policy_dismissal)
        end
      end

      context 'when querying for multiple UUIDs' do
        let_it_be(:other_dismissed_finding) { SecureRandom.uuid }
        let_it_be(:uuids) { [dismissed_finding, other_dismissed_finding] }

        context 'when the UUIDs were dismissed by the same policy' do
          let_it_be(:dismissed_findings) { [dismissed_finding, other_dismissed_finding] }

          it 'returns dismissals that contain the vulnerability finding UUIDs' do
            expect(policy_dismissal_for_uuids).to contain_exactly(security_policy_dismissal)
          end
        end

        context 'when the UUIDs were dismissed by different policies' do
          let_it_be(:other_security_policy_dismissal) do
            create(:policy_dismissal, security_findings_uuids: [other_dismissed_finding])
          end

          it 'returns dismissals that contain the vulnerability finding UUIDs' do
            expect(policy_dismissal_for_uuids).to contain_exactly(security_policy_dismissal,
              other_security_policy_dismissal)
          end
        end
      end
    end

    describe '.for_license_occurrence_uuids' do
      let_it_be(:dismissed_license_occurrence_uuid) { SecureRandom.uuid }
      let_it_be(:non_dismissed_license_occurrence_uuid) { SecureRandom.uuid }
      let_it_be(:dismissed_license_occurrence_uuids) { [dismissed_license_occurrence_uuid] }
      let_it_be(:uuids) { [dismissed_license_occurrence_uuid] }

      subject(:policy_dismissal_for_license_occurrence_uuids) { described_class.for_license_occurrence_uuids(uuids) }

      context 'when the policy dismissal is not preserved' do
        let_it_be(:security_policy_dismissal) do
          create(:policy_dismissal, license_occurrence_uuids: dismissed_license_occurrence_uuids)
        end

        it 'returns none' do
          expect(policy_dismissal_for_license_occurrence_uuids).to be_empty
        end
      end

      context 'when the policy dismissal is preserved' do
        let_it_be(:security_policy_dismissal) do
          create(:policy_dismissal, :preserved, license_occurrence_uuids: dismissed_license_occurrence_uuids)
        end

        context 'when querying for a single UUID' do
          it 'returns dismissals that contain the finding UUID' do
            expect(policy_dismissal_for_license_occurrence_uuids).to contain_exactly(security_policy_dismissal)
          end
        end

        context 'when querying for multiple UUIDs' do
          let_it_be(:other_dismissed_license_occurrence_uuid) { SecureRandom.uuid }
          let_it_be(:uuids) { [dismissed_license_occurrence_uuid, other_dismissed_license_occurrence_uuid] }

          context 'when the license occurrence UUIDs were dismissed by the same policy' do
            let_it_be(:dismissed_license_occurrence_uuids) do
              [dismissed_license_occurrence_uuid, other_dismissed_license_occurrence_uuid]
            end

            it 'returns dismissals that contain the license occurrence UUIDs' do
              expect(policy_dismissal_for_license_occurrence_uuids).to contain_exactly(security_policy_dismissal)
            end
          end

          context 'when the license occurrence UUIDs were dismissed by different policies' do
            let_it_be(:other_security_policy_dismissal) do
              create(:policy_dismissal, :preserved, license_occurrence_uuids: [other_dismissed_license_occurrence_uuid])
            end

            it 'returns dismissals that contain the license occurrence UUIDs' do
              expect(policy_dismissal_for_license_occurrence_uuids).to contain_exactly(security_policy_dismissal,
                other_security_policy_dismissal)
            end
          end
        end
      end
    end

    describe '.including_merge_request_and_user' do
      let_it_be(:policy_dismissal) { create(:policy_dismissal) }

      it 'includes user and merge_request associations' do
        result = described_class.including_merge_request_and_user

        expect(result).to include(policy_dismissal)

        expect(result.first.association(:user)).to be_loaded
        expect(result.first.association(:merge_request)).to be_loaded
      end
    end

    describe '.including_project' do
      let_it_be(:policy_dismissal) { create(:policy_dismissal) }

      it 'includes project association' do
        result = described_class.including_project

        expect(result).to include(policy_dismissal)
        expect(result.first.association(:project)).to be_loaded
      end
    end

    describe '.including_security_policy' do
      let_it_be(:policy_dismissal) { create(:policy_dismissal) }

      it 'includes security_policy association' do
        result = described_class.including_security_policy

        expect(result).to include(policy_dismissal)
        expect(result.first.association(:security_policy)).to be_loaded
      end
    end
  end

  describe '.pluck_security_findings_uuid' do
    let_it_be(:dismissed_security_findings_uuid) { SecureRandom.uuid }
    let_it_be(:dismissed_security_findings_uuids) { [dismissed_security_findings_uuid] }

    subject(:security_findings_uuids) { described_class.pluck_security_findings_uuid }

    context 'when there is no policy dismissal with security_findings_uuids' do
      it 'returns none' do
        expect(security_findings_uuids).to be_empty
      end
    end

    context 'when there are policy dismissals with security_findings_uuids' do
      let_it_be(:security_policy_dismissal) do
        create(:policy_dismissal, security_findings_uuids: dismissed_security_findings_uuids)
      end

      it 'returns the security_findings_uuids' do
        expect(security_findings_uuids).to contain_exactly(dismissed_security_findings_uuid)
      end

      context 'when there are duplicated security_findings_uuids' do
        let_it_be(:other_security_policy_dismissal) do
          create(:policy_dismissal, security_findings_uuids: dismissed_security_findings_uuids)
        end

        it 'returns distinct security_findings_uuids' do
          expect(security_findings_uuids).to contain_exactly(dismissed_security_findings_uuid)
        end
      end

      context 'with multiple distinct security_findings_uuids' do
        let_it_be(:other_dismissed_security_findings_uuid) { SecureRandom.uuid }

        let_it_be(:other_security_policy_dismissal) do
          create(:policy_dismissal, security_findings_uuids: [other_dismissed_security_findings_uuid])
        end

        it 'returns all security_findings_uuids' do
          expect(security_findings_uuids).to contain_exactly(dismissed_security_findings_uuid,
            other_dismissed_security_findings_uuid)
        end
      end
    end
  end

  describe '.pluck_license_occurrence_uuid' do
    let_it_be(:dismissed_license_occurrence_uuid) { SecureRandom.uuid }
    let_it_be(:dismissed_license_occurrence_uuids) { [dismissed_license_occurrence_uuid] }

    subject(:license_occurrence_uuids) { described_class.pluck_license_occurrence_uuid }

    context 'when there is no policy dismissal with license_occurrence_uuids' do
      it 'returns none' do
        expect(license_occurrence_uuids).to be_empty
      end
    end

    context 'when there are policy dismissals with license_occurrence_uuids' do
      let_it_be(:security_policy_dismissal) do
        create(:policy_dismissal, license_occurrence_uuids: dismissed_license_occurrence_uuids)
      end

      it 'returns the license_occurrence_uuids' do
        expect(license_occurrence_uuids).to contain_exactly(dismissed_license_occurrence_uuid)
      end

      context 'when there are duplicated license_occurrence_uuids' do
        let_it_be(:other_security_policy_dismissal) do
          create(:policy_dismissal, license_occurrence_uuids: dismissed_license_occurrence_uuids)
        end

        it 'returns distinct license_occurrence_uuids' do
          expect(license_occurrence_uuids).to contain_exactly(dismissed_license_occurrence_uuid)
        end
      end

      context 'with multiple distinct license_occurrence_uuids' do
        let_it_be(:other_dismissed_license_occurrence_uuid) { SecureRandom.uuid }

        let_it_be(:other_security_policy_dismissal) do
          create(:policy_dismissal, license_occurrence_uuids: [other_dismissed_license_occurrence_uuid])
        end

        it 'returns all license_occurrence_uuids' do
          expect(license_occurrence_uuids).to contain_exactly(dismissed_license_occurrence_uuid,
            other_dismissed_license_occurrence_uuid)
        end
      end
    end
  end

  describe '#applicable_for_all_violations?' do
    let_it_be(:project) { create(:project) }
    let_it_be(:merge_request) { create(:merge_request, target_project: project, source_project: project) }
    let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration, project: project) }
    let_it_be(:security_policy) do
      create(:security_policy, security_orchestration_policy_configuration: policy_configuration)
    end

    let_it_be(:approval_policy_rule) { create(:approval_policy_rule, security_policy: security_policy) }

    context 'when dismissal covers all violation finding UUIDs and licenses' do
      let_it_be(:violation_1) do
        create(:scan_result_policy_violation,
          project: project,
          merge_request: merge_request,
          approval_policy_rule: approval_policy_rule,
          violation_data: {
            "violations" => {
              "scan_finding" => { "uuids" => { "newly_detected" => %w[uuid-1 uuid-2] } },
              "license_scanning" => { 'MIT License' => ['rack'] }
            }
          })
      end

      let_it_be(:violation_2) do
        create(:scan_result_policy_violation,
          project: project,
          merge_request: merge_request,
          approval_policy_rule: approval_policy_rule,
          violation_data: {
            "violations" => {
              "scan_finding" => { "uuids" => { "previously_existing" => ['uuid-3'] } },
              "license_scanning" => { 'Apache License 2.0' => ['bundler'] }
            }
          })
      end

      let_it_be(:policy_dismissal) do
        create(:policy_dismissal,
          project: project,
          merge_request: merge_request,
          security_policy: security_policy,
          security_findings_uuids: %w[uuid-1 uuid-2 uuid-3 uuid-4],
          licenses: { 'MIT License' => ['rack'], 'Apache License 2.0' => ['bundler'] })
      end

      it 'returns true when all violation finding UUIDs and licenses are covered' do
        expect(policy_dismissal.applicable_for_all_violations?).to be true
      end
    end

    context 'when dismissal covers all violation finding UUIDs' do
      let_it_be(:violation_1) do
        create(:scan_result_policy_violation, :new_scan_finding,
          project: project,
          merge_request: merge_request,
          approval_policy_rule: approval_policy_rule,
          uuids: %w[uuid-1 uuid-2])
      end

      let_it_be(:violation_2) do
        create(:scan_result_policy_violation, :previous_scan_finding,
          project: project,
          merge_request: merge_request,
          approval_policy_rule: approval_policy_rule,
          uuids: ['uuid-3'])
      end

      let_it_be(:policy_dismissal) do
        create(:policy_dismissal,
          project: project,
          merge_request: merge_request,
          security_policy: security_policy,
          security_findings_uuids: %w[uuid-1 uuid-2 uuid-3 uuid-4])
      end

      it 'returns true when all violation finding UUIDs are covered' do
        expect(policy_dismissal.applicable_for_all_violations?).to be true
      end
    end

    context 'when dismissal does not cover all violation finding UUIDs' do
      let_it_be(:violation_1) do
        create(:scan_result_policy_violation, :new_scan_finding,
          project: project,
          merge_request: merge_request,
          approval_policy_rule: approval_policy_rule,
          uuids: %w[uuid-1 uuid-2])
      end

      let_it_be(:violation_2) do
        create(:scan_result_policy_violation, :previous_scan_finding,
          project: project,
          merge_request: merge_request,
          approval_policy_rule: approval_policy_rule,
          uuids: ['uuid-3'])
      end

      let_it_be(:policy_dismissal) do
        create(:policy_dismissal,
          project: project,
          merge_request: merge_request,
          security_policy: security_policy,
          security_findings_uuids: %w[uuid-1 uuid-2])
      end

      it 'returns false when some violation finding UUIDs are missing' do
        expect(policy_dismissal.applicable_for_all_violations?).to be false
      end
    end

    context 'when there are no violations' do
      let_it_be(:policy_dismissal) do
        create(:policy_dismissal,
          project: project,
          merge_request: merge_request,
          security_policy: security_policy,
          security_findings_uuids: ['uuid-1'])
      end

      it 'returns true when there are no violations to check' do
        expect(policy_dismissal.applicable_for_all_violations?).to be true
      end
    end

    context 'when there are violations for other security policies' do
      let_it_be(:other_security_policy) do
        create(:security_policy, security_orchestration_policy_configuration: policy_configuration, policy_index: 1)
      end

      let_it_be(:other_approval_policy_rule) { create(:approval_policy_rule, security_policy: other_security_policy) }

      let_it_be(:matching_violation) do
        create(:scan_result_policy_violation, :new_scan_finding,
          project: project,
          merge_request: merge_request,
          approval_policy_rule: approval_policy_rule,
          uuids: ['uuid-1'])
      end

      let_it_be(:different_policy_violation) do
        create(:scan_result_policy_violation, :new_scan_finding,
          project: project,
          merge_request: merge_request,
          approval_policy_rule: other_approval_policy_rule,
          uuids: ['uuid-2'])
      end

      let_it_be(:policy_dismissal) do
        create(:policy_dismissal,
          project: project,
          merge_request: merge_request,
          security_policy: security_policy,
          security_findings_uuids: ['uuid-1'])
      end

      it 'only considers violations for the same security policy' do
        expect(policy_dismissal.applicable_for_all_violations?).to be true
      end
    end

    context 'when there are violations for other merge requests' do
      let_it_be(:different_mr) do
        create(:merge_request, target_project: project, source_project: project, source_branch: 'different-branch')
      end

      let_it_be(:matching_violation) do
        create(:scan_result_policy_violation, :new_scan_finding,
          project: project,
          merge_request: merge_request,
          approval_policy_rule: approval_policy_rule,
          uuids: ['uuid-1'])
      end

      let_it_be(:different_mr_violation) do
        create(:scan_result_policy_violation, :new_scan_finding,
          project: project,
          merge_request: different_mr,
          approval_policy_rule: approval_policy_rule,
          uuids: ['uuid-2'])
      end

      let_it_be(:policy_dismissal) do
        create(:policy_dismissal,
          project: project,
          merge_request: merge_request,
          security_policy: security_policy,
          security_findings_uuids: ['uuid-1'])
      end

      it 'only considers violations for the same merge request' do
        expect(policy_dismissal.applicable_for_all_violations?).to be true
      end
    end

    context 'when dismissal has empty security findings UUIDs' do
      let_it_be(:violation) do
        create(:scan_result_policy_violation, :new_scan_finding,
          project: project,
          merge_request: merge_request,
          approval_policy_rule: approval_policy_rule,
          uuids: ['uuid-1'])
      end

      let_it_be(:empty_dismissal) do
        create(:policy_dismissal,
          project: project,
          merge_request: merge_request,
          security_policy: security_policy,
          security_findings_uuids: [])
      end

      it 'returns false when security_findings_uuids is empty and there are violations' do
        expect(empty_dismissal.applicable_for_all_violations?).to be false
      end
    end

    context 'when dismissal does not cover all violation licenses' do
      let_it_be(:violation_1) do
        create(:scan_result_policy_violation,
          project: project,
          merge_request: merge_request,
          approval_policy_rule: approval_policy_rule,
          violation_data: {
            "violations" => {
              "scan_finding" => { "uuids" => { "newly_detected" => ['uuid-1'] } },
              "license_scanning" => { 'MIT License' => %w[rack bundler] }
            }
          })
      end

      let_it_be(:policy_dismissal) do
        create(:policy_dismissal,
          project: project,
          merge_request: merge_request,
          security_policy: security_policy,
          security_findings_uuids: ['uuid-1'],
          licenses: { 'MIT License' => ['rack'] })
      end

      it 'returns false when some violation license components are missing' do
        expect(policy_dismissal.applicable_for_all_violations?).to be false
      end
    end

    context 'when dismissal does not cover all violation license names' do
      let_it_be(:violation_1) do
        create(:scan_result_policy_violation,
          project: project,
          merge_request: merge_request,
          approval_policy_rule: approval_policy_rule,
          violation_data: {
            "violations" => {
              "scan_finding" => { "uuids" => { "newly_detected" => ['uuid-1'] } },
              "license_scanning" => { 'MIT License' => ['rack'], 'Apache License 2.0' => ['bundler'] }
            }
          })
      end

      let_it_be(:policy_dismissal) do
        create(:policy_dismissal,
          project: project,
          merge_request: merge_request,
          security_policy: security_policy,
          security_findings_uuids: ['uuid-1'],
          licenses: { 'MIT License' => ['rack'] })
      end

      it 'returns false when some violation licenses are missing' do
        expect(policy_dismissal.applicable_for_all_violations?).to be false
      end
    end
  end

  describe '#applicable_for_findings?' do
    let_it_be(:policy_dismissal) do
      create(:policy_dismissal, security_findings_uuids: %w[uuid-1 uuid-2 uuid-3])
    end

    it 'returns true for subset of UUIDs' do
      expect(policy_dismissal.applicable_for_findings?(%w[uuid-1 uuid-2])).to be true
    end

    it 'returns true for exact match of UUIDs' do
      expect(policy_dismissal.applicable_for_findings?(%w[uuid-1 uuid-2 uuid-3])).to be true
    end

    it 'returns true for empty array' do
      expect(policy_dismissal.applicable_for_findings?([])).to be true
    end

    it 'returns false when some UUIDs are missing' do
      expect(policy_dismissal.applicable_for_findings?(%w[uuid-1 uuid-4])).to be false
    end

    context 'when dismissal has no security findings UUIDs' do
      let_it_be(:empty_dismissal) { create(:policy_dismissal, security_findings_uuids: []) }

      it 'returns false for any provided UUIDs' do
        expect(empty_dismissal.applicable_for_findings?(['uuid-1'])).to be false
      end

      it 'returns true for empty array' do
        expect(empty_dismissal.applicable_for_findings?([])).to be true
      end
    end
  end

  describe '#preserve!' do
    let_it_be(:project) { create(:project) }
    let_it_be(:merge_request) { create(:merge_request, target_project: project, source_project: project) }
    let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration, project: project) }
    let_it_be(:security_policy) do
      create(:security_policy, security_orchestration_policy_configuration: policy_configuration)
    end

    let_it_be(:approval_policy_rule) { create(:approval_policy_rule, security_policy: security_policy) }

    subject(:preserve) { policy_dismissal.preserve! }

    before do
      allow(Gitlab::EventStore).to receive(:publish)
    end

    context 'when dismissal is applicable for all violations' do
      let_it_be(:violation) do
        create(:scan_result_policy_violation, :new_scan_finding,
          project: project,
          merge_request: merge_request,
          approval_policy_rule: approval_policy_rule,
          uuids: %w[uuid-1 uuid-2])
      end

      let(:policy_dismissal) do
        create(:policy_dismissal,
          project: project,
          merge_request: merge_request,
          security_policy: security_policy,
          security_findings_uuids: %w[uuid-1 uuid-2 uuid-3])
      end

      it 'changes status to preserved and publishes event', :aggregate_failures do
        expect { preserve }.to change { policy_dismissal.reload.status }.from('open').to('preserved')

        expect(Gitlab::EventStore).to have_received(:publish) do |event|
          expect(event).to be_a(Security::PolicyDismissalPreservedEvent)
          expect(event.data[:security_policy_dismissal_id]).to eq(policy_dismissal.id)
        end
      end
    end

    context 'when dismissal is for any_merge_request policy' do
      let(:policy_dismissal) do
        create(:policy_dismissal,
          project: project,
          merge_request: merge_request,
          security_policy: security_policy,
          security_findings_uuids: [],
          licenses: {})
      end

      it 'changes status to preserved and publishes event', :aggregate_failures do
        expect { preserve }.to change { policy_dismissal.reload.status }.from('open').to('preserved')

        expect(Gitlab::EventStore).to have_received(:publish) do |event|
          expect(event).to be_a(Security::PolicyDismissalPreservedEvent)
          expect(event.data[:security_policy_dismissal_id]).to eq(policy_dismissal.id)
        end
      end
    end

    context 'when dismissal is not applicable for all violations' do
      let_it_be(:violation) do
        create(:scan_result_policy_violation, :new_scan_finding,
          project: project,
          merge_request: merge_request,
          approval_policy_rule: approval_policy_rule,
          uuids: %w[uuid-1 uuid-2 uuid-3])
      end

      let(:policy_dismissal) do
        create(:policy_dismissal,
          project: project,
          merge_request: merge_request,
          security_policy: security_policy,
          security_findings_uuids: %w[uuid-1 uuid-2])
      end

      it 'destroys the dismissal instead of preserving it' do
        policy_dismissal.id

        expect { preserve }.to change { described_class.count }.by(-1)
      end

      it 'does not publish the preserved event when destroyed' do
        preserve

        expect(Gitlab::EventStore).not_to have_received(:publish)
      end
    end
  end

  describe '#license_names' do
    let_it_be(:project) { create(:project) }
    let_it_be(:merge_request) { create(:merge_request, target_project: project, source_project: project) }
    let(:policy_dismissal) do
      create(:policy_dismissal, project: project, merge_request: merge_request, licenses: licenses)
    end

    subject(:license_names) { policy_dismissal.license_names }

    context 'without licenses' do
      let(:licenses) { {} }

      it 'returns an empty array' do
        expect(license_names).to be_empty
      end

      context 'with licenses' do
        let(:mit_license) { 'MIT License' }

        context 'with a single license' do
          let(:licenses) { { mit_license => ['rack'] } }

          it 'returns the license name' do
            expect(license_names).to match_array([mit_license])
          end
        end

        context 'with multiple licenses' do
          let(:ruby_license) { 'Ruby' }

          let(:licenses) { { mit_license => ['rack'], ruby_license => ['json'] } }

          it 'returns all license names' do
            expect(license_names).to match_array([mit_license, ruby_license])
          end
        end
      end
    end
  end

  describe '#components' do
    let_it_be(:project) { create(:project) }
    let_it_be(:merge_request) { create(:merge_request, target_project: project, source_project: project) }
    let(:policy_dismissal) do
      create(:policy_dismissal, project: project, merge_request: merge_request, licenses: licenses)
    end

    subject(:components) { policy_dismissal.components(license_name) }

    context 'without licenses' do
      let(:licenses) { {} }
      let(:license_name) { 'MIT License' }

      it 'returns an empty array' do
        expect(components).to be_empty
      end
    end

    context 'with licenses' do
      let(:license_name) { 'MIT License' }
      let(:licenses) { { license_name => components_list } }

      context 'when the license has a single component' do
        let(:components_list) { ['rack'] }

        it 'returns the component' do
          expect(components).to match_array(components_list)
        end
      end

      context 'when the license has multiple components' do
        let(:components_list) { %w[rack bundler] }

        it 'returns all components' do
          expect(components).to match_array(components_list)
        end
      end
    end
  end

  describe '#applicable_for_licenses?' do
    let_it_be(:project) { create(:project) }
    let_it_be(:merge_request) { create(:merge_request, target_project: project, source_project: project) }
    let(:policy_dismissal) do
      create(:policy_dismissal, project: project, merge_request: merge_request, licenses: dismissed_licenses)
    end

    subject(:applicable_for_licenses) { policy_dismissal.applicable_for_licenses?(violation_licenses) }

    context 'when dismissal has no licenses' do
      let(:dismissed_licenses) { {} }
      let(:violation_licenses) { { 'MIT License' => ['rack'] } }

      it 'returns false' do
        expect(applicable_for_licenses).to be false
      end
    end

    context 'when dismissal covers all violation licenses' do
      let(:dismissed_licenses) { { 'MIT License' => %w[rack bundler], 'Apache License 2.0' => ['json'] } }
      let(:violation_licenses) { { 'MIT License' => ['rack'], 'Apache License 2.0' => ['json'] } }

      it 'returns true' do
        expect(applicable_for_licenses).to be true
      end
    end

    context 'when dismissal covers a subset of components for a license' do
      let(:dismissed_licenses) { { 'MIT License' => ['rack'] } }
      let(:violation_licenses) { { 'MIT License' => %w[rack bundler] } }

      it 'returns false' do
        expect(applicable_for_licenses).to be false
      end
    end

    context 'when dismissal is missing a license' do
      let(:dismissed_licenses) { { 'MIT License' => ['rack'] } }
      let(:violation_licenses) { { 'MIT License' => ['rack'], 'Apache License 2.0' => ['json'] } }

      it 'returns false' do
        expect(applicable_for_licenses).to be false
      end
    end
  end
end
