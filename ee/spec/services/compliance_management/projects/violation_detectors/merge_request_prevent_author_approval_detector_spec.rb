# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::Projects::ViolationDetectors::MergeRequestPreventAuthorApprovalDetector,
  feature_category: :compliance_management do
  let_it_be(:namespace) { create(:group) }
  let_it_be(:project) { create(:project, namespace: namespace) }
  let_it_be(:control) { create(:compliance_requirements_control, namespace_id: namespace.id) }
  let(:detector) { described_class.new(project, control, audit_event) }

  describe '#detect_violations' do
    context 'when author is not approving' do
      let(:audit_event) do
        create(:audit_events_project_audit_event,
          project_id: project.id,
          target_type: 'MergeRequest',
          details: { approving_author: false }
        )
      end

      it 'does not create a violation' do
        expect { detector.detect_violations }.not_to change {
          ComplianceManagement::Projects::ComplianceViolation.count
        }
      end
    end

    context 'when author is approving' do
      let(:audit_event) do
        create(:audit_events_project_audit_event,
          target_type: 'MergeRequest',
          project_id: project.id,
          details: { approving_author: true }
        )
      end

      it 'creates a compliance violation with correct attributes' do
        expect { detector.detect_violations }.to change {
          ComplianceManagement::Projects::ComplianceViolation.count
        }.by(1)

        violation = ComplianceManagement::Projects::ComplianceViolation.last
        expect(violation.project).to eq(project)
        expect(violation.namespace_id).to eq(project.namespace_id)
        expect(violation.audit_event_id).to eq(audit_event.id)
        expect(violation.audit_event_table_name).to eq('project_audit_events')
        expect(violation.compliance_requirements_control_id).to eq(control.id)
        expect(violation.status).to eq('detected')
      end
    end
  end
end
