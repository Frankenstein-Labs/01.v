# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ComplianceFramework::ProjectSetting::AddFrameworkService, feature_category: :compliance_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:project) { create(:project, namespace: subgroup) }
  let_it_be(:framework) { create(:compliance_framework, namespace: group) }
  let_it_be(:current_user) { create(:user) }

  let(:service) { described_class.new(project_id: project.id, current_user: current_user, framework: framework) }

  describe '#execute' do
    context 'when user has permission' do
      before do
        allow(service).to receive(:can?).with(current_user, :admin_compliance_framework, framework).and_return(true)
      end

      context 'when the project setting does not exist' do
        context 'when project and framework belongs to same top-level namespace' do
          it 'creates a new project setting record' do
            expect { service.execute }.to change { ComplianceManagement::ComplianceFramework::ProjectSettings.count }
              .by(1)
          end

          it 'creates the project setting with the correct attributes' do
            service.execute

            setting = ComplianceManagement::ComplianceFramework::ProjectSettings.last
            expect(setting.project_id).to eq(project.id)
            expect(setting.framework_id).to eq(framework.id)
          end

          it 'returns a successful service response' do
            expect(service.execute.success?).to be true
          end

          it 'publishes a compliance framework changed event' do
            expect(::Gitlab::EventStore).to receive(:publish).with(
              an_instance_of(::Projects::ComplianceFrameworkChangedEvent)
            ).and_call_original

            service.execute
          end

          it 'creates an audit event' do
            expect { service.execute }.to change { AuditEventReader.count }.by(1)
          end

          it 'enqueues the ProjectComplianceEvaluatorWorker' do
            expect(ComplianceManagement::ProjectComplianceEvaluatorWorker).to receive(:perform_in).with(
              ComplianceManagement::ComplianceFramework::ProjectSettings::PROJECT_EVALUATOR_WORKER_DELAY,
              framework.id, [project.id]
            ).once.and_call_original

            service.execute
          end
        end

        context 'when project and framework belongs to the CSP namespace' do
          include Security::PolicyCspHelpers

          let_it_be(:csp_group) { create(:group) }
          let_it_be(:framework) { create(:compliance_framework, namespace: csp_group) }

          before do
            stub_csp_group(csp_group)
          end

          it 'creates the project setting with the correct attributes' do
            service.execute

            setting = ComplianceManagement::ComplianceFramework::ProjectSettings.last
            expect(setting.project_id).to eq(project.id)
            expect(setting.framework_id).to eq(framework.id)
          end

          it 'returns a successful service response' do
            expect(service.execute.success?).to be true
          end

          it 'publishes a compliance framework changed event' do
            expect(::Gitlab::EventStore).to receive(:publish).with(
              an_instance_of(::Projects::ComplianceFrameworkChangedEvent)
            ).and_call_original

            service.execute
          end

          it 'creates an audit event' do
            expect { service.execute }.to change {
              AuditEventReader.where("details LIKE ?", "%compliance_framework_added%").count
            }.by(1)
          end

          it 'enqueues the ProjectComplianceEvaluatorWorker' do
            expect(ComplianceManagement::ProjectComplianceEvaluatorWorker).to receive(:perform_in).with(
              ComplianceManagement::ComplianceFramework::ProjectSettings::PROJECT_EVALUATOR_WORKER_DELAY,
              framework.id, [project.id]
            ).once.and_call_original

            service.execute
          end
        end

        context 'when project and framework belongs to different top-level namespaces' do
          let_it_be(:project) { create(:project) }

          it 'returns an error service response' do
            response = service.execute

            expect(response.success?).to be false
            expect(response.message)
              .to include(format(_("Project %{project_name} and framework are not from same namespace."),
                project_name: project.name))
          end

          it 'does not publish an event' do
            expect(::Gitlab::EventStore).not_to receive(:publish)

            service.execute
          end

          it 'does not create an audit event' do
            expect { service.execute }.not_to change { AuditEventReader.count }
          end

          it 'does not enqueue the ProjectComplianceEvaluatorWorker' do
            expect(ComplianceManagement::ProjectComplianceEvaluatorWorker).not_to receive(:perform_in)

            service.execute
          end

          it 'does not create a new project setting record' do
            expect { service.execute }
              .not_to change { ::ComplianceManagement::ComplianceFramework::ProjectSettings.count }
          end
        end
      end

      context 'when the project setting already exists' do
        before do
          create(:compliance_framework_project_setting,
            project_id: project.id,
            compliance_management_framework: framework)
        end

        it 'does not create a new project setting record' do
          expect { service.execute }.not_to change { ComplianceManagement::ComplianceFramework::ProjectSettings.count }
        end

        it 'returns a successful service response' do
          expect(service.execute.success?).to be true
        end

        it 'does not publish a compliance framework changed event' do
          expect(::Gitlab::EventStore).not_to receive(:publish)

          service.execute
        end

        it 'does not create an audit event' do
          expect { service.execute }.not_to change { AuditEventReader.count }
        end

        it 'does not enqueue the ProjectComplianceEvaluatorWorker' do
          expect(ComplianceManagement::ProjectComplianceEvaluatorWorker).not_to receive(:perform_in)

          service.execute
        end
      end

      context 'when the project setting cannot be created' do
        before do
          allow(framework.projects).to receive(:push).with(project).and_return(false)
        end

        it 'returns an error service response' do
          response = service.execute

          expect(response.success?).to be false
          expect(response.message).to include("Failed to assign the framework to project")
        end

        it 'does not publish an event' do
          expect(::Gitlab::EventStore).not_to receive(:publish)

          service.execute
        end

        it 'does not create an audit event' do
          expect { service.execute }.not_to change { AuditEventReader.count }
        end

        it 'does not enqueue the ProjectComplianceEvaluatorWorker' do
          expect(ComplianceManagement::ProjectComplianceEvaluatorWorker).not_to receive(:perform_in)

          service.execute
        end
      end

      context 'when the project does not exist' do
        let(:project_id) { non_existing_record_id }
        let(:service) { described_class.new(project_id: project_id, current_user: current_user, framework: framework) }

        it 'returns an error service response' do
          response = service.execute

          expect(response.success?).to be false
          expect(response.message).to include("Project not found")
        end
      end
    end

    context 'when user does not have permission' do
      before do
        allow(service).to receive(:can?).with(current_user, :admin_compliance_framework, framework).and_return(false)
      end

      it 'returns an error service response' do
        response = service.execute

        expect(response.success?).to be false
        expect(response.message).to eq('Not permitted to create framework')
      end

      it 'does not create a new project setting record' do
        expect { service.execute }.not_to change { ComplianceManagement::ComplianceFramework::ProjectSettings.count }
      end

      it 'does not publish an event' do
        expect(::Gitlab::EventStore).not_to receive(:publish)

        service.execute
      end

      it 'does not create an audit event' do
        expect { service.execute }.not_to change { AuditEventReader.count }
      end

      it 'does not enqueue the ProjectComplianceEvaluatorWorker' do
        expect(ComplianceManagement::ProjectComplianceEvaluatorWorker).not_to receive(:perform_in)

        service.execute
      end
    end
  end
end
