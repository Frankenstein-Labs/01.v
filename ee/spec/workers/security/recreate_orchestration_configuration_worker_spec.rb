# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::RecreateOrchestrationConfigurationWorker, '#perform', feature_category: :security_policy_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:policy_project) { create(:project) }
  let_it_be(:group) { create(:group, owners: [user]) }
  let_it_be(:policy_configuration) do
    create(:security_orchestration_policy_configuration, :namespace, namespace: group,
      security_policy_management_project: policy_project)
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

  let(:params) { {} }
  let(:configuration_id) { policy_configuration.id }

  before do
    stub_licensed_features(security_orchestration_policies: true)
    allow_next_found_instance_of(Security::OrchestrationPolicyConfiguration) do |instance|
      allow(instance).to receive(:policy_last_updated_by).and_return(user)
    end
  end

  subject(:perform) { described_class.new.perform(configuration_id, params) }

  def record_exists?(record)
    record.class.exists?(record.id)
  end

  include_examples 'an idempotent worker' do
    let(:job_args) { [configuration_id, params] }
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

  it 'triggers AssignService' do
    expect(Security::Orchestration::AssignService).to receive(:new).with(
      container: group, current_user: user, params: { policy_project_id: policy_project.id }
    ).and_call_original

    perform
  end

  it 'audits' do
    expect(::Gitlab::Audit::Auditor).to receive(:audit).with(name: 'policy_project_updated', author: user,
      scope: group, target: policy_project, message: kind_of(String))

    perform
  end

  describe 'deduplication' do
    let(:configuration_id) { 1 }

    let(:job_a) { { 'class' => described_class.name, 'args' => [configuration_id, { 'param1' => true }] } }
    let(:job_b) { { 'class' => described_class.name, 'args' => [configuration_id, { 'param2' => true }] } }

    let(:duplicate_job_a) { Gitlab::SidekiqMiddleware::DuplicateJobs::DuplicateJob.new(job_a, 'test') }
    let(:duplicate_job_b) { Gitlab::SidekiqMiddleware::DuplicateJobs::DuplicateJob.new(job_b, 'test') }

    specify do
      expect(duplicate_job_a.send(:idempotency_key) == duplicate_job_b.send(:idempotency_key)).to be(true)
    end
  end

  context 'when configuration does not exist' do
    let(:configuration_id) { non_existing_record_id }

    it 'returns early without performing any operations' do
      expect(Security::Orchestration::AssignService).not_to receive(:new)

      perform
    end

    it 'does not raise an error' do
      expect { perform }.not_to raise_error
    end
  end

  describe 'transaction failure handling' do
    before do
      allow(policy_configuration).to receive(:delete_scan_result_policy_reads)
      allow(policy_configuration).to receive(:delete_all_schedules)
    end

    context 'when ActiveRecord::RecordNotDestroyed is raised during transaction' do
      let(:exception) { ActiveRecord::RecordNotDestroyed.new('Deletion failed', policy_configuration) }

      before do
        allow_next_found_instance_of(Security::OrchestrationPolicyConfiguration) do |instance|
          allow(instance).to receive(:delete).and_raise(exception)
        end
      end

      it 'tracks the exception with Gitlab::ErrorTracking' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
          exception,
          configuration_id: policy_configuration.id
        )

        perform
      end

      it 'returns early without calling AssignService' do
        expect(Security::Orchestration::AssignService).not_to receive(:new)

        perform
      end

      it 'does not re-raise the exception' do
        expect { perform }.not_to raise_error
      end
    end

    context 'when exception is raised during delete_scan_result_policy_reads' do
      let(:exception) do
        ActiveRecord::RecordNotDestroyed.new('Failed to delete scan result policy reads', policy_configuration)
      end

      before do
        allow_next_found_instance_of(Security::OrchestrationPolicyConfiguration) do |instance|
          allow(instance).to receive(:delete_scan_result_policy_reads).and_raise(exception)
        end
      end

      it 'tracks the exception and returns early' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
          exception,
          configuration_id: policy_configuration.id
        )

        expect(Security::Orchestration::AssignService).not_to receive(:new)

        perform
      end
    end

    context 'when exception is raised during delete_all_schedules' do
      let(:exception) { ActiveRecord::RecordNotDestroyed.new('Failed to delete schedules', policy_configuration) }

      before do
        allow_next_found_instance_of(Security::OrchestrationPolicyConfiguration) do |instance|
          allow(instance).to receive(:delete_all_schedules).and_raise(exception)
        end
      end

      it 'tracks the exception and returns early' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
          exception,
          configuration_id: policy_configuration.id
        )

        expect(Security::Orchestration::AssignService).not_to receive(:new)

        perform
      end
    end
  end

  describe 'Security::Orchestration::AssignService failure handling' do
    before do
      allow_next_instance_of(Security::Orchestration::AssignService) do |instance|
        allow(instance).to receive(:execute).and_return(ServiceResponse.error(message: 'Error message'))
      end
    end

    it 'logs a warning' do
      expect(Gitlab::AppLogger).to receive(:warn).with(
        hash_including(
          'class' => 'Security::RecreateOrchestrationConfigurationWorker',
          'container_id' => group.id,
          'message' => 'Error message'
        )
      )

      perform
    end
  end
end
