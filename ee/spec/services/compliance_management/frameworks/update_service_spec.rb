# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::Frameworks::UpdateService, feature_category: :compliance_management do
  let_it_be_with_refind(:namespace) { create(:group) }
  let_it_be_with_refind(:framework) { create(:compliance_framework, namespace: namespace) }
  let_it_be(:current_user) { create(:user, owner_of: namespace) }

  let(:params) { { color: '#000001', description: 'New Description', name: 'New Name' } }

  subject { described_class.new(framework: framework, current_user: current_user, params: params) }

  shared_examples 'a failed update request' do
    it 'does not update the compliance framework' do
      expect { subject.execute }.not_to change { framework.name }
      expect { subject.execute }.not_to change { framework.description }
      expect { subject.execute }.not_to change { framework.color }
    end

    it 'is unsuccessful' do
      expect(subject.execute.success?).to be false
    end
  end

  context 'feature is unlicensed' do
    before do
      stub_licensed_features(custom_compliance_frameworks: false)
    end

    it_behaves_like 'a failed update request'
  end

  context 'current_user is not the namespace owner' do
    let(:current_user) { create(:user) }

    it_behaves_like 'a failed update request'
  end

  context 'when feature is licensed' do
    before do
      stub_licensed_features(custom_compliance_frameworks: true)
    end

    context 'with an invalid param passed' do
      let(:params) { { color: '0001', description: '', name: 'New Name' } }

      it 'is unsuccessful' do
        expect(subject.execute.success?).to be false
      end

      it 'has appropriate errors' do
        expect(subject.execute.payload.full_messages).to contain_exactly 'Color must be a valid color code', "Description can't be blank"
      end
    end

    context 'with valid params passed' do
      it 'updates the compliance framework with valid params' do
        subject.execute

        expect(framework.name).to eq('New Name')
        expect(framework.color).to eq('#000001')
        expect(framework.description).to eq('New Description')
      end

      it 'is successful' do
        expect(subject.execute.success?).to be true
      end

      context 'when framework was created from a template' do
        before do
          framework.update_columns(template_id: 'soc2', template_version: 1)
        end

        it 'preserves template_id and template_version when content fields are modified' do
          subject.execute

          expect(framework.reload.template_id).to eq('soc2')
          expect(framework.template_version).to eq(1)
        end

        context 'when only the default flag is being updated' do
          let(:params) { { default: true } }

          before do
            namespace.namespace_settings.update!(default_compliance_framework_id: nil)
          end

          it 'preserves template_id and template_version' do
            subject.execute

            expect(framework.reload.template_id).to eq('soc2')
            expect(framework.template_version).to eq(1)
          end
        end

        context 'when only projects are being updated' do
          let(:project) { create(:project, namespace: namespace) }
          let(:params) { { projects: { add_projects: [project.id], remove_projects: [] } } }

          it 'preserves template_id and template_version' do
            subject.execute

            expect(framework.reload.template_id).to eq('soc2')
            expect(framework.template_version).to eq(1)
          end
        end

        context 'when params are empty' do
          let(:params) { {} }

          it 'preserves template_id and template_version' do
            subject.execute

            expect(framework.reload.template_id).to eq('soc2')
            expect(framework.template_version).to eq(1)
          end
        end

        context 'when params attempt to override template_id and template_version' do
          let(:params) { { template_id: 'gdpr', template_version: 99 } }

          it 'ignores them and preserves the original values' do
            subject.execute

            expect(framework.reload.template_id).to eq('soc2')
            expect(framework.template_version).to eq(1)
          end
        end
      end

      it 'audits the changes' do
        expect { subject.execute }.to change { AuditEventReader.count }.by(3)

        messages = AuditEventReader.last(3).map { |e| e.details[:custom_message] }

        expect(messages).to contain_exactly(
          'Changed compliance framework\'s "name" from "GDPR" to "New Name"',
          'Changed compliance framework\'s "color" from "#004494" to "#000001"',
          'Changed compliance framework\'s "description" from "The General Data Protection Regulation (GDPR) is a regulation in EU law on data protection and privacy in the European Union (EU) and the European Economic Area (EEA)." to "New Description"'
        )
      end

      context 'when default param is used' do
        context 'when true' do
          before do
            params[:default] = true
            namespace.namespace_settings.update!(default_compliance_framework_id: nil)
          end

          it 'updates the default compliance framework for the namespace' do
            expect_next_instance_of(::Groups::UpdateService) do |group_update_service|
              expect(group_update_service).to receive(:execute).and_call_original
            end

            subject.execute

            expect(namespace.reload.namespace_settings.default_compliance_framework_id).to eq(framework.id)
          end
        end

        context 'when false' do
          before do
            params[:default] = false
          end

          it 'does not update the default framework for the namespace when default framework is not set' do
            namespace.namespace_settings.update!(default_compliance_framework_id: nil)

            expect(::Groups::UpdateService).not_to receive(:new)

            subject.execute

            expect(namespace.reload.namespace_settings.default_compliance_framework_id).to be_nil
          end

          it 'removes the default framework for the namespace' do
            namespace.namespace_settings.update!(default_compliance_framework_id: framework.id)

            expect_next_instance_of(::Groups::UpdateService) do |group_update_service|
              expect(group_update_service).to receive(:execute).and_call_original
            end

            subject.execute

            expect(namespace.reload.namespace_settings.default_compliance_framework_id).to be_nil
          end
        end
      end

      context 'when projects param is included' do
        let(:project) { create :project, namespace: namespace }
        let(:project_two) { create :project, namespace: namespace }
        let_it_be(:project_three) { create :project, namespace: namespace }
        let_it_be(:existing_project) { create :compliance_framework_project_setting, compliance_management_framework: framework, project: project_three }

        context 'with valid projects from the same namespace' do
          before do
            params[:projects] = {
              add_projects: [project.id, project_two.id],
              remove_projects: [existing_project.project_id]
            }
          end

          it 'applies the framework to the selected projects' do
            framework = subject.execute.payload[:framework]
            project_ids = ComplianceManagement::ComplianceFramework::ProjectSettings.where(framework_id: framework.id).pluck(:project_id)
            expect(project_ids).to include(project.id)
            expect(project_ids).to include(project_two.id)
          end

          it 'removes the framework from the unselected projects' do
            project_ids = ComplianceManagement::ComplianceFramework::ProjectSettings.where(framework_id: framework.id).pluck(:project_id)
            expect(project_ids).to include(existing_project.project_id)
            framework = subject.execute.payload[:framework]
            project_ids = ComplianceManagement::ComplianceFramework::ProjectSettings.where(framework_id: framework.id).pluck(:project_id)
            expect(project_ids).not_to include(existing_project.project_id)
          end
        end

        context 'when trying to add projects from different groups' do
          let(:other_group) { create(:group) }
          let(:external_project) { create(:project, namespace: other_group) }

          before do
            params[:projects] = {
              add_projects: [external_project.id],
              remove_projects: []
            }
          end

          it 'does not add the external project' do
            subject.execute

            project_ids = ComplianceManagement::ComplianceFramework::ProjectSettings
              .where(framework_id: framework.id)
              .pluck(:project_id)

            expect(project_ids).not_to include(external_project.id)
          end

          it 'returns an error message about the project not belonging to the namespace' do
            result = subject.execute

            expect(result.message)
              .to include(format(_("Project %{project_name} and framework are not from same namespace."),
                project_name: external_project.name))
          end
        end

        context 'when trying to add projects from subgroups' do
          let(:subgroup) { create(:group, parent: namespace) }
          let(:subgroup_project) { create(:project, namespace: subgroup) }

          before do
            params[:projects] = {
              add_projects: [subgroup_project.id],
              remove_projects: []
            }
          end

          it 'successfully adds the subgroup project' do
            subject.execute

            project_ids = ComplianceManagement::ComplianceFramework::ProjectSettings
              .where(framework_id: framework.id)
              .pluck(:project_id)

            expect(project_ids).to include(subgroup_project.id)
          end
        end

        context 'when trying to add non-existent projects' do
          let(:non_existent_id) { 999999 }

          before do
            params[:projects] = {
              add_projects: [non_existent_id, project.id],
              remove_projects: []
            }
          end

          it 'handles the error gracefully and still adds valid projects' do
            subject.execute

            project_ids = ComplianceManagement::ComplianceFramework::ProjectSettings
              .where(framework_id: framework.id)
              .pluck(:project_id)

            expect(project_ids).to include(project.id)
            expect(project_ids).not_to include(non_existent_id)
          end

          it 'returns an error message about the non-existent project' do
            result = subject.execute

            expect(result.message).to include(format(_("Project with ID %{project_id} not found"),
              project_id: non_existent_id))
          end
        end

        context 'when mixing valid and invalid projects' do
          let(:other_group) { create(:group) }
          let(:external_project) { create(:project, namespace: other_group) }
          let(:non_existent_id) { 999999 }

          before do
            params[:projects] = {
              add_projects: [project.id, external_project.id, non_existent_id, project_two.id],
              remove_projects: []
            }
          end

          it 'only adds the valid projects from the same group' do
            subject.execute

            project_ids = ComplianceManagement::ComplianceFramework::ProjectSettings
              .where(framework_id: framework.id)
              .pluck(:project_id)

            expect(project_ids).to include(project.id, project_two.id)
            expect(project_ids).not_to include(external_project.id, non_existent_id)
          end

          it 'returns multiple error messages' do
            result = subject.execute

            expect(result.message)
              .to include(format(_("Project %{project_name} and framework are not from same namespace."),
                project_name: external_project.name))
            expect(result.message).to include(format(_("Project with ID %{project_id} not found"),
              project_id: non_existent_id))
          end
        end
      end
    end
  end
end
