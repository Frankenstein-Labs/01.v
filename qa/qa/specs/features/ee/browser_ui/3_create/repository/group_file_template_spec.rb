# frozen_string_literal: true

module QA
  RSpec.describe 'Create', feature_category: :source_code_management do
    describe 'Group file templates', :requires_admin do
      include Support::API

      let(:api_client) { Runtime::API::Client.as_admin }

      let(:group) { create(:group, path: 'template-group', api_client: api_client) }

      let(:file_name) { 'Dockerfile' }
      let(:template) { 'custom_dockerfile' }
      let(:action) { 'create' }
      let(:file_path) { 'Dockerfile/custom_dockerfile.dockerfile' }
      let(:content) { 'dockerfile template test' }

      let(:file_template_project) do
        create(:project,
          :with_readme,
          name: 'group-file-template-project',
          description: 'Add group file templates',
          group: group,
          api_client: api_client)
      end

      let(:project) do
        create(:project,
          :with_readme,
          name: 'group-file-template-project-2',
          description: 'Add files for group file templates',
          group: group,
          api_client: api_client)
      end

      it "creates file via custom Dockerfile file template" do
        api_client.personal_access_token

        create(:commit,
          project: file_template_project,
          commit_message: 'Add group file templates',
          api_client: api_client,
          actions: [{
            file_name: file_name,
            template: template,
            action: action,
            file_path: file_path,
            content: content
          }])

        Flow::Login.sign_in_as_admin

        set_file_template_if_not_already_set

        project.visit!

        Page::Project::Show.perform(&:create_new_file!)
        Page::File::Form.perform do |form|
          Support::Retrier.retry_until do
            form.add_custom_name(file_name)
            form.select_template(file_name, template)

            form.has_normalized_ws_text?(content)
          end
          form.click_commit_changes_in_header
          form.commit_changes_through_modal

          aggregate_failures "indications of file created" do
            expect(form).to have_content(file_name)
            expect(form).to have_normalized_ws_text(content.chomp)
            expect(form).to have_content('Add new file')
          end
        end

        remove_group_file_template_if_set
      end

      def set_file_template_if_not_already_set
        response = get Runtime::API::Request.new(api_client, "/groups/#{group.id}").url

        return if parse_body(response)[:file_template_project_id]

        group.visit!
        Page::Group::Menu.perform(&:go_to_general_settings)
        Page::Group::Settings::General.perform do |general|
          general.choose_file_template_repository(file_template_project.name)
        end
      end

      def remove_group_file_template_if_set
        response = get Runtime::API::Request.new(api_client, "/groups/#{group.id}").url

        if parse_body(response)[:file_template_project_id]
          put Runtime::API::Request.new(api_client, "/groups/#{group.id}").url, { file_template_project_id: nil }
        end
      end
    end
  end
end
