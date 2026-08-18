# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ComplianceFramework::ProjectControlStatuses::BulkDestroyService,
  feature_category: :compliance_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:project1) { create(:project, namespace: group) }
  let_it_be(:project2) { create(:project, namespace: group) }
  let_it_be(:framework1) { create(:compliance_framework, namespace: group, name: 'framework1') }

  let_it_be(:requirement11) { create(:compliance_requirement, framework: framework1) }
  let_it_be(:control1) { create(:compliance_requirements_control, compliance_requirement: requirement11) }

  let_it_be(:requirement12) { create(:compliance_requirement, framework: framework1) }
  let_it_be(:control2) { create(:compliance_requirements_control, compliance_requirement: requirement12) }
  let_it_be(:control3) { create(:compliance_requirements_control, :external, compliance_requirement: requirement12) }

  let_it_be(:framework2) { create(:compliance_framework, namespace: group, name: 'framework2') }
  let_it_be(:requirement21) { create(:compliance_requirement, framework: framework2) }
  let_it_be(:control4) { create(:compliance_requirements_control, compliance_requirement: requirement21) }

  let_it_be(:project1_control1_status) do
    create(:project_control_compliance_status, compliance_requirement: requirement11,
      compliance_requirements_control: control1, project: project1)
  end

  let_it_be(:project1_control2_status) do
    create(:project_control_compliance_status, compliance_requirement: requirement12,
      compliance_requirements_control: control2, project: project1)
  end

  let_it_be(:project1_control3_status) do
    create(:project_control_compliance_status, compliance_requirement: requirement12,
      compliance_requirements_control: control3, project: project1)
  end

  let_it_be(:project1_control4_status) do
    create(:project_control_compliance_status, compliance_requirement: requirement21,
      compliance_requirements_control: control4, project: project1)
  end

  let_it_be(:project2_control1_status) do
    create(:project_control_compliance_status, compliance_requirement: requirement11,
      compliance_requirements_control: control1, project: project2)
  end

  let_it_be(:project2_control2_status) do
    create(:project_control_compliance_status, compliance_requirement: requirement12,
      compliance_requirements_control: control2, project: project2)
  end

  let_it_be(:project2_control3_status) do
    create(:project_control_compliance_status, compliance_requirement: requirement12,
      compliance_requirements_control: control3, project: project2)
  end

  subject(:service) { described_class.new(project1.id, framework1.id) }

  describe '#execute' do
    context 'when project and framework has control statuses' do
      it 'destroys all related control status records' do
        expect { service.execute }.to change { project1.reload.project_control_compliance_statuses.count }.from(4).to(1)
      end

      it 'does not destroy statuses for the other framework records' do
        expect { service.execute }.to not_change {
          ComplianceManagement::ComplianceFramework::ProjectControlComplianceStatus.exists?(project1_control4_status.id)
        }
      end

      it 'does not destroy statuses for the other project records' do
        expect { service.execute }.to not_change { project2.reload.project_control_compliance_statuses.count }
      end

      it 'is successful' do
        response = service.execute

        expect(response).to be_success
        expect(response.message).to eq('Successfully deleted requirement statuses')
      end
    end

    context 'when project and framework does not have control statuses' do
      subject(:service) { described_class.new(project2.id, framework2.id) }

      it 'does not delete any record' do
        expect { service.execute }.not_to change {
          ComplianceManagement::ComplianceFramework::ProjectControlComplianceStatus.count
        }
      end

      it 'return success' do
        response = service.execute

        expect(response).to be_success
      end
    end
  end
end
