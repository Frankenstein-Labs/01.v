# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::Frameworks::CreateService, feature_category: :compliance_management do
  let_it_be_with_refind(:namespace) { create(:group) }
  let_it_be(:current_user) { create(:user, owner_of: namespace) }

  let(:params) do
    {
      name: 'GDPR',
      description: 'The EUs data protection directive',
      color: '#abc123'
    }
  end

  context 'custom_compliance_frameworks is disabled' do
    before do
      stub_licensed_features(custom_compliance_frameworks: false)
    end

    subject { described_class.new(namespace: namespace, params: params, current_user: current_user) }

    it 'does not create a new compliance framework' do
      expect { subject.execute }.not_to change { ComplianceManagement::Framework.count }
    end

    it 'responds with an error message' do
      expect(subject.execute.message).to eq('Not permitted to create framework')
    end
  end

  context 'custom_compliance_frameworks is enabled' do
    before do
      stub_licensed_features(custom_compliance_frameworks: true)
    end

    context 'namespace has a parent' do
      let_it_be(:user) { create(:user) }
      let_it_be_with_reload(:group) { create(:group, :with_hierarchy, owners: user) }

      let(:descendant) { group.descendants.first }

      subject { described_class.new(namespace: descendant, params: params, current_user: user) }

      it 'responds with a successful service response' do
        expect(subject.execute.success?).to be true
      end

      it 'creates the new framework in the root namespace' do
        expect(subject.execute.payload[:framework].namespace).to eq(group)
      end
    end

    context 'when using invalid parameters' do
      subject { described_class.new(namespace: namespace, params: params.except(:name), current_user: current_user) }

      let(:response) { subject.execute }

      it 'responds with an error service response' do
        expect(response.success?).to eq false
        expect(response.payload.messages[:name]).to contain_exactly "can't be blank"
      end
    end

    context 'when creating a compliance framework for a namespace that current_user is not the owner of' do
      let_it_be(:non_owner) { create(:user) }

      subject { described_class.new(namespace: namespace, params: params, current_user: non_owner) }

      it 'responds with an error service response' do
        expect(subject.execute.success?).to be false
      end

      it 'does not create a new compliance framework' do
        expect { subject.execute }.not_to change { ComplianceManagement::Framework.count }
      end
    end

    context 'when pipeline_configuration_full_path parameter is used and feature is not available' do
      subject { described_class.new(namespace: namespace, params: params, current_user: current_user) }

      before do
        params[:pipeline_configuration_full_path] = '.compliance-gitlab-ci.yml@compliance/hipaa'
        stub_licensed_features(custom_compliance_frameworks: true, evaluate_group_level_compliance_pipeline: false)
      end

      let(:response) { subject.execute }

      it 'returns an error', :aggregate_failures do
        expect(response.success?).to be false
        expect(response.message).to eq 'Pipeline configuration full path feature is not available'
      end
    end

    context 'when using parameters for a valid compliance framework' do
      subject { described_class.new(namespace: namespace, params: params, current_user: current_user) }

      it 'audits the changes' do
        expect { subject.execute }.to change { AuditEventReader.count }.by(1)
      end

      it 'creates a new compliance framework' do
        expect { subject.execute }.to change { ComplianceManagement::Framework.count }.by(1)
      end

      it 'responds with a successful service response' do
        expect(subject.execute.success?).to be true
      end

      it 'has the expected attributes' do
        framework = subject.execute.payload[:framework]

        expect(framework.name).to eq('GDPR')
        expect(framework.description).to eq('The EUs data protection directive')
        expect(framework.color).to eq('#abc123')
      end

      context 'when template_id and template_version params are provided' do
        before do
          params[:template_id] = 'soc2'
          params[:template_version] = 1
        end

        it 'sets the template fields' do
          framework = subject.execute.payload[:framework]

          expect(framework.template_id).to eq('soc2')
          expect(framework.template_version).to eq(1)
        end
      end

      context 'when compliance pipeline configuration is available' do
        before do
          params[:pipeline_configuration_full_path] = '.compliance-gitlab-ci.yml@compliance/hipaa'
          stub_licensed_features(custom_compliance_frameworks: true, evaluate_group_level_compliance_pipeline: true)
        end

        it 'sets the pipeline configuration path attribute' do
          framework = subject.execute.payload[:framework]

          expect(framework.pipeline_configuration_full_path).to eq('.compliance-gitlab-ci.yml@compliance/hipaa')
        end
      end

      context 'when default param is used' do
        context 'when true' do
          before do
            params[:default] = true
            namespace.namespace_settings.update!(default_compliance_framework_id: nil)
          end

          it 'sets the new framework as the default framework for the namespace' do
            expect_next_instance_of(::Groups::UpdateService) do |group_update_service|
              expect(group_update_service).to receive(:execute).and_call_original
            end

            framework = subject.execute.payload[:framework]

            expect(namespace.reload.namespace_settings.default_compliance_framework_id).to eq(framework.id)
          end
        end

        context 'when false' do
          before do
            params[:default] = false
            namespace.namespace_settings.update!(default_compliance_framework_id: nil)
          end

          it 'does not set the new framework as the default framework for the namespace' do
            expect(::Groups::UpdateService).not_to receive(:new)

            subject.execute

            expect(namespace.namespace_settings.default_compliance_framework_id).to be_nil
          end
        end
      end

      context 'when projects param is included' do
        let_it_be(:project) { create(:project, namespace: namespace) }
        let_it_be(:project_two) { create(:project, namespace: namespace) }

        context 'with valid projects from the same namespace' do
          before do
            params[:projects] = {
              add_projects: [project.id, project_two.id]
            }
          end

          it 'applies the framework to the selected projects' do
            framework = subject.execute.payload[:framework]
            project_ids = ComplianceManagement::ComplianceFramework::ProjectSettings
              .where(framework_id: framework.id)
              .pluck(:project_id)

            expect(project_ids).to include(project.id)
            expect(project_ids).to include(project_two.id)
          end
        end

        context 'when trying to add projects from different groups' do
          let_it_be(:other_group) { create(:group) }
          let_it_be(:external_project) { create(:project, namespace: other_group) }

          before do
            params[:projects] = {
              add_projects: [external_project.id]
            }
          end

          it 'does not add the external project' do
            framework = subject.execute.payload[:framework]

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
              add_projects: [subgroup_project.id]
            }
          end

          it 'successfully adds the subgroup project' do
            framework = subject.execute.payload[:framework]

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
              add_projects: [non_existent_id, project.id]
            }
          end

          it 'creates the framework and handles the error gracefully' do
            expect { subject.execute }.to change { ComplianceManagement::Framework.count }.by(1)

            framework = subject.execute.payload[:framework]
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
          let_it_be(:other_group) { create(:group) }
          let_it_be(:external_project) { create(:project, namespace: other_group) }
          let(:non_existent_id) { 999999 }

          before do
            params[:projects] = {
              add_projects: [project.id, external_project.id, non_existent_id, project_two.id]
            }
          end

          it 'creates the framework but only adds valid projects from the same group' do
            expect { subject.execute }.to change { ComplianceManagement::Framework.count }.by(1)

            framework = subject.execute.payload[:framework]
            project_ids = ComplianceManagement::ComplianceFramework::ProjectSettings
              .where(framework_id: framework.id)
              .pluck(:project_id)

            expect(project_ids).to include(project.id, project_two.id)
            expect(project_ids).not_to include(external_project.id, non_existent_id)
          end

          it 'returns multiple error messages' do
            result = subject.execute

            expect(result.success?).to be true # Framework is still created
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
