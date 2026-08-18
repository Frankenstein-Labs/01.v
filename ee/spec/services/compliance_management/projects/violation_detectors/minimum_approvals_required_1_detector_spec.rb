# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::Projects::ViolationDetectors::MinimumApprovalsRequired1Detector, # rubocop:disable RSpec/SpecFilePathFormat -- we keep the digit 1 seperated by underscore to match the source code filename
  feature_category: :compliance_management do
  let_it_be(:namespace) { create(:group) }
  let_it_be(:project) { create(:project, namespace: namespace) }
  let_it_be(:control) { create(:compliance_requirements_control, namespace_id: namespace.id) }
  let(:detector) { described_class.new(project, control, audit_event) }

  describe '#detect_violations' do
    context 'when there are 1 or more approvers' do
      let(:audit_event) do
        create(:audit_events_project_audit_event,
          project_id: project.id,
          target_type: 'MergeRequest',
          details: { approvers: %w[user1] }
        )
      end

      it 'does not create a violation' do
        expect { detector.detect_violations }.not_to change {
          ComplianceManagement::Projects::ComplianceViolation.count
        }
      end
    end

    context 'when there are no approvers' do
      let(:audit_event) do
        create(:audit_events_project_audit_event,
          target_type: 'MergeRequest',
          project_id: project.id,
          details: { approvers: [] }
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
