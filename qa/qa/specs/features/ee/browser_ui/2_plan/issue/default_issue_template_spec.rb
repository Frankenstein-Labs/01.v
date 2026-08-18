# frozen_string_literal: true

module QA
  RSpec.describe 'Plan', :smoke, feature_category: :team_planning do
    describe 'Default issue templates' do
      let(:default_template_project) { create(:project, name: 'default-issue-template-project') }

      let(:template) { 'This is a default issue template' }

      before do
        Flow::Login.sign_in
      end

      it 'uses default template when creating an issue' do
        default_template_project.visit!

        Page::Project::Menu.perform(&:go_to_general_settings)
        Page::Project::Settings::Main.perform(&:expand_default_description_template_for_issues)
        EE::Page::Project::Settings::IssueTemplateDefault.perform do |issue_settings|
          issue_settings.set_default_issue_template(template)
        end

        Page::Project::Menu.perform(&:go_to_general_settings)
        Page::Project::Settings::Main.perform(&:expand_default_description_template_for_issues)
        EE::Page::Project::Settings::IssueTemplateDefault.perform do |issue_settings|
          expect(issue_settings.default_issue_template_text_project_settings).to eq(template)
        end

        # Clears default description so as not to overwrite default template
        create(:issue, description: nil, project: default_template_project).visit!

        expect(page).to have_content(template)
      end
    end
  end
end
