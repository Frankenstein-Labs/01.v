# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ComplianceFramework::ComplianceRequirements::RefreshStatusService,
  feature_category: :compliance_management do
  let_it_be(:namespace) { create(:group) }
  let_it_be(:project) { create(:project, namespace: namespace) }
  let_it_be(:framework) { create(:compliance_framework, namespace: namespace) }
  let_it_be(:requirement) { create(:compliance_requirement, framework: framework) }
  let_it_be_with_refind(:requirement_status) do
    create(:project_requirement_compliance_status, compliance_requirement: requirement, project: project,
      pass_count: 0, fail_count: 0, pending_count: 0)
  end

  context 'when requirement status is nil' do
    it 'returns error' do
      service = described_class.new(nil).execute

      expect(service.success?).to be false
      expect(service.message).to eq 'Failed to refresh compliance requirement status. Error: Requirement status is nil.'
    end
  end

  context 'when requirement status is not nil' do
    context 'when feature is licensed' do
      before do
        stub_licensed_features(custom_compliance_frameworks: true)
      end

      shared_examples 'error in refreshing' do
        it 'returns error' do
          service = described_class.new(requirement_status).execute

          expect(service.success?).to be false
          expect(service.message).to eq "Failed to refresh compliance requirement status. Error: Something wrong"
        end

        it 'tracks error' do
          expect(Gitlab::ErrorTracking).to receive(:log_exception).with(
            an_instance_of(ComplianceManagement::ComplianceFramework::ComplianceRequirements::
              RefreshStatusService::RefreshStatusError),
            requirement_status: requirement_status.id,
            requirement: requirement.id,
            project: project.id
          )

          described_class.new(requirement_status).execute
        end
      end

      context 'when there are no associated control statuses' do
        it 'destroys the requirement status' do
          expect { described_class.new(requirement_status).execute }.to change {
            ComplianceManagement::ComplianceFramework::ProjectRequirementComplianceStatus.count
          }.by(-1)
        end

        it 'is successful' do
          service = described_class.new(requirement_status).execute

          expect(service.success?).to be true
          expect(service.message).to eq(_('Compliance requirement status successfully refreshed.'))
        end

        context 'when destruction fails' do
          before do
            allow(requirement_status).to receive(:destroyed?).and_return(false)
            allow(requirement_status.errors).to receive(:full_messages).and_return(['Something wrong'])
          end

          it_behaves_like 'error in refreshing'
        end
      end

      context 'when there are associated control statuses' do
        let!(:control1) { create(:compliance_requirements_control, compliance_requirement: requirement) }
        let!(:control2) do
          create(:compliance_requirements_control, :external, compliance_requirement: requirement)
        end

        let!(:requirement2) { create(:compliance_requirement, framework: framework) }
        let!(:control21) { create(:compliance_requirements_control, compliance_requirement: requirement2) }

        before do
          create(:project_control_compliance_status, project: project, compliance_requirements_control: control1,
            status: :pass, compliance_requirement: requirement)
          create(:project_control_compliance_status, project: project, compliance_requirements_control: control2,
            status: :fail, compliance_requirement: requirement)

          create(:project_control_compliance_status, project: project, compliance_requirements_control: control21,
            status: :pass, compliance_requirement: requirement2)

          requirement_status.update!(pass_count: 1, fail_count: 2, pending_count: 1)
        end

        it 'updates the requirement status counts' do
          expect { described_class.new(requirement_status).execute }
            .to not_change { requirement_status.reload.pass_count }
            .and change { requirement_status.reload.fail_count }.from(2).to(1)
            .and change { requirement_status.reload.pending_count }.from(1).to(0)
        end

        it 'is successful' do
          service = described_class.new(requirement_status).execute

          expect(service.success?).to be true
          expect(service.message).to eq(_('Compliance requirement status successfully refreshed.'))
        end

        context 'when the status counts are same as previous ones' do
          before do
            requirement_status.update!(pass_count: 1, fail_count: 1, pending_count: 0)
          end

          it 'updates the updated_at timestamp' do
            expect { described_class.new(requirement_status).execute }
              .to change { requirement_status.reload.updated_at }
              .and not_change { requirement_status.reload.pass_count }
                     .and not_change { requirement_status.reload.fail_count }
                            .and not_change { requirement_status.reload.pending_count }
          end
        end

        context 'when update fails' do
          before do
            allow(requirement_status).to receive(:update).and_return(false)
            allow(requirement_status.errors).to receive(:full_messages).and_return(['Something wrong'])
          end

          it_behaves_like 'error in refreshing'
        end
      end
    end

    context 'when feature is not licensed' do
      before do
        stub_licensed_features(custom_compliance_frameworks: false)
      end

      it 'returns error' do
        service = described_class.new(requirement_status).execute

        expect(service.success?).to be false
        expect(service.message).to eq _("Failed to refresh compliance requirement status. Error: Not permitted to " \
          "refresh compliance requirement status")
      end

      it 'does not update requirement status' do
        expect { described_class.new(requirement_status).execute }.not_to change {
          requirement_status.reload.attributes
        }
      end
    end
  end
end
