# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ComplianceFrameworkChangesAuditor,
  feature_category: :compliance_management do
    describe 'auditing compliance framework changes' do
      let_it_be(:user) { create(:user) }
      let_it_be(:group) { create(:group) }
      let_it_be(:destination) { create(:audit_events_group_external_streaming_destination, group: group) }

      let_it_be(:project) { create(:project, group: group) }

      subject(:auditor) do
        described_class.new(user, project.compliance_framework_settings.first, project)
      end

      before do
        project.reload
        stub_licensed_features(extended_audit_events: true, external_audit_events: true)
      end

      context 'when a project has no compliance framework' do
        context 'when the framework is added' do
          let_it_be(:framework) { create(:compliance_framework) }

          before do
            project.update!(compliance_management_frameworks: [framework])
          end

          it 'adds an audit event' do
            expect { auditor.execute }.to change { AuditEventReader.count }.by(1)
            expect(AuditEventReader.last.details[:custom_message]).to eq("Assigned project compliance framework GDPR")
          end

          it 'streams correct audit event stream' do
            expect(::AuditEvents::AuditEventStreamingWorker).to receive(:perform_async).with(
              'compliance_framework_id_updated', anything, anything)

            auditor.execute
          end
        end
      end

      context 'when a project has a compliance framework' do
        let(:framework_project_setting) { create(:compliance_framework_project_setting, project: project) }

        context 'when the framework is removed' do
          subject(:auditor) { described_class.new(user, framework_project_setting, project) }

          before do
            framework_project_setting.delete
          end

          it 'adds an audit event' do
            expect { auditor.execute }.to change { AuditEventReader.count }.by(1)
            expect(AuditEventReader.last.details).to include({
              custom_message: "Unassigned project compliance framework"
            })
          end

          it 'streams correct audit event stream' do
            expect(::AuditEvents::AuditEventStreamingWorker).to receive(:perform_async).with(
              'compliance_framework_deleted', anything, anything)

            auditor.execute
          end
        end

        context 'when the framework is changed' do
          before do
            project.update!(compliance_management_frameworks:
              [create(:compliance_framework, namespace: project.group, name: 'SOX')])
          end

          it 'adds an audit event' do
            expect { auditor.execute }.to change { AuditEventReader.count }.by(1)
            expect(AuditEventReader.last.details[:custom_message]).to eq("Assigned project compliance framework SOX")
          end
        end
      end

      context 'when the framework is not changed' do
        before do
          project.update!(description: 'This is a description of a project')
        end

        it 'does not add an audit event' do
          expect { auditor.execute }.not_to change { AuditEventReader.count }
        end
      end
    end
  end
