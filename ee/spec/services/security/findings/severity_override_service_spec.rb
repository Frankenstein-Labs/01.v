# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Findings::SeverityOverrideService, feature_category: :vulnerability_management do
  before do
    stub_licensed_features(security_dashboard: true)
    stub_feature_flags(hide_vulnerability_severity_override: false)
  end

  def override_severity(severity: new_severity)
    described_class.new(user: current_user, security_finding: security_finding, severity: severity).execute
  end

  subject(:execute) { override_severity }

  describe '#execute' do
    include_context 'with dependency scanning security report findings'

    let_it_be(:scan) do
      create(
        :security_scan,
        :latest_successful,
        scan_type: :dependency_scanning,
        pipeline: pipeline,
        build: artifact.job
      )
    end

    let_it_be(:security_finding) do
      create(
        :security_finding,
        severity: report_finding.severity,
        uuid: report_finding.uuid,
        scan: scan
      )
    end

    let_it_be(:current_user) { create(:user) }
    let_it_be(:new_severity) { 'high' }

    shared_examples 'creates project audit event' do
      it 'creates project audit event' do
        original_severity = security_finding.severity
        expected_details = "Vulnerability finding uuid: #{security_finding.uuid}"
        expected_message = "Vulnerability finding severity was changed from #{original_severity.capitalize} " \
          "to #{new_severity.capitalize}"

        expect { execute }.to change { AuditEventReader.count }.by(1)

        last_audit_event = AuditEventReader.last&.details
        expect(last_audit_event[:event_name]).to eq('vulnerability_severity_override')
        expect(last_audit_event[:author_name]).to eq(current_user.name)
        expect(last_audit_event[:target_id]).to eq(project.id)
        expect(last_audit_event[:target_details]).to eq(expected_details)
        expect(last_audit_event[:custom_message]).to eq(expected_message)
      end
    end

    context 'when the user is authorized' do
      before do
        security_finding.project.add_maintainer(current_user)
      end

      context 'when new severity matches the existing vulnerability severity' do
        let(:new_severity) { security_finding.severity }

        it 'adds only vulnerability related records' do
          expect { execute }.to change { Vulnerability.count }.by(1)
          .and change { Vulnerabilities::Finding.count }.by(1)
          .and not_change { Vulnerabilities::SeverityOverride.count }
          .and not_change { Vulnerabilities::Read.count }
        end

        it 'doesnt create audit event' do
          expect { execute }.not_to change { AuditEventReader.count }
        end
      end

      context 'when severity is overridden' do
        context 'when no vulnerability matching the security finding exists' do
          it 'creates vulnerability records, overrides the severity and creates a severity_override record' do
            original_severity = security_finding.severity

            expect { execute }.to change { Vulnerability.count }.by(1)
              .and change { Vulnerabilities::Finding.count }.by(1)
              .and change { Vulnerabilities::SeverityOverride.count }.by(1)
              .and not_change { Vulnerabilities::Read.count }

            expect(security_finding.reload.vulnerability.severity).to eq(new_severity)
            expect(security_finding.vulnerability.finding.severity).to eq(new_severity)

            expect(Vulnerabilities::SeverityOverride.last).to have_attributes(
              new_severity: new_severity,
              original_severity: original_severity,
              project: security_finding.project,
              author: current_user,
              vulnerability: security_finding.vulnerability
            )
          end

          it_behaves_like 'creates project audit event'
        end

        context 'when a vulnerability matching the security finding already exists' do
          let(:previous_severity) { 'low' }

          before do
            override_severity(severity: previous_severity)
          end

          context 'when new severity matches the existing severity' do
            let(:new_severity) { security_finding.severity }

            it 'doesnt update the updated_at or add a new severity override record' do
              expect { execute }.to not_change { Vulnerability.count }
              .and not_change { Vulnerabilities::Finding.count }
              .and not_change { Vulnerabilities::SeverityOverride.count }
              .and not_change { Vulnerability.last.updated_at }
            end
          end

          it 'overrides the severity and creates a severity_override record' do
            initial_updated_at = security_finding.reload.vulnerability.updated_at

            expect(Vulnerabilities::Statistics::UpdateService).to receive(:update_for)

            travel(10.seconds) do
              expect { execute }
                .to not_change { Vulnerability.count }
                .and not_change { Vulnerabilities::Finding.count }
                .and change { Vulnerabilities::SeverityOverride.count }.by(1)

              expect(security_finding.reload.vulnerability.severity).to eq(new_severity)
              expect(security_finding.vulnerability.updated_at).not_to eq(initial_updated_at)
              expect(security_finding.vulnerability.finding.severity).to eq(new_severity)

              expect(Vulnerabilities::SeverityOverride.last).to have_attributes(
                new_severity: new_severity,
                original_severity: previous_severity,
                project: security_finding.project,
                author: current_user,
                vulnerability: security_finding.vulnerability
              )
            end
          end

          it 'updates the vulnerability read record with the new severity' do
            vulnerability = security_finding.reload.vulnerability
            vulnerability_read = Vulnerabilities::Read.find_by(vulnerability_id: vulnerability.id) ||
              create(:vulnerability_read, vulnerability: vulnerability, severity: previous_severity)

            expect { execute }.to change { vulnerability_read.reload.severity }.from(previous_severity).to(new_severity)
          end

          it_behaves_like 'creates project audit event'
        end
      end

      context 'when severity override fails' do
        let(:create_service_double) do
          instance_double(Vulnerabilities::FindOrCreateFromSecurityFindingService, execute: service_failure_payload)
        end

        let(:service_failure_payload) { { status: :error, message: errors_double } }
        let(:error_message) { "Something went wrong" }
        let(:errors_double) { instance_double(ActiveModel::Errors, full_messages: error_messages_array) }
        let(:error_messages_array) { instance_double(Array, join: error_message) }
        let(:new_severity) { 'low' }

        before do
          allow(Vulnerabilities::FindOrCreateFromSecurityFindingService)
            .to receive(:new).and_return(create_service_double)
        end

        it 'returns an error response' do
          expect(create_service_double).to receive(:execute).once

          expect(execute).not_to be_success
          expect(execute.reason).to be(:unprocessable_entity)
          expect(execute.message).to eq("failed to change severity of security finding: #{error_message}")
        end
      end

      context 'when update severity fails' do
        let(:error_message) { "Something went wrong" }
        let(:new_severity) { 'medium' }

        before do
          allow_next_instance_of(described_class) do |service|
            allow(service).to receive(:update_severity).and_raise(ArgumentError, error_message)
          end
        end

        it 'returns an error response' do
          expect(execute).not_to be_success
          expect(execute.reason).to be(:unprocessable_entity)
          expect(execute.message).to eq("failed to change severity of security finding: #{error_message}")
        end
      end
    end

    context 'when the user is not authorized' do
      it 'raises an "access denied" error' do
        expect(execute).not_to be_success
        expect(execute.reason).to be(:forbidden)
        expect(execute.message).to eq("Access denied")
      end

      context 'when the security dashboard feature is disabled' do
        before do
          security_finding.project.add_maintainer(current_user)
          stub_licensed_features(security_dashboard: false)
        end

        it 'raises an "access denied" error' do
          expect(execute).not_to be_success
          expect(execute.reason).to be(:forbidden)
          expect(execute.message).to eq("Access denied")
        end
      end

      context 'when vulnerability_severity_override feature flag is disabled' do
        before do
          security_finding.project.add_maintainer(current_user)
          stub_feature_flags(hide_vulnerability_severity_override: true)
        end

        it 'raises an "access denied" error' do
          expect(execute).not_to be_success
          expect(execute.reason).to be(:forbidden)
          expect(execute.message).to eq("Access denied")
        end
      end
    end

    context 'when the severity value is invalid' do
      before do
        security_finding.project.add_maintainer(current_user)
      end

      let(:new_severity) { 'invalid_severity' }

      it 'returns an error response' do
        expect(execute).not_to be_success
        expect(execute.reason).to be(:unprocessable_entity)
        expect(execute.message).to eq("failed to change severity of security finding: " \
          "'#{new_severity}' is not a valid new_severity")
      end
    end
  end
end
