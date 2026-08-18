# frozen_string_literal: true

module API
  class ProjectMirror < ::API::Base
    feature_category :source_code_management

    helpers do
      def github_webhook_signature
        @github_webhook_signature ||= headers['X-Hub-Signature']
      end

      def render_invalid_github_signature!
        if ::Users::Anonymous.can?(:read_project, project)
          unauthorized!
        else
          not_found!
        end
      end

      def valid_github_signature?
        token = project.external_webhook_token.to_s
        # project.external_webhook_token should always exist when authenticating
        # via headers['X-Hub-Signature']. If it doesn't exist, this could be
        # an attempt to misuse.
        return false if token.empty?

        request.body.rewind
        payload_body = request.body.read
        signature    = 'sha1=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), token, payload_body)

        Rack::Utils.secure_compare(signature, github_webhook_signature)
      end

      def authenticate_with_webhook_token!
        return not_found! unless project

        return if valid_github_signature?

        render_invalid_github_signature!
      end

      def try_authenticate_with_webhook_token!
        if github_webhook_signature
          authenticate_with_webhook_token!
        else
          authenticate!
          authorize_admin_project
        end
      end

      def project
        @project ||= github_webhook_signature ? find_project(params[:id]) : user_project
      end

      def process_pull_request
        external_pull_request = ::Ci::ExternalPullRequests::ProcessGithubEventService.new(project, mirror_user).execute(params)

        if external_pull_request
          render_validation_error!(external_pull_request)
        else
          render_api_error!('The pull request event is not processable', 422)
        end
      end

      def start_pull_mirroring
        result = StartPullMirroringService
          .new(project, mirror_user, pause_on_hard_failure: !force_requested?)
          .execute

        render_api_error!(result[:message], result[:http_status]) if result[:status] == :error
      end

      def force_requested?
        params[:force].present? && github_webhook_signature.blank?
      end

      def mirror_user
        current_user || project.mirror_user
      end

      # Convert keys to make them compatible with PullMirror::UpdateService
      def pull_mirror_update_attributes(attrs)
        attrs
          .dup
          .transform_keys(enabled: :mirror)
          .transform_keys(url: :import_url)
          .then { |hash| extract_credentials!(hash) }
      end

      def extract_credentials!(attrs)
        credentials = { user: attrs.delete(:auth_user), password: attrs.delete(:auth_password) }.compact
        return attrs.merge(credentials: credentials) if credentials.present?

        attrs
      end
    end

    params do
      requires :id, types: [String, Integer], desc: 'The ID or URL-encoded path of the project'
    end
    resource :projects, requirements: ::API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
      desc 'Start the pull mirroring process for a project' do
        detail 'Starts the pull mirroring process for a specified project.'
        success code: 200
        failure [
          { code: 400, message: 'The project is not mirrored' },
          { code: 403, message: 'Mirroring for the project is on pause' },
          { code: 422, message: 'The pull request event is not processable' }
        ]
        tags ['project_mirrors']
      end
      params do
        optional :action, type: String, desc: 'Pull Request action'
        optional 'pull_request.number', type: Integer, desc: 'Pull request IID'
        optional 'pull_request.head.ref', type: String, desc: 'Source branch'
        optional 'pull_request.head.sha', type: String, desc: 'Source sha'
        optional 'pull_request.head.repo.full_name', type: String, desc: 'Source repository'
        optional 'pull_request.base.ref', type: String, desc: 'Target branch'
        optional 'pull_request.base.sha', type: String, desc: 'Target sha'
        optional 'pull_request.base.repo.full_name', type: String, desc: 'Target repository'
        optional :force, type: Grape::API::Boolean,
          desc: 'Reset the mirror if it is in a hard-failed state and retry the update'
      end
      route_setting :authorization, permissions: :create_pull_mirror, boundary_type: :project
      post ":id/mirror/pull" do
        try_authenticate_with_webhook_token!

        break render_api_error!('The project is not mirrored', 400) unless project.mirror?

        if params[:pull_request]
          process_pull_request
        else
          start_pull_mirroring
        end

        status 200
      end

      desc 'Update project pull mirroring settings' do
        detail 'Updates pull mirroring settings for a specified project. This feature was introduced in GitLab 17.5.'
        success code: 200, model: Entities::PullMirror
        failure [
          { code: 400, message: 'Url is blocked: Only allowed schemes are http, https, ssh, git' }
        ]
        tags ['project_mirrors']
      end
      params do
        optional :enabled, type: Grape::API::Boolean, desc: 'Enables pull mirroring in a project'
        optional :url, type: String, desc: 'URL of the project to pull mirror'
        optional :auth_user, type: String, desc: 'The username used for authentication of a project to pull mirror'
        optional :auth_password, type: String, desc: 'The password used for authentication of a project to pull mirror or a personal access token with the api scope enabled.'
        optional :mirror_trigger_builds, type: Grape::API::Boolean, desc: 'Pull mirroring triggers builds'
        optional :only_mirror_protected_branches, type: Grape::API::Boolean, desc: 'Only mirror protected branches'
        optional :mirror_overwrites_diverged_branches, type: Grape::API::Boolean, desc: 'Pull mirror overwrites diverged branches'
        optional :mirror_branch_regex, type: String, desc: 'Only mirror branches with names that match this regex'
        mutually_exclusive :only_protected_branches, :mirror_branch_regex
        at_least_one_of :enabled, :url, :auth_user, :auth_password, :mirror_overwrites_diverged_branches,
          :mirror_trigger_builds, :only_mirror_protected_branches, :mirror_branch_regex
      end
      route_setting :authorization, permissions: :update_pull_mirror, boundary_type: :project
      route_setting :lifecycle, :experiment
      put ':id/mirror/pull' do
        authenticate!
        authorize_admin_project

        pull_mirror_params = pull_mirror_update_attributes(declared_params(include_missing: false))

        result = ::Repositories::PullMirrors::UpdateService.new(
          project,
          current_user,
          pull_mirror_params
        ).execute

        render_api_error!(result.message, 400) if result.error?

        present result.payload[:project].import_state, with: Entities::PullMirror
      end

      desc 'Retrieve project pull mirror details' do
        detail 'Retrieves pull mirror details for a specified project.'
        success code: 200, model: Entities::PullMirror
        failure [
          { code: 400, message: 'The project is not mirrored' }
        ]
        tags ['project_mirrors']
      end
      route_setting :authorization, permissions: :read_pull_mirror, boundary_type: :project
      get ':id/mirror/pull' do
        authenticate!
        authorize_admin_project

        render_api_error!('The project is not mirrored', 400) unless project.mirror?

        present project.import_state, with: Entities::PullMirror
      end
    end
  end
end
