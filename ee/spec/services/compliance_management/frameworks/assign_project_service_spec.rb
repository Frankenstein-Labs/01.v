# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::Frameworks::AssignProjectService, feature_category: :compliance_management do
  describe '#execute' do
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:framework) { create(:compliance_framework, namespace: group) }

    let(:params) { { framework: framework.id } }
    let(:error_message) { 'Failed to assign the framework to the project' }
    let(:multiple_frameworks_error_message) do
      'You cannot assign or unassign frameworks to a project that has ' \
        'more than one associated framework.'
    end

    let(:service) { described_class.new(project, user, params) }

    subject(:update_framework) { service.execute }

    shared_examples 'no framework update' do
      it 'does not update the framework' do
        expect { update_framework }.not_to change { project.reload.compliance_management_frameworks.to_a }
      end

      it 'does not publish Projects::ComplianceFrameworkChangedEvent' do
        expect { update_framework }.not_to publish_event(::Projects::ComplianceFrameworkChangedEvent)
      end

      it 'does not log audit event' do
        expect { update_framework }
          .not_to change { AuditEventReader.where("details LIKE ?", "%compliance_framework_id_updated%").count }
      end

      it 'does not enqueue the ProjectComplianceEvaluatorWorker' do
        expect(ComplianceManagement::ProjectComplianceEvaluatorWorker).not_to receive(:perform_in)

        update_framework
      end
    end

    shared_examples 'framework update' do
      it 'updates the framework' do
        expect { update_framework }.to change {
          project.reload.compliance_management_frameworks
        }.from(old_framework).to([new_framework])
      end

      it 'publishes Projects::ComplianceFrameworkChangedEvent' do
        expect { update_framework }
          .to publish_event(::Projects::ComplianceFrameworkChangedEvent)
                .with(project_id: project.id, compliance_framework_id: new_framework.id, event_type: 'added')
      end

      it 'logs audit event' do
        expect { update_framework }
          .to change { AuditEventReader.where("details LIKE ?", "%compliance_framework_id_updated%").count }.by(1)
      end

      it 'enqueues the ProjectComplianceEvaluatorWorker' do
        expect(ComplianceManagement::ProjectComplianceEvaluatorWorker).to receive(:perform_in).with(
          ComplianceManagement::ComplianceFramework::ProjectSettings::PROJECT_EVALUATOR_WORKER_DELAY,
          new_framework.id, [project.id]
        ).once.and_call_original

        update_framework
      end
    end

    shared_examples 'more than 1 frameworks for project' do
      let_it_be(:framework1) { create(:compliance_framework, name: 'framework1', namespace: group) }
      let_it_be(:framework2) { create(:compliance_framework, name: 'framework2', namespace: group) }

      before_all do
        create(:compliance_framework_project_setting,
          project: project, compliance_management_framework: framework1)
        create(:compliance_framework_project_setting,
          project: project, compliance_management_framework: framework2)
      end

      it_behaves_like 'no framework update'

      it 'returns error' do
        response = update_framework

        expect(response).to be_error
        expect(response.message).to eq(multiple_frameworks_error_message)
      end
    end

    context 'when compliance framework feature is available' do
      context 'when user can admin compliance framework for the project' do
        before do
          allow(service).to receive(:can?).with(user, :admin_compliance_framework, project).and_return(true)
        end

        context 'when assigning a compliance framework to a project' do
          context 'when no framework is assigned' do
            let(:old_framework) { [] }

            it_behaves_like 'framework update' do
              let(:new_framework) { framework }
            end

            it 'does not enqueue the ProjectComplianceStatusesRemovalWorker' do
              expect(ComplianceManagement::ComplianceFramework::ProjectComplianceStatusesRemovalWorker)
                .not_to receive(:perform_in)

              update_framework
            end
          end

          context 'when a framework is assigned' do
            let_it_be(:other_framework) { create(:compliance_framework, name: 'other fr', namespace: group) }

            let(:old_framework) { [other_framework] }

            before_all do
              create(:compliance_framework_project_setting,
                project: project, compliance_management_framework: other_framework)
            end

            it_behaves_like 'framework update' do
              let(:new_framework) { framework }
            end
          end

          context 'when more than 1 framework is assigned' do
            it_behaves_like 'more than 1 frameworks for project'
          end

          context 'when project and framework belongs to different namespaces' do
            let_it_be(:other_framework) { create(:compliance_framework) }

            let(:params) { { framework: other_framework.id } }

            context 'when on GitLab.com' do
              before do
                allow(Gitlab).to receive(:com?).and_return(true)
              end

              it_behaves_like 'no framework update'

              it 'returns an error response' do
                response = update_framework

                expect(response).to be_error
                expect(response.message).to eq(
                  format(_('Project %{project_name} and framework %{framework_name} are not from same namespace.'),
                    project_name: project.name, framework_name: other_framework.name
                  )
                )
              end
            end

            context 'when on self-managed instance' do
              let(:old_framework) { [] }

              before do
                allow(Gitlab).to receive(:com?).and_return(false)
              end

              it_behaves_like 'framework update' do
                let(:new_framework) { other_framework }
              end
            end
          end
        end

        context 'when framework param is invalid' do
          let(:params) { { framework: non_existing_record_id } }

          it_behaves_like 'no framework update'

          it 'returns an error response' do
            response = update_framework

            expect(response).to be_error
            expect(response.message).to eq(error_message)
          end
        end

        context 'when unassigning a framework' do
          let(:params) { { framework: nil } }

          context 'when no framework is assigned' do
            it_behaves_like 'no framework update'
          end

          context 'when a framework is assigned' do
            before_all do
              create(:compliance_framework_project_setting,
                project: project, compliance_management_framework: framework)
            end

            it 'unassigns a framework from a project' do
              expect { update_framework }.to change {
                project.reload.compliance_management_frameworks
              }.from([framework]).to([])
            end

            it 'publishes Projects::ComplianceFrameworkChangedEvent with removed event type' do
              expect { update_framework }
                .to publish_event(::Projects::ComplianceFrameworkChangedEvent)
                .with(project_id: project.id, compliance_framework_id: framework.id, event_type: 'removed')
            end

            it 'logs audit event' do
              expect { update_framework }
                .to change { AuditEventReader.where("details LIKE ?", "%compliance_framework_deleted%").count }.by(1)
            end

            it 'enqueues the ProjectComplianceStatusesRemovalWorker' do
              expect(ComplianceManagement::ComplianceFramework::ProjectComplianceStatusesRemovalWorker)
                .to receive(:perform_in)
                .with(ComplianceManagement::ComplianceFramework::ProjectSettings::PROJECT_EVALUATOR_WORKER_DELAY,
                  project.id, framework.id
                ).once.and_call_original

              update_framework
            end
          end

          context 'when more than 1 framework is assigned' do
            it_behaves_like 'more than 1 frameworks for project'
          end
        end
      end

      context 'when user cannot admin compliance framework for the project' do
        before do
          allow(service).to receive(:can?).with(user, :admin_compliance_framework, project).and_return(false)
        end

        it_behaves_like 'no framework update'

        it 'returns an error response' do
          response = update_framework

          expect(response).to be_error
          expect(response.message).to eq(error_message)
        end
      end
    end

    context 'when compliance framework feature is not available' do
      before do
        stub_licensed_features(compliance_framework: false)
      end

      before_all do
        group.add_owner(user)
      end

      it_behaves_like 'no framework update'

      it 'returns an error response' do
        response = update_framework

        expect(response).to be_error
        expect(response.message).to eq(error_message)
      end
    end
  end
end
