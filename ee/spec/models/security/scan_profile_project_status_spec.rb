# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanProfileProjectStatus, feature_category: :security_testing_configuration do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, namespace: group) }
  let_it_be(:scan_profile) { create(:security_scan_profile, namespace: group, scan_type: :sast) }
  let_it_be(:scan_profile_sd) { create(:security_scan_profile, namespace: group, scan_type: :secret_detection) }

  describe 'associations' do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:scan_profile).class_name('Security::ScanProfile') }
    it { is_expected.to belong_to(:build).class_name('Ci::Build').optional }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:status) }

    it 'validates consecutive_failure_count is non-negative' do
      is_expected.to validate_numericality_of(:consecutive_failure_count)
        .is_greater_than_or_equal_to(0)
    end

    it 'validates consecutive_success_count is non-negative' do
      is_expected.to validate_numericality_of(:consecutive_success_count)
        .is_greater_than_or_equal_to(0)
    end
  end

  describe 'enums' do
    it 'defines status enum with expected values' do
      is_expected.to define_enum_for(:status)
        .with_values(Enums::Security.scan_profile_statuses)
    end
  end

  describe 'scopes' do
    let_it_be(:other_project) { create(:project, namespace: group) }
    let_it_be(:sast_status) do
      create(:scan_profile_project_status, project: project, scan_profile: scan_profile)
    end

    let_it_be(:secret_detection_status) do
      create(:scan_profile_project_status, project: project, scan_profile: scan_profile_sd)
    end

    let_it_be(:other_project_status) do
      create(:scan_profile_project_status, project: other_project, scan_profile: scan_profile)
    end

    describe '.by_project' do
      it 'returns statuses for the specified project' do
        expect(described_class.by_project(project.id)).to match_array([sast_status, secret_detection_status])
      end
    end

    describe '.for_projects_and_profile' do
      it 'returns statuses for the given project IDs and profile' do
        result = described_class.for_projects_and_profile([project.id, other_project.id], scan_profile.id)

        expect(result).to match_array([sast_status, other_project_status])
      end

      it 'excludes statuses for other profiles' do
        result = described_class.for_projects_and_profile([project.id], scan_profile_sd.id)

        expect(result).to contain_exactly(secret_detection_status)
      end

      it 'returns empty when no matches' do
        result = described_class.for_projects_and_profile([non_existing_record_id], scan_profile.id)

        expect(result).to be_empty
      end
    end

    describe '.with_not_deleted_scan_profile' do
      it 'excludes statuses whose scan profile is soft-deleted' do
        # Re-find to avoid mutating the frozen let_it_be record.
        Security::ScanProfile.find(scan_profile_sd.id).destroy!

        expect(described_class.with_not_deleted_scan_profile)
          .to match_array([sast_status, other_project_status])
      end
    end

    describe '.for_scan_profile' do
      it 'returns statuses for the given profile' do
        expect(described_class.for_scan_profile(scan_profile.id))
          .to match_array([sast_status, other_project_status])
      end
    end
  end

  describe '#stale?' do
    using RSpec::Parameterized::TableSyntax

    let(:stale_time) { (described_class::STALE_THRESHOLD_DAYS + 1).days.ago }
    let(:recent_time) { 1.day.ago }

    where(:status, :last_scan_at, :expected) do
      :success        | ref(:stale_time)  | true
      :warning        | ref(:stale_time)  | true
      :failed         | ref(:stale_time)  | true
      :not_configured | ref(:stale_time)  | false
      :success        | nil               | false
      :success        | ref(:recent_time) | false
    end
    with_them do
      subject { build(:scan_profile_project_status, status: status, last_scan_at: last_scan_at) }

      it { is_expected.to have_attributes(stale?: expected) }
    end
  end

  describe '#active?' do
    using RSpec::Parameterized::TableSyntax

    let(:stale_time) { (described_class::STALE_THRESHOLD_DAYS + 1).days.ago }
    let(:recent_time) { 1.day.ago }

    where(:status, :last_scan_at, :expected) do
      :success        | ref(:recent_time) | true
      :success        | ref(:stale_time)  | false
      :warning        | ref(:recent_time) | false
      :failed         | ref(:recent_time) | false
      :not_configured | nil               | false
    end

    with_them do
      subject { build(:scan_profile_project_status, status: status, last_scan_at: last_scan_at) }

      it { is_expected.to have_attributes(active?: expected) }
    end
  end

  describe '#profile_failed?' do
    using RSpec::Parameterized::TableSyntax

    where(:status, :failure_count, :expected) do
      :failed  | ref(:threshold)         | true
      :failed  | ref(:above_threshold)   | true
      :failed  | ref(:below_threshold)   | false
      :success | ref(:above_threshold)   | false
    end

    let(:threshold) { described_class::FAILED_THRESHOLD }
    let(:above_threshold) { described_class::FAILED_THRESHOLD + 2 }
    let(:below_threshold) { described_class::FAILED_THRESHOLD - 1 }

    with_them do
      subject { build(:scan_profile_project_status, status: status, consecutive_failure_count: failure_count) }

      it { is_expected.to have_attributes(profile_failed?: expected) }
    end
  end

  context 'with loose foreign key on security_scan_profile_project_statuses.project_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:project) }
      let_it_be(:model) do
        create(:scan_profile_project_status, project: parent, scan_profile: scan_profile)
      end
    end
  end

  describe '#pending?' do
    using RSpec::Parameterized::TableSyntax

    where(:status, :last_scan_at, :expected) do
      :success        | nil       | true
      :warning        | nil       | true
      :failed         | nil       | true
      :not_configured | nil       | false
      :success        | 1.day.ago | false
    end

    with_them do
      subject { build(:scan_profile_project_status, status: status, last_scan_at: last_scan_at) }

      it { is_expected.to have_attributes(pending?: expected) }
    end
  end

  describe '#computed_status' do
    using RSpec::Parameterized::TableSyntax

    let(:stale_time) { (described_class::STALE_THRESHOLD_DAYS + 1).days.ago }
    let(:failed_threshold) { described_class::FAILED_THRESHOLD }
    let(:below_failed_threshold) { described_class::FAILED_THRESHOLD - 1 }

    where(:db_status, :failure_count, :last_scan_at, :expected) do
      :not_configured | 0                            | nil              | 'not_configured'
      :success        | 0                            | nil              | 'pending'
      :warning        | 0                            | nil              | 'pending'
      :failed         | 0                            | nil              | 'pending'
      :success        | 0                            | 1.day.ago        | 'active'
      :success        | 0                            | ref(:stale_time) | 'stale'
      :warning        | 2                            | 1.day.ago        | 'warning'
      :warning        | 2                            | ref(:stale_time) | 'stale'
      :failed         | ref(:failed_threshold)       | 1.day.ago        | 'failed'
      :failed         | ref(:failed_threshold)       | ref(:stale_time) | 'stale'
      :failed         | ref(:below_failed_threshold) | 1.day.ago        | 'warning'
    end

    with_them do
      let(:status_record) do
        build(:scan_profile_project_status,
          scan_profile: scan_profile,
          status: db_status,
          consecutive_failure_count: failure_count,
          last_scan_at: last_scan_at
        )
      end

      it { expect(status_record.computed_status).to eq(expected) }
    end
  end

  context 'with loose foreign key on security_scan_profile_project_statuses.build_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:ci_build) }
      let_it_be(:model) do
        create(:scan_profile_project_status, scan_profile: scan_profile, build: parent)
      end
    end
  end
end
