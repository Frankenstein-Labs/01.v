# frozen_string_literal: true

module QA
  RSpec.describe(
    'Security Risk Management', feature_category: :security_policy_management
  ) do
    describe 'Security policies' do
      let!(:project) do
        Resource::Project.fabricate_via_api_unless_fips! do |project|
          project.name = Runtime::Env.auto_devops_project_name || 'project-with-protect'
          project.description = 'Project with Protect'
          project.auto_devops_enabled = true
          project.initialize_with_readme = true
          project.template_name = 'express'
        end
      end

      let!(:commit) do
        create(:commit, project: project, actions: [{ action: 'create', file_path: 'foo', content: 'bar' }])
      end

      before do
        Flow::Login.sign_in
        project.visit!
      end

      it 'can load Policies page and view the policies list' do
        Page::Project::Menu.perform(&:go_to_policies)

        EE::Page::Project::Policies::PolicyList.perform do |policies_page|
          aggregate_failures do
            expect(policies_page).to have_policies_list
          end
        end
      end

      it 'can navigate to Policy Editor page' do
        Page::Project::Menu.perform(&:go_to_policies)

        EE::Page::Project::Policies::PolicyList.perform(&:click_new_policy_button)

        EE::Page::Project::Policies::PolicyEditor.perform do |policy_editor|
          aggregate_failures do
            expect(policy_editor).to have_policy_selection('policy-selection-wizard')
          end
        end
      end

      it 'can create a new policy' do
        Page::Project::Menu.perform(&:go_to_policies)

        EE::Page::Project::Policies::PolicyList.perform(&:click_new_policy_button)

        EE::Page::Project::Policies::PolicyEditor.perform do |policy_editor|
          policy_editor.select_scan_execution_policy
          policy_editor.fill_name
          policy_editor.click_save_policy_button
        end

        Page::MergeRequest::Show.perform do |mr_page|
          mr_page.wait_until(max_duration: 60, sleep_interval: 2, reload: true,
            message: 'Wait for policy MR page') do
            mr_page.has_merge_button?
          end
        end

        expect(page.current_url).to include('-security-policy-project/-/merge_requests/1')
      end
    end
  end
end
