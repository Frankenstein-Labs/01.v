# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::Frameworks::UpdateProjectService, feature_category: :compliance_management do
  describe '#execute' do
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group) }
    let_it_be_with_reload(:project) { create(:project, group: group) }
    let_it_be(:framework1) { create(:compliance_framework, name: 'framework1', namespace: group) }
    let_it_be(:framework2) { create(:compliance_framework, name: 'framework2', namespace: group) }
    let_it_be(:framework3) { create(:compliance_framework, name: 'framework3', namespace: group) }
    let_it_be(:framework4) { create(:compliance_framework, name: 'framework4', namespace: group) }

    let(:frameworks) { [framework1, framework2] }

    let(:service) { described_class.new(project, user, frameworks) }

    subject(:update_framework) { service.execute }

    context 'when compliance framework feature is available' do
      before do
        allow(service).to receive(:can?).with(user, :admin_compliance_framework, project).and_return(true)
      end

      context 'when the input parameters are correct' do
        context 'when project has no framework associated with it' do
          it 'adds the framework association' do
            expect { update_framework }.to change {
              project.reload.compliance_management_frameworks
            }.from([]).to(
              match_array([framework1, framework2])
            )
          end

          it 'logs audit events' do
            expect { update_framework }.to change {
              AuditEventReader.where("details LIKE ?", "%compliance_framework_added%").count
            }.by(2)
          end

          it 'publishes Projects::ComplianceFrameworkChangedEvent' do
            expect(::Gitlab::EventStore).to receive(:publish)
              .with(an_instance_of(::Projects::ComplianceFrameworkChangedEvent)).twice

            update_framework
          end

          it 'enqueues the ProjectComplianceEvaluatorWorker' do
            expect(ComplianceManagement::ProjectComplianceEvaluatorWorker).to receive(:perform_in).with(
              ComplianceManagement::ComplianceFramework::ProjectSettings::PROJECT_EVALUATOR_WORKER_DELAY,
              framework1.id, [project.id]
            ).and_call_original
            expect(ComplianceManagement::ProjectComplianceEvaluatorWorker).to receive(:perform_in).with(
              ComplianceManagement::ComplianceFramework::ProjectSettings::PROJECT_EVALUATOR_WORKER_DELAY,
              framework2.id, [project.id]
            ).and_call_original

            update_framework
          end
        end

        context "when given a framework from another group" do
          let_it_be(:csp_group) { create(:group, name: "CSP Group") }
          let_it_be(:csp_framework) { create(:compliance_framework, name: 'CSP Framework', namespace: csp_group) }

          let(:service) { described_class.new(project, user, [csp_framework]) }

          context "when the group is not the CSP Group" do
            it "does not add the framework association" do
              expect { update_framework }.not_to change {
                project.reload.compliance_management_frameworks.to_a
              }
            end
          end

          context "when the group is the CSP Group" do
            include Security::PolicyCspHelpers

            before do
              project.clear_memoization(:organization_policy_setting)
              stub_csp_group(csp_group)
            end

            it "adds the framework association for the CSP framework" do
              expect { update_framework }.to change {
                project.reload.compliance_management_frameworks
              }.from([]).to(
                match_array([csp_framework])
              )
            end

            it 'logs audit events' do
              expect { update_framework }.to change {
                AuditEventReader.where("details LIKE ?", "%compliance_framework_added%").count
              }.by(1)
            end

            it 'enqueues the ProjectComplianceEvaluatorWorker' do
              expect(ComplianceManagement::ProjectComplianceEvaluatorWorker).to receive(:perform_in).with(
                ComplianceManagement::ComplianceFramework::ProjectSettings::PROJECT_EVALUATOR_WORKER_DELAY,
                csp_framework.id, [project.id]
              ).and_call_original

              update_framework
            end

            it 'publishes Projects::ComplianceFrameworkChangedEvent' do
              expect(::Gitlab::EventStore).to receive(:publish)
                .with(an_instance_of(::Projects::ComplianceFrameworkChangedEvent))

              update_framework
            end
          end
        end

        context 'when project already has some frameworks associated with it' do
          before do
            create(:compliance_framework_project_setting, project: project, compliance_management_framework: framework2)
            create(:compliance_framework_project_setting, project: project, compliance_management_framework: framework3)
            create(:compliance_framework_project_setting, project: project, compliance_management_framework: framework4)
          end

          it 'adds and removes framework associations' do
            expect { update_framework }.to change {
              project.reload.compliance_management_frameworks
            }.from(
              match_array([framework2, framework3, framework4])
            ).to(
              match_array([framework1, framework2])
            )
          end

          it 'logs audit events' do
            expect { update_framework }.to change {
              AuditEventReader.where("details LIKE ?", "%compliance_framework_added%").count
            }.by(1).and change {
              AuditEventReader.where("details LIKE ?", "%compliance_framework_removed%").count
            }.by(2)
          end

          it 'publishes Projects::ComplianceFrameworkChangedEvent' do
            expect(::Gitlab::EventStore).to receive(:publish)
              .with(an_instance_of(::Projects::ComplianceFrameworkChangedEvent)).exactly(3).times

            update_framework
          end

          it 'enqueues the ProjectComplianceEvaluatorWorker' do
            expect(ComplianceManagement::ProjectComplianceEvaluatorWorker).to receive(:perform_in).with(
              ComplianceManagement::ComplianceFramework::ProjectSettings::PROJECT_EVALUATOR_WORKER_DELAY,
              framework1.id, [project.id]
            ).once.and_call_original

            update_framework
          end

          it 'enqueues the ProjectComplianceStatusesRemovalWorker' do
            expect(ComplianceManagement::ComplianceFramework::ProjectComplianceStatusesRemovalWorker)
              .to receive(:perform_in).with(
                ComplianceManagement::ComplianceFramework::ProjectSettings::PROJECT_EVALUATOR_WORKER_DELAY,
                project.id, framework3.id
              ).once.ordered.and_call_original
            expect(ComplianceManagement::ComplianceFramework::ProjectComplianceStatusesRemovalWorker)
              .to receive(:perform_in).with(
                ComplianceManagement::ComplianceFramework::ProjectSettings::PROJECT_EVALUATOR_WORKER_DELAY,
                project.id, framework4.id
              ).once.ordered.and_call_original

            update_framework
          end
        end

        context 'when there is an error while saving framework project setting' do
          it 'returns error', :aggregate_failures do
            expect(ComplianceManagement::ProjectComplianceEvaluatorWorker).not_to receive(:perform_in)

            save_error_message = 'Not able to save project settings for compliance framework'
            error_message = "Error while adding framework #{frameworks.first.name}. Errors: #{save_error_message}"

            allow_next_instance_of(ComplianceManagement::ComplianceFramework::ProjectSettings) do |instance|
              allow(instance).to receive(:save).and_return(false)

              errors = ActiveModel::Errors.new(instance).tap { |e| e.add(:base, save_error_message) }
              allow(instance).to receive(:errors).and_return(errors)
            end

            expect(update_framework.errors).to eq([error_message])
          end
        end

        context 'when there is an error while deleting a framework project setting' do
          before do
            create(:compliance_framework_project_setting, project: project, compliance_management_framework: framework3)
          end

          let(:frameworks) { [] }

          it 'returns error' do
            save_error_message = 'Not able to delete project settings for compliance framework'
            error_message = "Error while removing framework framework3. Errors: #{save_error_message}"

            allow_next_found_instance_of(ComplianceManagement::ComplianceFramework::ProjectSettings) do |instance|
              allow(instance).to receive(:destroy).and_return(false)

              errors = ActiveModel::Errors.new(instance).tap { |e| e.add(:base, save_error_message) }
              allow(instance).to receive(:errors).and_return(errors)
            end

            expect(update_framework.errors).to eq([error_message])
          end
        end
      end
    end

    context 'when compliance framework feature is unavailable' do
      before do
        stub_licensed_features(compliance_framework: false)
      end

      before_all do
        group.add_owner(user)
      end

      it 'returns an error response' do
        response = update_framework

        expect(response).to be_error
        expect(response.message).to eq('Failed to assign the framework to the project')
      end
    end
  end
end
