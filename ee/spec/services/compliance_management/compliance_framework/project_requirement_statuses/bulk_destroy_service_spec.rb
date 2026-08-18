# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ComplianceFramework::ProjectRequirementStatuses::BulkDestroyService,
  feature_category: :compliance_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:project1) { create(:project, name: "Test Project", namespace: group) }
  let_it_be(:project2) { create(:project, name: "Test Project2", namespace: group) }

  let_it_be(:framework1) { create(:compliance_framework, name: 'Test Framework', namespace: group) }
  let_it_be(:requirement1) { create(:compliance_requirement, name: 'First Requirement', framework: framework1) }
  let_it_be(:requirement2) { create(:compliance_requirement, name: 'Second Requirement', framework: framework1) }

  let_it_be(:framework2) { create(:compliance_framework, name: 'Test Framework2', namespace: group) }
  let_it_be(:requirement3) { create(:compliance_requirement, name: 'First Requirement', framework: framework2) }

  let(:project1_requirement1_status) do
    create(:project_requirement_compliance_status,
      project_id: project1.id,
      compliance_requirement: requirement1,
      compliance_framework: framework1
    )
  end

  let(:project1_requirement2_status) do
    create(:project_requirement_compliance_status,
      project_id: project1.id,
      compliance_requirement: requirement2,
      compliance_framework: framework1
    )
  end

  let(:project1_requirement3_status) do
    create(:project_requirement_compliance_status,
      project_id: project1.id,
      compliance_requirement: requirement3,
      compliance_framework: framework2
    )
  end

  let(:project2_requirement1_status) do
    create(:project_requirement_compliance_status,
      project_id: project2.id,
      compliance_requirement: requirement1,
      compliance_framework: framework1
    )
  end

  let(:project2_requirement2_status) do
    create(:project_requirement_compliance_status,
      project_id: project2.id,
      compliance_requirement: requirement2,
      compliance_framework: framework1
    )
  end

  subject(:service) { described_class.new(project1.id, framework1.id) }

  describe '#execute' do
    it 'delete all the records which belongs to the project framework pair' do
      expect { service.execute }
        .to change {
          ComplianceManagement::ComplianceFramework::ProjectRequirementComplianceStatus
            .exists?(project1_requirement1_status.id)
        }.from(true).to(false)
        .and change {
          ComplianceManagement::ComplianceFramework::ProjectRequirementComplianceStatus
            .exists?(project1_requirement2_status.id)
        }.from(true).to(false)
    end

    it 'does not delete records for other projects' do
      expect { service.execute }
        .to not_change { project2.reload.project_requirement_compliance_statuses.count }
    end

    it 'does not delete records for other frameworks' do
      expect { service.execute }
        .to not_change {
          ComplianceManagement::ComplianceFramework::ProjectRequirementComplianceStatus
            .exists?(project1_requirement3_status.id)
        }
    end

    it 'return success' do
      response = service.execute
      expect(response).to be_success
      expect(response.message).to eq('Successfully deleted requirement statuses.')
    end
  end
end
