# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::Projects::ViolationDetectionService, feature_category: :compliance_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let(:control) { create(:compliance_requirements_control, :minimum_approvals_required_2, namespace_id: group.id) }
  let(:audit_event) { create(:audit_events_project_audit_event, project_id: project.id) }
  let(:service) { described_class.new(project, control, audit_event) }

  describe '#execute' do
    context 'when a violation is detected' do
      let(:audit_event) do
        create(:audit_events_project_audit_event, project_id: project.id, target_type: 'MergeRequest')
      end

      before do
        detector_class = ComplianceManagement::Projects::ViolationDetectors::MinimumApprovalsRequired2Detector
        allow_next_instance_of(detector_class) do |instance|
          allow(instance).to receive(:violation?).and_return(true)
        end
      end

      it 'creates and returns a compliance violation record' do
        result = service.execute

        expect(result).to be_a(ComplianceManagement::Projects::ComplianceViolation)
        expect(result.project).to eq(project)
        expect(result.audit_event_id).to eq(audit_event.id)
        expect(result.compliance_requirements_control_id).to eq(control.id)
        expect(result.status).to eq('detected')
      end
    end

    context 'when violation? returns false' do
      let(:audit_event) do
        create(:audit_events_project_audit_event, project_id: project.id, target_type: 'MergeRequest')
      end

      before do
        detector_class = ComplianceManagement::Projects::ViolationDetectors::MinimumApprovalsRequired2Detector
        allow_next_instance_of(detector_class) do |instance|
          allow(instance).to receive(:violation?).and_return(false)
        end
      end

      it 'returns nil' do
        result = service.execute

        expect(result).to be_nil
      end
    end
  end

  describe '#find_detector' do
    context 'when detector class exists' do
      let(:control) { create(:compliance_requirements_control, :minimum_approvals_required_2) }

      it 'returns an instance of the correct detector class' do
        result = service.send(:find_detector)

        expect(result).to be_a(ComplianceManagement::Projects::ViolationDetectors::MinimumApprovalsRequired2Detector)
        expect(result.project).to eq(project)
        expect(result.control).to eq(control)
        expect(result.audit_event).to eq(audit_event)
      end
    end

    context 'when detector class does not exist' do
      let(:control) { create(:compliance_requirements_control, :default_branch_protected) }

      it 'raises an error with descriptive message' do
        expected_message = "Violation detector not found: " \
          "ComplianceManagement::Projects::ViolationDetectors::DefaultBranchProtectedDetector. " \
          "Please create the detector class or remove 'default_branch_protected' from the audit event configuration."

        expect { service.send(:find_detector) }.to raise_error(RuntimeError, expected_message)
      end
    end

    context 'with different control names' do
      using RSpec::Parameterized::TableSyntax

      detector_initial_name = 'ComplianceManagement::Projects::ViolationDetectors::'

      where(:control_name, :expected_class_name) do
        'default_branch_protected' | "#{detector_initial_name}DefaultBranchProtectedDetector"
        'project_visibility_not_internal' | "#{detector_initial_name}ProjectVisibilityNotInternalDetector"
        'scanner_sast_running' | "#{detector_initial_name}ScannerSastRunningDetector"
      end

      with_them do
        let(:control) { create(:compliance_requirements_control, control_name.to_sym) }

        it 'generates the correct detector class name' do
          expect { service.send(:find_detector) }.to raise_error do |error|
            expect(error.message).to include(expected_class_name)
          end
        end
      end
    end
  end
end
