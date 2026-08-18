# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::TimeoutPendingExternalControlsWorker, feature_category: :compliance_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, namespace: group) }
  let_it_be(:framework) { create(:compliance_framework, namespace: group) }
  let_it_be(:compliance_requirement) { create(:compliance_requirement, namespace: group, framework: framework) }
  let_it_be(:control) do
    create(:compliance_requirements_control,
      :external,
      compliance_requirement: compliance_requirement,
      namespace: group)
  end

  let(:worker) { described_class.new }
  let(:args) { { control_id: control.id, project_id: project.id } }

  describe '#perform' do
    context 'when control does not exist' do
      let(:args) { { control_id: non_existing_record_id, project_id: project.id } }

      it 'does nothing' do
        expect(ComplianceManagement::ComplianceFramework::ProjectControlComplianceStatus)
          .not_to receive(:for_project_and_control)

        worker.perform(args)
      end
    end

    context 'when compliance status does not exist' do
      it 'does nothing' do
        expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

        worker.perform(args)
      end
    end

    context 'when compliance status exists' do
      let_it_be_with_reload(:compliance_status) do
        create(:project_control_compliance_status,
          project: project,
          compliance_requirements_control: control,
          compliance_requirement: compliance_requirement,
          status: :pending
        )
      end

      context 'when status is not pending' do
        before do
          compliance_status.update!(status: :fail)
        end

        it 'does nothing' do
          expect(compliance_status).not_to receive(:fail!)

          worker.perform(args)
        end
      end

      context 'when status was updated less than 30 minutes ago' do
        before do
          compliance_status.touch
        end

        it 'does nothing' do
          expect(compliance_status).not_to receive(:fail!)

          worker.perform(args)
        end
      end

      context 'when status is pending and was updated more than 30 minutes ago' do
        before do
          compliance_status.update!(updated_at: 31.minutes.ago)
        end

        it 'marks status as failed' do
          expect(compliance_status.reload.status).to eq("pending")

          worker.perform(args)

          expect(compliance_status.reload.status).to eq("fail")
        end

        it 'creates an audit event' do
          expected_message = "Project control compliance status with URL #{control.external_url} marked as fail."

          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
            hash_including(
              name: 'pending_compliance_external_control_failed',
              author: instance_of(::Gitlab::Audit::UnauthenticatedAuthor),
              scope: project,
              target: project,
              message: expected_message
            )
          )

          worker.perform(args)
        end
      end
    end

    context 'when args are strings' do
      let(:string_args) { { 'control_id' => control.id.to_s, 'project_id' => project.id.to_s } }

      it 'handles string keys' do
        expect(ComplianceManagement::ComplianceFramework::ComplianceRequirementsControl)
          .to receive(:find_by_id).with(control.id.to_s).and_return(control)

        worker.perform(string_args)
      end
    end
  end

  it_behaves_like 'an idempotent worker' do
    let(:job_args) { { control_id: control.id, project_id: project.id } }
  end
end
