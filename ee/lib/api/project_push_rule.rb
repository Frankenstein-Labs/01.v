# frozen_string_literal: true

module API
  class ProjectPushRule < ::API::Base
    feature_category :source_code_management
    before { authenticate! }
    before { authorize! :admin_push_rules, user_project }
    before { check_project_feature_available!(:push_rules) }
    before { authorize_change_param(user_project, :commit_committer_check, :commit_committer_name_check, :reject_unsigned_commits, :reject_non_dco_commits) }

    helpers do
      def create_or_update_push_rule
        service_response = PushRules::CreateOrUpdateService.new(
          container: user_project,
          current_user: current_user,
          params: declared_params(include_missing: false)
        ).execute

        push_rule = service_response.payload[:push_rule]

        if service_response.success?
          present(push_rule, with: ::API::Entities::ProjectPushRule, user: current_user)
        else
          render_validation_error!(push_rule)
        end
      end
    end

    params do
      requires :id, types: [String, Integer], desc: 'The ID or URL-encoded path of the project'
    end
    resource :projects, requirements: ::API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
      helpers do
        params :push_rule_params do
          optional :deny_delete_tag, type: Boolean, desc: 'Deny deleting a tag', documentation: { example: true }
          optional :member_check, type: Boolean, desc: 'Restrict commits by author (email) to existing GitLab users', documentation: { example: true }
          optional :prevent_secrets, type: Boolean, desc: 'GitLab will reject any files that are likely to contain secrets', documentation: { example: true }
          optional :commit_message_regex, type: String, desc: 'All commit messages must match this', documentation: { example: 'Fixed \d+\..*' }
          optional :commit_message_negative_regex, type: String, desc: 'No commit message is allowed to match this', documentation: { example: 'ssh\:\/\/' }
          optional :branch_name_regex, type: String, desc: 'All branches names must match this', documentation: { example: '(feature|hotfix)\/.*' }
          optional :author_email_regex, type: String, desc: 'All commit author emails must match this', documentation: { example: '@my-company.com$' }
          optional :file_name_regex, type: String, desc: 'All committed filenames must not match this', documentation: { example: '(jar|exe)$' }
          optional :max_file_size, type: Integer, desc: 'Maximum file size (MB)', documentation: { example: 1024 }
          optional :commit_committer_check,
            type: Boolean,
            desc: 'Users can only push commits to this repository if the committer email is one of their own verified emails.',
            documentation: { example: true }
          optional :commit_committer_name_check,
            type: Boolean,
            desc: 'Users can only push commits to this repository if the commit author name is consistent with their GitLab account name.',
            documentation: { example: true }
          optional :reject_unsigned_commits, type: Boolean, desc: 'Reject commit when it’s not signed.', documentation: { example: true }
          optional :reject_non_dco_commits, type: Boolean, desc: 'Reject commit when it’s not DCO certified.', documentation: { example: true }
          at_least_one_of :deny_delete_tag, :member_check, :prevent_secrets,
            :commit_message_regex, :commit_message_negative_regex, :branch_name_regex, :author_email_regex,
            :file_name_regex, :max_file_size,
            :commit_committer_check, :commit_committer_name_check,
            :reject_unsigned_commits, :reject_non_dco_commits
        end
      end

      desc 'Retrieve the push rules of a project' do
        detail 'Retrieves the push rules of a specified project.'
        success code: 200, model: ::API::Entities::ProjectPushRule
        failure [{ code: 404, message: 'Not found' }]
        tags %w[push_rules]
      end
      route_setting :authorization, permissions: :read_push_rule, boundary_type: :project
      get ":id/push_rule" do
        push_rule = user_project.push_rule
        present push_rule, with: ::API::Entities::ProjectPushRule, user: current_user
      end

      desc 'Add push rules to a project' do
        detail 'Adds push rules to a specified project.'
        success code: 201, model: ::API::Entities::ProjectPushRule
        failure [
          { code: 400, message: 'Validation error' },
          { code: 404, message: 'Not found' },
          { code: 422, message: 'Unprocessable entity' }
        ]
        tags %w[push_rules]
      end
      params do
        use :push_rule_params
      end
      route_setting :authorization, permissions: :create_push_rule, boundary_type: :project
      post ":id/push_rule" do
        unprocessable_entity!('Project push rule exists') if user_project.push_rule
        create_or_update_push_rule
      end

      desc 'Update push rules of a project' do
        detail 'Updates the push rules for a specified project.'
        success code: 200, model: ::API::Entities::ProjectPushRule
        failure [
          { code: 400, message: 'Validation error' },
          { code: 404, message: 'Not found' },
          { code: 422, message: 'Unprocessable entity' }
        ]
        tags %w[push_rules]
      end
      params do
        use :push_rule_params
      end
      route_setting :authorization, permissions: :update_push_rule, boundary_type: :project
      put ":id/push_rule" do
        not_found!('Push rule') unless user_project.push_rule
        create_or_update_push_rule
      end

      desc 'Delete the push rules of a project' do
        detail 'Deletes all the push rules of a specified project.'
        success code: 204
        failure [{ code: 404, message: 'Not found' }]
        tags %w[push_rules]
      end
      route_setting :authorization, permissions: :delete_push_rule, boundary_type: :project
      delete ":id/push_rule" do
        push_rule = user_project.push_rule
        not_found!('Push rule') unless push_rule

        push_rule.destroy

        no_content!
      end
    end
  end
end
