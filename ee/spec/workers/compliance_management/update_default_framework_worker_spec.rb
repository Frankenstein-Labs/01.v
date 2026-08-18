# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::UpdateDefaultFrameworkWorker, feature_category: :compliance_management do
  # `freeze: false` is kept here because this `let_it_be` subject is not an
  # ActiveRecord record (it's a plain Hash/String/Array/Struct), so freezing
  # gives no cross-example isolation benefit and `let_it_be_with_reload`/
  # `refind` are no-ops on it. Keep as-is (see gitlab-org/gitlab#602925).
  let_it_be(:worker, freeze: false) { described_class.new }
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user, developer_of: group) }
  let_it_be_with_reload(:project) { create(:project, namespace: group) }
  let_it_be(:framework) { create(:compliance_framework, namespace: group, name: 'GDPR') }
  let_it_be(:admin_bot) { create(:user, :admin_bot, organization: project.organization) }

  let(:job_args) { [user.id, project.id, framework.id] }

  shared_examples 'updates the compliance framework for the project' do
    it do
      expect(project.compliance_management_frameworks).to eq([])

      worker.perform(*job_args)

      expect(project.reload.compliance_management_frameworks).to eq([framework])
    end
  end

  describe "#perform" do
    before do
      stub_licensed_features(custom_compliance_frameworks: true, compliance_framework: true)
    end

    it 'invokes ComplianceManagement::Frameworks::UpdateProjectService' do
      params = [project, admin_bot, [framework]]

      expect_next_instance_of(ComplianceManagement::Frameworks::UpdateProjectService, *params) do |assign_service|
        expect(assign_service).to receive(:execute).and_call_original
      end

      worker.perform(*job_args)
    end

    context 'when admin mode is not enabled', :do_not_mock_admin_mode_setting do
      include_examples 'updates the compliance framework for the project'
    end

    context 'when admin mode is enabled', :request_store do
      before do
        stub_application_setting(admin_mode: true)
      end

      include_examples 'updates the compliance framework for the project'
    end

    it_behaves_like 'an idempotent worker'

    context 'when framework is already assigned to the project' do
      before do
        project.compliance_management_frameworks << framework
      end

      it 'does not invoke the service' do
        expect(ComplianceManagement::Frameworks::UpdateProjectService).not_to receive(:new)

        worker.perform(*job_args)
      end
    end

    context 'when project does not exist' do
      it 'logs the exception and re-raises for retry' do
        expect(Gitlab::ErrorTracking).to receive(:track_and_raise_exception)
          .with(instance_of(ActiveRecord::RecordNotFound))
          .and_call_original

        expect do
          worker.perform(user.id, non_existing_record_id, framework.id)
        end.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when framework does not exist' do
      it 'logs the exception and re-raises for retry' do
        expect(Gitlab::ErrorTracking).to receive(:track_and_raise_exception)
          .with(instance_of(ActiveRecord::RecordNotFound))
          .and_call_original

        expect do
          worker.perform(user.id, project.id, non_existing_record_id)
        end.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when the service returns an error' do
      let(:error_message) { 'Something went wrong' }

      before do
        allow_next_instance_of(ComplianceManagement::Frameworks::UpdateProjectService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.error(message: error_message))
        end
      end

      it 'raises an error with the service message' do
        expect do
          worker.perform(*job_args)
        end.to raise_error("Failed to assign default compliance framework: #{error_message}")
      end
    end

    context 'when the service succeeds but the framework is not assigned' do
      before do
        allow_next_instance_of(ComplianceManagement::Frameworks::UpdateProjectService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.success)
        end
      end

      it 'raises an error to trigger a retry' do
        expect do
          worker.perform(*job_args)
        end.to raise_error("Default compliance framework was not assigned to project #{project.id}, will retry")
      end
    end
  end
end
