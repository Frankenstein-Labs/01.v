# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::SeverityOverrideAuditService, feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:vulnerability) { create(:vulnerability, project: project) }
  let_it_be(:now) { Time.current }
  let(:new_severity) { 'high' }
  let(:service) do
    described_class.new(
      vulnerabilities_audit_attrs: vulnerabilities_audit_attrs,
      now: now,
      current_user: current_user,
      new_severity: new_severity
    )
  end

  subject(:execute) { service.execute }

  describe '#execute' do
    context 'when vulnerabilities_audit_attrs is empty' do
      let(:vulnerabilities_audit_attrs) { [] }

      it 'returns nil without creating any events' do
        expect(::Gitlab::Audit::EventQueue).not_to receive(:push)
        expect(::Gitlab::Audit::Auditor).not_to receive(:audit)
        expect { execute }.not_to change { AuditEventReader.count }
        expect(execute).to be_nil
      end
    end

    context 'when vulnerabilities_audit_attrs contains valid data', :request_store do
      let(:vulnerabilities_audit_attrs) do
        [
          {
            project: project,
            old_severity: vulnerability.severity,
            vulnerability: vulnerability
          }
        ]
      end

      before do
        allow(::Gitlab::Routing.url_helpers).to receive(:project_security_vulnerability_url)
          .with(project, vulnerability).and_return(expected_url(project, vulnerability))
      end

      it 'creates and pushes audit events through the Auditor' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with({
          author: current_user,
          scope: project,
          target: project,
          name: 'vulnerability_severity_override'
        }).and_call_original

        expect(::Gitlab::Audit::EventQueue).to receive(:push).with(
          satisfy { |event| severity_override_event?(event) }
        ).and_call_original
        expect(execute).to eq(1)

        verify_audit_event_details(AuditEventReader.last&.details, project, vulnerability)
      end

      context 'with multiple events for the same project' do
        before do
          allow(::Gitlab::Routing.url_helpers).to receive(:project_security_vulnerability_url)
            .with(project, another_vulnerability).and_return(expected_url(project, another_vulnerability))
        end

        let(:another_vulnerability) { create(:vulnerability, project: project, severity: :medium) }
        let(:vulnerabilities_audit_attrs) do
          [
            {
              project: project,
              old_severity: vulnerability.severity,
              vulnerability: vulnerability
            },
            {
              project: project,
              old_severity: another_vulnerability.severity,
              vulnerability: another_vulnerability
            }
          ]
        end

        it 'processes all events within a single audit context with the correct values' do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with({
            author: current_user,
            scope: project,
            target: project,
            name: 'vulnerability_severity_override'
          }).and_call_original

          expect(::Gitlab::Audit::EventQueue).to receive(:push).twice.with(
            satisfy { |event| severity_override_event?(event) }
          ).and_call_original

          expect { execute }.to change { AuditEventReader.count }.by(2)
          expect(execute).to eq(2)

          audit_events = AuditEventReader.last(2)
          verify_audit_event_details(audit_events.first.details, project, vulnerability)
          verify_audit_event_details(audit_events.second.details, project, another_vulnerability)
        end
      end

      context 'with events for different projects' do
        let(:another_project) { build(:project) }
        let(:another_vulnerability) { create(:vulnerability, project: another_project, severity: :medium) }
        let(:vulnerabilities_audit_attrs) do
          [
            {
              project: project,
              old_severity: vulnerability.severity,
              vulnerability: vulnerability
            },
            {
              project: another_project,
              old_severity: another_vulnerability.severity,
              vulnerability: another_vulnerability
            }
          ]
        end

        before do
          allow(::Gitlab::Routing.url_helpers).to receive(:project_security_vulnerability_url)
            .with(another_project, another_vulnerability)
            .and_return(expected_url(another_project, another_vulnerability))
        end

        it 'creates separate Auditors for each project with the correct values' do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with({
            author: current_user,
            scope: project,
            target: project,
            name: 'vulnerability_severity_override'
          }).and_call_original

          expect(::Gitlab::Audit::Auditor).to receive(:audit).with({
            author: current_user,
            scope: another_project,
            target: another_project,
            name: 'vulnerability_severity_override'
          }).and_call_original

          expect(::Gitlab::Audit::EventQueue).to receive(:push).twice.with(
            satisfy { |event| severity_override_event?(event) }
          ).and_call_original

          expect { execute }.to change { AuditEventReader.count }.by(2)
          expect(execute).to eq(2)

          audit_events = AuditEventReader.last(2)
          verify_audit_event_details(audit_events.first.details, project, vulnerability)
          verify_audit_event_details(audit_events.second.details, another_project, another_vulnerability)
        end
      end
    end
  end

  describe '#audit_context' do
    let(:vulnerabilities_audit_attrs) { [] }

    it 'returns the correct audit context hash' do
      context = service.send(:audit_context, project)

      expect(context).to eq({
        author: current_user,
        scope: project,
        target: project,
        name: 'vulnerability_severity_override'
      })
    end
  end

  def expected_url(project, vulnerability)
    "http://localhost/#{project.full_path}/-/security/vulnerabilities/#{vulnerability.id}"
  end

  def expected_message(vulnerability)
    "Vulnerability severity was changed from #{vulnerability.severity.capitalize} to #{new_severity.capitalize}"
  end

  def severity_override_event?(event)
    event.is_a?(AuditEvent) && event.details[:name] == 'vulnerability_severity_override'
  end

  def verify_audit_event_details(audit_event, expected_project, expected_vulnerability)
    aggregate_failures "audit event details" do
      expect(audit_event[:name]).to eq('vulnerability_severity_override')
      expect(audit_event[:author_name]).to eq(current_user.name)
      expect(audit_event[:target_id]).to eq(expected_project.id)
      expect(audit_event[:target_details]).to eq(expected_url(expected_project, expected_vulnerability))
      expect(audit_event[:custom_message]).to eq(expected_message(expected_vulnerability))
    end
  end
end
