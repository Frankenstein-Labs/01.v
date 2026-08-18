# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::ComplianceViolationScheduler, feature_category: :compliance_management do
  let(:scheduler) { described_class.new(audit_events) }

  describe '#execute' do
    context 'with multiple audit events' do
      let(:audit_event_1) { create(:audit_events_project_audit_event) }
      let(:audit_event_2) { create(:audit_events_project_audit_event) }
      let(:audit_events) { [audit_event_1, audit_event_2] }

      it 'schedules compliance check for each audit event' do
        expect(scheduler).to receive(:schedule_compliance_check).with(audit_event_1)
        expect(scheduler).to receive(:schedule_compliance_check).with(audit_event_2)

        scheduler.execute
      end
    end

    context 'with empty audit events' do
      let(:audit_events) { [] }

      it 'does not schedule any compliance checks' do
        expect(scheduler).not_to receive(:schedule_compliance_check)

        scheduler.execute
      end
    end
  end

  describe '#schedule_compliance_check' do
    let(:audit_events) { [audit_event] }

    context 'when should_schedule_compliance_check? returns false' do
      let(:audit_event) { create(:audit_event) }

      before do
        allow(scheduler).to receive(:should_schedule_compliance_check?).with(audit_event).and_return(false)
      end

      it 'does not schedule worker' do
        expect(::ComplianceManagement::ComplianceViolationDetectionWorker).not_to receive(:perform_async)

        scheduler.send(:schedule_compliance_check, audit_event)
      end
    end

    context 'when should_schedule_compliance_check? returns true' do
      let(:audit_event) { create(:audit_events_project_audit_event, event_name: 'test_event') }

      before do
        allow(scheduler).to receive(:should_schedule_compliance_check?).with(audit_event).and_return(true)
      end

      context 'when event definition exists but has no compliance controls' do
        let(:event_definition) { instance_double(Gitlab::Audit::Type::Definition, compliance_controls: []) }

        before do
          allow(Gitlab::Audit::Type::Definition).to receive(:get).with('test_event').and_return(event_definition)
        end

        it 'does not schedule worker' do
          expect(::ComplianceManagement::ComplianceViolationDetectionWorker).not_to receive(:perform_async)

          scheduler.send(:schedule_compliance_check, audit_event)
        end
      end

      context 'when event definition exists and has compliance controls' do
        let(:event_definition) { instance_double(Gitlab::Audit::Type::Definition, compliance_controls: ['control1']) }

        before do
          allow(Gitlab::Audit::Type::Definition).to receive(:get).with('test_event').and_return(event_definition)
        end

        it 'schedules worker with correct parameters' do
          expected_params = {
            'audit_event_id' => audit_event.id,
            'audit_event_class_name' => audit_event.class.name
          }

          expect(::ComplianceManagement::ComplianceViolationDetectionWorker)
            .to receive(:perform_async).with(expected_params)

          scheduler.send(:schedule_compliance_check, audit_event)
        end
      end
    end
  end

  describe '#should_schedule_compliance_check?' do
    let(:audit_events) { [audit_event] }

    context 'when audit event has no entity' do
      let(:audit_event) { create(:audit_events_project_audit_event, project_id: non_existing_record_id) }

      before do
        allow(audit_event).to receive(:entity).and_return(nil)
      end

      it 'returns false' do
        expect(scheduler.send(:should_schedule_compliance_check?, audit_event)).to be_falsey
      end
    end

    context 'when audit event entity is NullEntity' do
      let(:audit_event) { create(:audit_events_project_audit_event, project_id: non_existing_record_id) }

      before do
        allow(audit_event).to receive(:entity).and_return(Gitlab::Audit::NullEntity.new)
      end

      it 'returns false' do
        expect(scheduler.send(:should_schedule_compliance_check?, audit_event)).to be_falsey
      end
    end

    context 'when audit event has no event_name' do
      let_it_be(:project) { create(:project) }
      let(:audit_event) { create(:audit_events_project_audit_event, project_id: project.id, event_name: nil) }

      before do
        allow(audit_event).to receive(:project).and_return(project)
        allow(project).to receive(:licensed_feature_available?)
                            .with(:project_level_compliance_violations_report).and_return(true)
      end

      it 'returns false and logs the missing event_name' do
        expect(Gitlab::AppLogger).to receive(:info).with(
          message: "Audit event without event_name encountered in compliance scheduler",
          audit_event_id: audit_event.id,
          audit_event_class: audit_event.class.name
        )

        expect(scheduler.send(:should_schedule_compliance_check?, audit_event)).to be false
      end
    end

    context 'when audit event has blank event_name' do
      let_it_be(:project) { create(:project) }
      let(:audit_event) { create(:audit_events_project_audit_event, project_id: project.id, event_name: '') }

      before do
        allow(audit_event).to receive(:project).and_return(project)
        allow(project).to receive(:licensed_feature_available?)
                            .with(:project_level_compliance_violations_report).and_return(true)
      end

      it 'returns false and logs the missing event_name' do
        expect(Gitlab::AppLogger).to receive(:info).with(
          message: "Audit event without event_name encountered in compliance scheduler",
          audit_event_id: audit_event.id,
          audit_event_class: audit_event.class.name
        )

        expect(scheduler.send(:should_schedule_compliance_check?, audit_event)).to be false
      end
    end

    context 'when audit event has whitespace-only event_name' do
      let_it_be(:project) { create(:project) }
      let(:audit_event) { create(:audit_events_project_audit_event, project_id: project.id, event_name: '   ') }

      before do
        allow(audit_event).to receive(:project).and_return(project)
        allow(project).to receive(:licensed_feature_available?)
                            .with(:project_level_compliance_violations_report).and_return(true)
      end

      it 'returns false and logs the missing event_name' do
        expect(Gitlab::AppLogger).to receive(:info).with(
          message: "Audit event without event_name encountered in compliance scheduler",
          audit_event_id: audit_event.id,
          audit_event_class: audit_event.class.name
        )

        expect(scheduler.send(:should_schedule_compliance_check?, audit_event)).to be false
      end
    end

    context 'when audit event entity is a Project' do
      let_it_be(:project) { create(:project) }
      let(:audit_event) do
        create(:audit_events_project_audit_event, project_id: project.id, event_name: 'test_event')
      end

      context 'when project has licensed feature available' do
        before do
          allow(audit_event).to receive(:project).and_return(project)
          allow(project).to receive(:licensed_feature_available?)
                              .with(:project_level_compliance_violations_report).and_return(true)
        end

        it 'returns true' do
          expect(scheduler.send(:should_schedule_compliance_check?, audit_event)).to be true
        end
      end

      context 'when project does not have licensed feature available' do
        before do
          allow(audit_event).to receive(:project).and_return(project)
          allow(project).to receive(:licensed_feature_available?)
                              .with(:project_level_compliance_violations_report).and_return(false)
        end

        it 'returns false' do
          expect(scheduler.send(:should_schedule_compliance_check?, audit_event)).to be false
        end
      end
    end

    context 'when audit event entity is a Group' do
      let(:group) { create(:group) }
      let(:audit_event) { create(:audit_events_group_audit_event, group_id: group.id, event_name: 'test_event') }

      context 'when group has licensed feature available' do
        before do
          allow(audit_event).to receive(:group).and_return(group)
          allow(group).to receive(:licensed_feature_available?)
                            .with(:group_level_compliance_violations_report).and_return(true)
        end

        it 'returns true' do
          expect(scheduler.send(:should_schedule_compliance_check?, audit_event)).to be true
        end
      end

      context 'when group does not have licensed feature available' do
        before do
          allow(audit_event).to receive(:group).and_return(group)
          allow(group).to receive(:licensed_feature_available?)
                            .with(:group_level_compliance_violations_report).and_return(false)
        end

        it 'returns false' do
          expect(scheduler.send(:should_schedule_compliance_check?, audit_event)).to be false
        end
      end
    end

    context 'when audit event entity is neither Project nor Group' do
      let(:audit_event) { create(:audit_events_user_audit_event, event_name: 'test_event') }

      it 'returns nil' do
        expect(scheduler.send(:should_schedule_compliance_check?, audit_event)).to be_nil
      end
    end
  end
end
