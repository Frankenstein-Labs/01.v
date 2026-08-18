# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ComplianceFramework::ComplianceRequirementsControls::UpdateStatusService,
  feature_category: :compliance_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, namespace: group) }
  let_it_be(:framework) { create(:compliance_framework, namespace: group) }
  let_it_be(:requirement) { create(:compliance_requirement, namespace: group, framework: framework) }
  let_it_be(:control) do
    create(:compliance_requirements_control, :external, compliance_requirement: requirement, namespace: group)
  end

  let_it_be(:control2) do
    create(:compliance_requirements_control, compliance_requirement: requirement, namespace: group)
  end

  let_it_be(:project_control_compliance_status) do
    create(:project_control_compliance_status,
      project: project,
      compliance_requirements_control: control,
      compliance_requirement: requirement,
      status: 'pending')
  end

  let_it_be(:project_control_compliance_status2) do
    create(:project_control_compliance_status,
      project: project,
      compliance_requirements_control: control2,
      compliance_requirement: requirement,
      status: 'fail')
  end

  let_it_be(:requirement_status) do
    create(:project_requirement_compliance_status,
      project: project,
      compliance_requirement: requirement,
      pass_count: 0,
      fail_count: 2,
      pending_count: 2
    )
  end

  let_it_be(:user) { create(:user) }

  subject(:service) do
    described_class.new(current_user: user, control: control, project: project, status_value: 'pass')
  end

  context 'when feature is disabled' do
    before do
      stub_licensed_features(custom_compliance_frameworks: false)
      allow(::Gitlab::Audit::Auditor).to receive(:audit)
    end

    it 'returns an error' do
      result = service.execute

      expect(result.success?).to be false
      expect(result.message).to eq(
        _('Failed to update compliance control status. Error: Not permitted to update compliance control status')
      )
    end
  end

  context 'when feature is enabled' do
    before do
      stub_licensed_features(custom_compliance_frameworks: true)
      allow(::Gitlab::Audit::Auditor).to receive(:audit)
    end

    shared_examples 'do not refresh requirement status' do
      it 'does not fetches requirement status' do
        expect(ComplianceManagement::ComplianceFramework::ProjectRequirementComplianceStatus)
          .not_to receive(:find_or_create_project_and_requirement)

        service.execute
      end
    end

    shared_context 'with requirement status refresh' do
      context 'when refresh_requirement_status is true' do
        subject(:service) do
          described_class.new(current_user: user, control: control, project: project, status_value: 'pass',
            params: { refresh_requirement_status: true }
          )
        end

        context 'when requirement status does not exist' do
          let(:refresh_service) do
            instance_double(ComplianceManagement::ComplianceFramework::ComplianceRequirements::RefreshStatusService)
          end

          before do
            ComplianceManagement::ComplianceFramework::ProjectRequirementComplianceStatus.delete_all
            allow(ComplianceManagement::ComplianceFramework::ComplianceRequirements::RefreshStatusService)
              .to receive(:new).and_return(refresh_service)
          end

          it 'creates a new requirement status', :aggregate_failures do
            expect(ComplianceManagement::ComplianceFramework::ProjectRequirementComplianceStatus)
              .to receive(:find_or_create_project_and_requirement)
              .and_call_original

            expect(refresh_service).to receive(:execute)

            service.execute
          end
        end

        context 'when requirement status exists' do
          it 'refreshes the requirement status' do
            expect { service.execute }.to change { requirement_status.reload.pass_count }.from(0).to(1)
              .and change { requirement_status.reload.fail_count }.from(2).to(1)
              .and change { requirement_status.reload.pending_count }.from(2).to(0)
          end
        end
      end

      context 'when refresh_requirement_status is false' do
        subject(:service) do
          described_class.new(current_user: user, control: control, project: project, status_value: 'pass',
            params: { refresh_requirement_status: false }
          )
        end

        it_behaves_like 'do not refresh requirement status'
      end

      context 'when refresh_requirement_status is nil' do
        it_behaves_like 'do not refresh requirement status'
      end
    end

    context 'when status is valid' do
      it 'updates the compliance requirement control status' do
        expect { service.execute }.to change { project_control_compliance_status.reload.status }.to('pass')
      end

      it 'is successful' do
        result = service.execute

        expect(result.success?).to be true
        expect(result.payload[:status]).to eq('pass')
      end

      it 'audits the changes' do
        service.execute

        expect(::Gitlab::Audit::Auditor).to have_received(:audit).with(
          name: 'compliance_control_status_pass',
          scope: project,
          target: project_control_compliance_status,
          message: "Changed compliance control status from 'pending' to 'pass'",
          author: user
        )
      end

      it 'does not track any events when changing from pending to pass' do
        expect { service.execute }.not_to trigger_internal_events
      end

      include_context 'with requirement status refresh'

      context 'when transitioning from pass to fail' do
        let(:fail_service) do
          described_class.new(current_user: user, control: control, project: project, status_value: 'fail')
        end

        before do
          described_class.new(current_user: user, control: control, project: project, status_value: 'pass').execute
        end

        it 'tracks a pass to fail event' do
          expect { fail_service.execute }
            .to trigger_internal_events('g_sscs_compliance_control_status_pass_to_fail')
            .with(
              user: user,
              namespace: project.namespace,
              project: project,
              additional_properties: {
                property: control.control_type.to_s
              }
            )
        end
      end

      context 'when transitioning from fail to pass' do
        before do
          described_class.new(current_user: user, control: control, project: project, status_value: 'fail').execute
        end

        it 'tracks a fail to pass event' do
          expect { service.execute }
            .to trigger_internal_events('g_sscs_compliance_control_status_fail_to_pass')
            .with(
              user: user,
              namespace: project.namespace,
              project: project,
              additional_properties: {
                property: control.control_type.to_s
              }
            )
        end
      end

      context 'when project control status does not exist' do
        before do
          ComplianceManagement::ComplianceFramework::ProjectControlComplianceStatus.delete_all
        end

        it 'creates a new project control compliance status' do
          expect { service.execute }.to change {
            ComplianceManagement::ComplianceFramework::ProjectControlComplianceStatus.count
          }.by(1)
        end

        it 'sets the correct attributes' do
          service.execute

          new_status = ComplianceManagement::ComplianceFramework::ProjectControlComplianceStatus.last
          expect(new_status.status).to eq('pass')
          expect(new_status.project_id).to eq(project.id)
          expect(new_status.compliance_requirements_control_id).to eq(control.id)
        end

        it 'does not track any events when creating a new pass status' do
          expect { service.execute }.not_to trigger_internal_events
        end
      end

      context 'when using an unauthenticated author' do
        let(:unauthenticated_author) { ::Gitlab::Audit::UnauthenticatedAuthor.new }
        let(:unauthenticated_service) do
          described_class.new(
            current_user: unauthenticated_author,
            control: control,
            project: project,
            status_value: 'pass'
          )
        end

        before do
          described_class.new(current_user: user, control: control, project: project, status_value: 'fail').execute
        end

        it 'updates the status successfully' do
          expect { unauthenticated_service.execute }.to change {
            project_control_compliance_status.reload.status
          }.to('pass')
        end

        it 'audits the changes with the unauthenticated author' do
          unauthenticated_service.execute

          expect(::Gitlab::Audit::Auditor).to have_received(:audit).with(
            name: 'compliance_control_status_pass',
            scope: project,
            target: project_control_compliance_status,
            message: "Changed compliance control status from 'fail' to 'pass'",
            author: unauthenticated_author
          )
        end

        it 'tracks the fail to pass event without a user parameter' do
          expect { unauthenticated_service.execute }
            .to trigger_internal_events('g_sscs_compliance_control_status_fail_to_pass')
            .with(
              namespace: project.namespace,
              project: project,
              additional_properties: {
                property: control.control_type.to_s
              }
            )
        end
      end

      context 'when the status is already the same as the requested status' do
        before do
          described_class.new(current_user: user, control: control, project: project, status_value: 'pass').execute
        end

        it 'does not audit when updating to the same status' do
          service.execute

          expect(::Gitlab::Audit::Auditor).not_to have_received(:audit).with(
            name: 'compliance_control_status_pass',
            scope: project,
            target: project_control_compliance_status,
            message: "Changed compliance control status from 'pass' to 'pass'",
            author: user
          )
        end

        it 'returns success' do
          result = service.execute

          expect(result.success?).to be true
          expect(result.payload[:status]).to eq('pass')
        end

        it 'does not track any events' do
          expect { service.execute }.not_to trigger_internal_events
        end

        include_context 'with requirement status refresh'
      end
    end

    context 'with invalid params' do
      shared_examples 'rejects invalid status' do |status|
        let(:invalid_service) do
          described_class.new(current_user: user, control: control, project: project, status_value: status)
        end

        it "does not update project control compliance status" do
          expect { invalid_service.execute }.not_to change { project_control_compliance_status.reload.attributes }
        end

        it "is unsuccessful" do
          result = invalid_service.execute

          expect(result.success?).to be false
          expect(result.message).to eq(
            "Failed to update compliance control status. Error: '#{status}' is not a valid status"
          )
        end

        it "does not audit the changes" do
          invalid_service.execute

          expect(::Gitlab::Audit::Auditor).not_to have_received(:audit)
        end

        it "does not track any events" do
          expect { invalid_service.execute }.not_to trigger_internal_events
        end
      end

      it_behaves_like 'rejects invalid status', 'pending'
      it_behaves_like 'rejects invalid status', 'invalid'
    end

    context 'when status update fails' do
      before do
        allow(project_control_compliance_status).to receive_messages(update: false,
          errors: instance_double(ActiveModel::Errors, full_messages: ['Some validation error']))
        allow(ComplianceManagement::ComplianceFramework::ProjectControlComplianceStatus)
          .to receive(:create_or_find_for_project_and_control)
          .with(project, control)
          .and_return(project_control_compliance_status)
      end

      it 'returns an error with validation messages' do
        result = service.execute

        expect(result.success?).to be false
        expect(result.message).to eq(
          'Failed to update compliance control status. Error: Some validation error'
        )
      end

      it 'does not audit the changes' do
        service.execute

        expect(::Gitlab::Audit::Auditor).not_to have_received(:audit)
      end

      it 'does not track any events' do
        expect { service.execute }.not_to trigger_internal_events
      end

      it_behaves_like 'do not refresh requirement status'
    end

    context 'when an ArgumentError is raised' do
      before do
        allow(service).to receive(:update_control_status).and_raise(ArgumentError, 'test error message')
        allow(service).to receive(:execute).and_wrap_original do |original|
          original.call
        rescue ArgumentError => e
          ServiceResponse.error(message: "Failed to update compliance control status. Error: #{e.message}")
        end
      end

      it 'returns an error response with the error message' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq('Failed to update compliance control status. Error: test error message')
      end

      it 'does not track any events' do
        expect { service.execute }.not_to trigger_internal_events
      end

      it_behaves_like 'do not refresh requirement status'
    end
  end
end
