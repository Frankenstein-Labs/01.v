# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::Groups::ComplianceViolations::ExportService,
  feature_category: :compliance_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:compliance_framework) { create(:compliance_framework, namespace: group) }
  let_it_be(:compliance_requirement) { create(:compliance_requirement, framework: compliance_framework) }
  let_it_be(:compliance_control) do
    create(:compliance_requirements_control, compliance_requirement: compliance_requirement)
  end

  let_it_be(:audit_event) do
    create(:audit_events_project_audit_event, project_id: project.id,
      details: { message: 'foo_bar_420.69' }
    )
  end

  let_it_be(:violation) do
    create(:project_compliance_violation,
      audit_event_table_name: :project_audit_events,
      project: project, namespace: group, compliance_control: compliance_control, audit_event_id: audit_event.id)
  end

  subject(:service) { described_class.new(user: user, group: group) }

  describe '#execute' do
    before do
      stub_licensed_features(group_level_compliance_violations_report: true)
    end

    context 'when user has permission' do
      it 'returns success with CSV data' do
        headers = [
          "Detected at",
          "Violation ID",
          "Status",
          "Framework",
          "Compliance Control",
          "Compliance Requirement",
          "Audit Event ID",
          "Audit Event Author",
          "Audit Event Type",
          "Audit Event Name",
          "Audit Event Message",
          "Project ID"
        ]
        group.add_owner(user)
        result = service.execute

        expect(result).to be_success
        expect(result.payload).to be_present
        expect(result.payload).to include(headers.join(','))
      end

      it 'includes violation data in CSV' do
        group.add_owner(user)
        result = service.execute

        expect(result.payload).to include(violation.id.to_s)
        expect(result.payload).to include(violation.status)
        expect(result.payload).to include(violation.project_id.to_s)
        expect(result.payload).to include(violation.created_at.strftime('%Y-%m-%d %H:%M:%S'))
        expect(result.payload).to include(audit_event.id.to_s)
        expect(result.payload).to include(audit_event.entity_type.to_s)
        expect(result.payload).to include(audit_event.event_name.to_s)
        expect(result.payload).to include('foo_bar_420.69')
      end
    end

    context 'when user does not have permission' do
      it 'returns error' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to include("Access to group denied for user with ID: #{user.id}")
      end
    end

    context 'when namespace is not a group' do
      let(:namespace) { create(:user_namespace) }

      subject(:service) { described_class.new(user: user, group: namespace) }

      it 'returns error' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq('namespace must be a group')
      end
    end
  end

  describe '#email_export' do
    it 'enqueues the mailer worker' do
      group.add_owner(user)
      expect(ComplianceManagement::Groups::ComplianceViolationsExportMailerWorker)
        .to receive(:perform_async).with(user.id, group.id)

      result = service.email_export

      expect(result).to be_success
    end
  end
end
