# frozen_string_literal: true

require 'spec_helper'

# Group Hierarchy:

# Group
#   Subgroup 1
#     Subgroup 1_1
#      Subgroup 1_1_1
#     Subgroup 1_2 (the group with the template)
#       project_template
#       Subgroup_1_2_1
#   Subgroup 2
#     Subgroup 2_1
# Group 2

RSpec.describe Projects::CreateFromTemplateService, feature_category: :importers do
  using RSpec::Parameterized::TableSyntax

  let(:group) { create(:group) }
  let!(:project) { create(:project, :public, namespace: group) }
  let(:user) { create(:user) }
  let(:project_name) { project.name }
  let(:use_custom_template) { true }

  let(:subgroup_1) { create(:group, parent: group) }
  let(:subgroup_1_1) { create(:group, parent: subgroup_1) }
  let(:subgroup_1_1_1) { create(:group, parent: subgroup_1_1) }
  let(:subgroup_1_2) { create(:group, parent: subgroup_1) }
  let(:subgroup_1_2_1) { create(:group, parent: subgroup_1_2) }
  let(:subgroup_2) { create(:group, parent: group) }
  let(:subgroup_2_1) { create(:group, parent: subgroup_2) }
  let(:project_template) { create(:project, :public, :metrics_dashboard_enabled, namespace: subgroup_1_2) }
  let(:template_name) { project_template.name }
  let(:namespace_id) { nil }
  let(:group_with_project_templates_id) { nil }

  let(:project_params) do
    {
      path: user.to_param,
      template_name: template_name,
      description: 'project description',
      visibility_level: Gitlab::VisibilityLevel::PUBLIC,
      use_custom_template: use_custom_template,
      namespace_id: namespace_id,
      group_with_project_templates_id: group_with_project_templates_id
    }
  end

  subject { described_class.new(user, project_params) }

  before do
    stub_licensed_features(custom_project_templates: true)
    stub_ee_application_setting(custom_project_templates_group_id: subgroup_1_2.id)
  end

  describe '#execute' do
    shared_examples 'a persisted project' do
      it 'is persisted' do
        project = subject.execute

        expect(project).to be_saved
        expect(project.import_scheduled?).to be(true)
      end
    end

    shared_examples 'a project that isn\'t persisted' do |error_message = nil|
      it "isn't persisted" do
        project = subject.execute

        expect(project).not_to be_saved
        expect(project.repository.empty?).to be(true)
        expect(project.errors.full_messages).to include(error_message) if error_message
      end
    end

    context 'does not create project from custom template' do
      after do
        project = subject.execute

        expect(project).not_to be_saved
        expect(project.repository.empty?).to be true
      end

      context 'when use_custom_template is not present or false' do
        let(:use_custom_template) { false }

        it 'creates an empty project' do
          expect(::Gitlab::ProjectTemplate).to receive(:find)
          expect(::Gitlab::SampleDataTemplate).to receive(:find)
          expect(subject).not_to receive(:find_template_project)
        end
      end

      context 'when custom_project_templates feature is not enabled' do
        it 'creates an empty project' do
          stub_licensed_features(custom_project_templates: false)

          expect(::Gitlab::ProjectTemplate).to receive(:find)
          expect(::Gitlab::SampleDataTemplate).to receive(:find)
          expect(subject).not_to receive(:find_template_project)
        end
      end

      context 'when custom_project_template does not exist' do
        let(:template_name) { 'whatever' }

        it 'does not attempt to import a project' do
          expect(::Projects::GitlabProjectsImportService).not_to receive(:new)
        end
      end

      context 'when use_custom_template is true but template_name and template_project_id are nil' do
        let(:template_name) { nil }

        before do
          project_params[:template_project_id] = nil
        end

        it 'return a project with error' do
          project = subject.execute
          expect(project).not_to be_saved
          expect(project.errors.messages).to eq(
            use_custom_template: ['must be used with template_name or template_project_id']
          )
        end
      end
    end

    where(:use_template_name) { [true, false] }

    with_them do
      before do
        if use_template_name
          project_params[:template_name] = template_name
          project_params.delete(:template_project_id)
        else
          project_params.delete(:template_name)
          project_params[:template_project_id] = project_template.id
        end

        @project = subject.execute
      end

      it 'returns the created project' do
        expect(@project).to be_saved
        expect(@project.import_scheduled?).to be(true)
      end

      context 'the result project' do
        it 'overrides template description' do
          expect(@project.description).to match('project description')
        end

        it 'overrides template visibility_level' do
          expect(@project.visibility_level).to eq(Gitlab::VisibilityLevel::PUBLIC)
        end
      end

      describe 'creating project from a Group project template' do
        let(:project_name) { project_template.name }
        let(:group_with_project_templates_id) { subgroup_1_2.id }
        let(:group2) { create(:group) }

        before do
          subgroup_1.update!(custom_project_templates_group_id: subgroup_1_2.id)
          group.add_maintainer(user)
          group2.add_maintainer(user)
        end

        context 'when the namespace is not a descendant of the Group owning the template' do
          context 'when project is created under a group that is outside the hierarchy its root ancestor group' do
            let(:namespace_id) { group2.id }

            it_behaves_like 'a project that isn\'t persisted'
          end

          context 'when project is created under a group that is a descendant of its root ancestor group' do
            let(:namespace_id) { subgroup_2.id }

            it_behaves_like 'a project that isn\'t persisted'
          end

          context 'when project is created under a subgroup that is a descendant of its root ancestor group' do
            let(:namespace_id) { subgroup_2_1.id }

            it_behaves_like 'a project that isn\'t persisted'
          end

          context 'when project is created outside of group hierarchy' do
            let(:user) { create(:user) }
            let(:project) { create(:project, :public, namespace: user.namespace) }
            let(:namespace_id) { user.namespace_id }

            it_behaves_like 'a project that isn\'t persisted'
          end
        end

        context 'when the namespace is inside the hierarchy of the Group owning the template' do
          context 'when project is created under its parent group' do
            let(:namespace_id) { subgroup_1.id }

            it_behaves_like 'a persisted project'
          end

          context 'when project is created under the same group' do
            let(:namespace_id) { subgroup_1_2.id }

            it_behaves_like 'a persisted project'
          end

          context 'when project is created under its descendant group' do
            let(:namespace_id) { subgroup_1_2_1.id }

            it_behaves_like 'a persisted project'
          end

          context 'when project is created under a group that is a descendant of its parent group' do
            let(:namespace_id) { subgroup_1_1.id }

            it_behaves_like 'a persisted project'
          end

          context 'when project is created under a subgroup that is a descendant of its parent group' do
            let(:namespace_id) { subgroup_1_1_1.id }

            it_behaves_like 'a persisted project'
          end
        end
      end
    end

    describe 'when using a built-in project template' do
      let(:use_custom_template) { false }
      let(:template_name) { 'rails' }
      let(:namespace_id) { subgroup_1.id }

      before do
        stub_licensed_features(built_in_project_templates_enabled: true)

        subgroup_1.add_maintainer(user)
      end

      context 'when built-in project templates are disabled for the target group' do
        before do
          subgroup_1.namespace_settings.update!(built_in_project_templates_enabled: false)
        end

        it_behaves_like 'a project that isn\'t persisted',
          _('Group has disabled the use of built-in project templates')

        context 'when enabled in a parent group' do
          before do
            group.namespace_settings.update!(built_in_project_templates_enabled: true)
          end

          it_behaves_like 'a project that isn\'t persisted',
            _('Group has disabled the use of built-in project templates')
        end

        context 'when the target namespace is nil' do
          let(:namespace_id) { nil }

          it_behaves_like 'a persisted project'
        end
      end

      context 'when the target namespace is a personal namespace' do
        let(:namespace_id) { user.namespace_id }

        context 'when the instance-level setting is available' do
          before do
            stub_ee_application_setting(instance_built_in_project_templates_enabled_available?: true)
          end

          context 'when built-in project templates are disabled at the instance level' do
            before do
              stub_application_setting(built_in_project_templates_enabled: false)
            end

            it_behaves_like 'a project that isn\'t persisted',
              _('Instance has disabled the use of built-in project templates')
          end

          context 'when built-in project templates are enabled at the instance level' do
            before do
              stub_application_setting(built_in_project_templates_enabled: true)
            end

            it_behaves_like 'a persisted project'
          end
        end

        context 'when the instance-level setting is not available (e.g. SaaS)' do
          before do
            stub_ee_application_setting(instance_built_in_project_templates_enabled_available?: false)
            stub_application_setting(built_in_project_templates_enabled: false)
          end

          it_behaves_like 'a persisted project'
        end
      end

      context 'when built-in project templates are enabled for the target group' do
        before do
          subgroup_1.namespace_settings.update!(built_in_project_templates_enabled: true)
        end

        it_behaves_like 'a persisted project'

        it 'passes the built-in template import type to the import service' do
          expect(::Projects::GitlabProjectsImportService).to receive(:new)
            .with(user, anything, anything, hash_including(import_type: 'gitlab_built_in_project_template'))
            .and_call_original

          subject.execute
        end

        context 'when disabled in a parent group' do
          before do
            group.namespace_settings.update!(built_in_project_templates_enabled: false)
          end

          it_behaves_like 'a persisted project'
        end
      end

      context 'when the built-in project templates feature is not available' do
        before do
          stub_licensed_features(built_in_project_templates_enabled: false)
          subgroup_1.namespace_settings.update!(built_in_project_templates_enabled: false)
        end

        it_behaves_like 'a persisted project'
      end
    end

    context 'when template_name is a substring of another template name' do
      let!(:other_template) do
        create(:project, :public, :metrics_dashboard_enabled, namespace: subgroup_1_2,
          name: "python-#{project_template.name}")
      end

      before do
        project_params[:template_name] = project_template.name
        project_params.delete(:template_project_id)
      end

      it 'selects the exact matching template, not the substring match' do
        expect(::Projects::GitlabProjectsImportService).to receive(:new)
          .with(user, hash_including(custom_template: project_template), anything, anything)
          .and_call_original

        project = subject.execute

        expect(project).to be_saved
        expect(project.import_scheduled?).to be(true)
      end

      context 'when template_name has no exact match but has fuzzy matches' do
        let(:template_name) { project_template.name[0...-1] }

        before do
          project_params[:template_name] = template_name
        end

        it 'falls back to the first fuzzy match' do
          project = subject.execute

          expect(project).to be_saved
          expect(project.import_scheduled?).to be(true)
        end
      end
    end

    context 'when current_user does not have read_code permissions to the template_project' do
      let(:group_with_project_templates_id) { subgroup_1.id }
      let(:project_template) { create(:project, :private, :metrics_dashboard_enabled, namespace: subgroup_1) }
      let(:namespace_id) { subgroup_2.id }

      before do
        project_params.delete(:template_name)
        project_params[:template_project_id] = project_template.id

        group.update!(custom_project_templates_group_id: subgroup_1.id)
        subgroup_1.add_guest(user)
        subgroup_2.add_maintainer(user)
      end

      it "isn't persisted" do
        project = subject.execute

        expect(project.errors&.first&.full_message).to match(
          "Template project #{project_template.id} is unknown or invalid"
        )
        expect(project).not_to be_saved
        expect(project.repository.empty?).to be(true)
      end
    end
  end
end
