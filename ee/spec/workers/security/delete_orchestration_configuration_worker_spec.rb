# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::DeleteOrchestrationConfigurationWorker, "#perform", feature_category: :security_policy_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:policy_project) { create(:project) }
  let_it_be(:policy_configuration) do
    create(:security_orchestration_policy_configuration, security_policy_management_project: policy_project)
  end

  let_it_be(:read) do
    create(:scan_result_policy_read, security_orchestration_policy_configuration: policy_configuration)
  end

  let_it_be(:software_license_policy) { create(:software_license_policy, scan_result_policy_read: read) }
  let_it_be(:violation) { create(:scan_result_policy_violation, scan_result_policy_read: read) }
  let_it_be(:approval_project_rule) do
    create(:approval_project_rule,
      :scan_finding,
      security_orchestration_policy_configuration_id: policy_configuration.id)
  end

  let_it_be(:approval_merge_request_rule) do
    create(:report_approver_rule,
      :scan_finding,
      security_orchestration_policy_configuration_id: policy_configuration.id)
  end

  subject(:perform) { described_class.new.perform(policy_configuration.id, user.id, policy_project.id) }

  def record_exists?(record)
    record.class.exists?(record.id)
  end

  it 'deletes records' do
    expect { perform }
      .to change { record_exists?(policy_configuration) }.to(false)
            .and change { record_exists?(read) }.to(false)
            .and change { record_exists?(software_license_policy) }.to(false)
            .and change { record_exists?(violation) }.to(false)
            .and change { record_exists?(approval_project_rule) }.to(false)
            .and change { record_exists?(approval_merge_request_rule) }.to(false)
  end

  it 'audits' do
    expect(::Gitlab::Audit::Auditor).to receive(:audit).with(name: 'policy_project_updated', author: user,
      scope: policy_configuration.project, target: policy_project, message: kind_of(String))

    perform
  end

  describe 'deduplication' do
    let(:configuration_id) { 1 }
    let(:old_policy_project_id) { 2 }
    let(:user_id_a) { 3 }
    let(:user_id_b) { 4 }

    let(:job_a) { { 'class' => described_class.name, 'args' => [configuration_id, user_id_a, old_policy_project_id] } }
    let(:job_b) { { 'class' => described_class.name, 'args' => [configuration_id, user_id_b, old_policy_project_id] } }

    let(:duplicate_job_a) { Gitlab::SidekiqMiddleware::DuplicateJobs::DuplicateJob.new(job_a, 'test') }
    let(:duplicate_job_b) { Gitlab::SidekiqMiddleware::DuplicateJobs::DuplicateJob.new(job_b, 'test') }

    specify do
      expect(duplicate_job_a.send(:idempotency_key) == duplicate_job_b.send(:idempotency_key)).to be(true)
    end
  end
end
