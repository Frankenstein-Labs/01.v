# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ComplianceViolationDetectionWorker, feature_category: :compliance_management do
  let(:worker) { described_class.new }

  describe '#perform' do
    context 'when audit event does not exist' do
      let(:args) do
        { audit_event_id: non_existing_record_id, audit_event_class_name: 'AuditEvents::ProjectAuditEvent' }
      end

      it 'returns early without processing' do
        expect(ComplianceManagement::Projects::ViolationDetectionService).not_to receive(:new)

        worker.perform(args)
      end
    end

    context 'when audit event exists but has no compliance controls' do
      let(:audit_event) { create(:audit_events_project_audit_event, event_name: 'test_event') }
      let(:args) { { audit_event_id: audit_event.id, audit_event_class_name: audit_event.class.name } }

      before do
        event_definition = instance_double(Gitlab::Audit::Type::Definition, compliance_controls: [])
        allow(Gitlab::Audit::Type::Definition)
          .to receive(:get).with(audit_event.event_name).and_return(event_definition)
      end

      it 'returns early without processing' do
        expect(ComplianceManagement::Projects::ViolationDetectionService).not_to receive(:new)

        worker.perform(args)
      end
    end

    context 'for project audit event with compliance controls' do
      let_it_be(:project) { create(:project) }
      let_it_be(:audit_event) do
        create(:audit_events_project_audit_event, project_id: project.id, event_name: 'test_event')
      end

      let_it_be(:control) { create(:compliance_requirements_control, :minimum_approvals_required_2) }
      let_it_be(:args) { { audit_event_id: audit_event.id, audit_event_class_name: audit_event.class.name } }

      before do
        event_definition = instance_double(Gitlab::Audit::Type::Definition,
          compliance_controls: ['minimum_approvals_required_2'])
        allow(Gitlab::Audit::Type::Definition)
          .to receive(:get).with(audit_event.event_name).and_return(event_definition)

        allow(ComplianceManagement::ComplianceFramework::ComplianceRequirementsControl)
          .to receive(:grouped_by_project).with([project]).and_return({ project.id => [control] })
      end

      it 'calls ViolationDetectionService for each matching control' do
        service_instance = instance_double(ComplianceManagement::Projects::ViolationDetectionService)
        expect(ComplianceManagement::Projects::ViolationDetectionService)
          .to receive(:new).with(project, control, audit_event).and_return(service_instance)
        expect(service_instance).to receive(:execute)

        worker.perform(args)
      end

      context 'when project has no compliance controls' do
        before do
          allow(ComplianceManagement::ComplianceFramework::ComplianceRequirementsControl)
            .to receive(:grouped_by_project).with([project]).and_return({})
        end

        it 'does not call ViolationDetectionService' do
          expect(ComplianceManagement::Projects::ViolationDetectionService).not_to receive(:new)

          worker.perform(args)
        end
      end

      context 'when control name does not match compliance controls to check' do
        let(:unmatched_control) { create(:compliance_requirements_control, :scanner_sast_running) }

        before do
          allow(ComplianceManagement::ComplianceFramework::ComplianceRequirementsControl)
            .to receive(:grouped_by_project).with([project]).and_return({ project.id => [unmatched_control] })
        end

        it 'does not call ViolationDetectionService' do
          expect(ComplianceManagement::Projects::ViolationDetectionService).not_to receive(:new)

          worker.perform(args)
        end
      end
    end

    context 'when group audit event with compliance controls' do
      let_it_be(:group) { create(:group) }
      let_it_be(:project1) { create(:project, group: group) }
      let_it_be(:project2) { create(:project, group: group) }
      let_it_be(:audit_event) { create(:audit_events_group_audit_event, group_id: group.id, event_name: 'test_event') }
      let_it_be(:control) { create(:compliance_requirements_control, :minimum_approvals_required_2) }
      let_it_be(:args) { { audit_event_id: audit_event.id, audit_event_class_name: audit_event.class.name } }

      before do
        event_definition = instance_double(Gitlab::Audit::Type::Definition,
          compliance_controls: ['minimum_approvals_required_2'])

        allow(Gitlab::Audit::Type::Definition).to receive(:get).and_call_original
        allow(Gitlab::Audit::Type::Definition)
          .to receive(:get).with(audit_event.event_name).and_return(event_definition)
        allow(ComplianceManagement::ComplianceFramework::ComplianceRequirementsControl)
          .to receive(:grouped_by_project).with([project1, project2]).and_return({ project1.id => [control] })
      end

      it 'processes all projects in the group' do
        service_instance = instance_double(ComplianceManagement::Projects::ViolationDetectionService)

        expect(ComplianceManagement::Projects::ViolationDetectionService)
          .to receive(:new).with(project1, control, audit_event).and_return(service_instance)
        expect(service_instance).to receive(:execute)

        worker.perform(args)
      end
    end

    context 'when audit event entity is NullEntity' do
      let(:audit_event) { create(:audit_events_project_audit_event, event_name: 'test_event') }
      let(:args) { { audit_event_id: audit_event.id, audit_event_class_name: audit_event.class.name } }

      before do
        event_definition = instance_double(Gitlab::Audit::Type::Definition,
          compliance_controls: ['minimum_approvals_required_2'])
        allow(Gitlab::Audit::Type::Definition)
          .to receive(:get).with(audit_event.event_name).and_return(event_definition)

        allow(audit_event).to receive(:project).and_return(Gitlab::Audit::NullEntity.new)
      end

      it 'returns early without processing' do
        expect(ComplianceManagement::Projects::ViolationDetectionService).not_to receive(:new)

        worker.perform(args)
      end
    end

    context 'when ViolationDetectionService raises an error' do
      let_it_be(:project) { create(:project) }
      let_it_be(:audit_event) do
        create(:audit_events_project_audit_event, project_id: project.id, event_name: 'test_event')
      end

      let_it_be(:control) { create(:compliance_requirements_control, :minimum_approvals_required_2) }
      let_it_be(:error) { StandardError.new('Test error') }
      let_it_be(:args) { { audit_event_id: audit_event.id, audit_event_class_name: audit_event.class.name } }

      before do
        event_definition = instance_double(Gitlab::Audit::Type::Definition,
          compliance_controls: ['minimum_approvals_required_2'])
        allow(Gitlab::Audit::Type::Definition)
          .to receive(:get).with(audit_event.event_name).and_return(event_definition)
        allow(ComplianceManagement::ComplianceFramework::ComplianceRequirementsControl)
          .to receive(:grouped_by_project).with([project]).and_return({ project.id => [control] })
        allow(ComplianceManagement::Projects::ViolationDetectionService)
          .to receive(:new).with(project, control, audit_event).and_raise(error)
      end

      it 'tracks the exception' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
          error,
          project_id: project.id,
          control_id: control.id,
          audit_event_id: audit_event.id
        )

        worker.perform(args)
      end
    end
  end
end
