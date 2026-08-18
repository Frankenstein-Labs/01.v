# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicyViolationDetail, feature_category: :security_policy_management do
  using RSpec::Parameterized::TableSyntax

  describe 'associations' do
    it { is_expected.to belong_to(:violation).class_name('Security::ScanResultPolicyViolation').required }
    it { is_expected.to belong_to(:project).required }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:policy_rule_type) }
    it { is_expected.to validate_length_of(:finding_uuid).is_at_most(50) }
    it { is_expected.to validate_length_of(:license_name).is_at_most(255) }

    describe 'metadata json_schema' do
      subject(:detail) do
        build(:scan_result_policy_violation_detail, metadata: metadata)
      end

      context 'with valid metadata' do
        where(:metadata) do
          [
            [nil],
            [{}],
            [{ 'total_dependencies_count' => 5 }],
            [{ 'total_commit_shas_count' => 3 }],
            [{ 'total_dependencies_count' => 10, 'total_commit_shas_count' => 2 }]
          ]
        end

        with_them do
          it { is_expected.to be_valid }
        end
      end

      context 'with invalid metadata' do
        where(:metadata) do
          [
            [{ 'unknown_key' => 1 }],
            [{ 'total_dependencies_count' => 'not_an_integer' }],
            [{ 'total_commit_shas_count' => -1 }]
          ]
        end

        with_them do
          it { is_expected.not_to be_valid }
        end
      end
    end
  end

  describe 'enums' do
    it 'defines policy_rule_type enum' do
      is_expected.to define_enum_for(:policy_rule_type)
        .with_values(scan_finding: 0, license_scanning: 1, any_merge_request: 2)
    end

    it 'defines finding_state enum' do
      is_expected.to define_enum_for(:finding_state)
        .with_values(newly_detected: 0, previously_existing: 1)
    end
  end

  describe '#total_dependencies_count' do
    subject(:detail) do
      build(:scan_result_policy_violation_detail, :license_scanning, metadata: metadata)
    end

    context 'when metadata contains total_dependencies_count' do
      let(:metadata) { { Security::ScanResultPolicyViolationDetail::METADATA_COUNT_DEPENDENCIES => 42 } }

      it 'returns the metadata value' do
        expect(detail.total_dependencies_count).to eq(42)
      end
    end

    context 'when metadata does not contain total_dependencies_count' do
      let(:metadata) { {} }

      it 'returns nil' do
        expect(detail.total_dependencies_count).to be_nil
      end
    end
  end

  describe '#total_commit_shas_count' do
    subject(:detail) do
      build(:scan_result_policy_violation_detail, :any_merge_request, metadata: metadata)
    end

    context 'when metadata contains total_commit_shas_count' do
      let(:metadata) { { Security::ScanResultPolicyViolationDetail::METADATA_COUNT_COMMIT_SHAS => 99 } }

      it 'returns the metadata value' do
        expect(detail.total_commit_shas_count).to eq(99)
      end
    end

    context 'when metadata does not contain total_commit_shas_count' do
      let(:metadata) { {} }

      it 'returns nil' do
        expect(detail.total_commit_shas_count).to be_nil
      end
    end
  end
end
