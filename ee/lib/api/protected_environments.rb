# frozen_string_literal: true

module API
  class ProtectedEnvironments < ::API::Base
    include PaginationParams

    protected_environments_tags = %w[protected_environments]
    ENVIRONMENT_ENDPOINT_REQUIREMENTS = ::API::NAMESPACE_OR_PROJECT_REQUIREMENTS.merge(name: ::API::NO_SLASH_URL_PART_REGEX)

    feature_category :continuous_delivery
    urgency :low

    helpers do
      def has_deprecated_approval_rules_params?
        params[:required_approval_count].present? && params[:required_approval_count] > 0
      end

      params :shared_params do
        optional :user_id, type: Integer, desc: 'The ID of a user with access to the project'
        optional :group_id, type: Integer, desc: 'The ID of a group with access to the project'
        optional :group_inheritance_type,
          type: Integer,
          values: ::ProtectedEnvironments::Authorizable::GROUP_INHERITANCE_TYPE.values,
          desc: 'Specify whether to take inherited group membership into account. Use `0` for direct ' \
                'group membership or `1` for all inherited groups. Default is `0`'
      end

      params :shared_update_params do
        optional :id, type: Integer, desc: 'The ID of the approval rule to update'
        optional :_destroy, type: Boolean, desc: 'Deletes the object when true'
      end

      params :deploy_access_levels do
        requires :deploy_access_levels,
          as: :deploy_access_levels_attributes,
          type: Array,
          desc: 'Array of access levels allowed to deploy, with each described by a hash. One of ' \
                '`user_id`, `group_id` or `access_level`. They take the form of `{user_id: integer}`, ' \
                '`{group_id: integer}` or `{access_level: integer}` respectively.' do
          use :shared_params

          # rubocop:disable API/AccessLevelStringType -- Introduced before the cop
          optional :access_level,
            type: Integer,
            values: ::ProtectedEnvironments::DeployAccessLevel::ALLOWED_ACCESS_LEVELS,
            desc: 'The access levels allowed to deploy'
          # rubocop:enable API/AccessLevelStringType
        end
      end

      params :optional_approval_rules do
        optional :approval_rules,
          as: :approval_rules_attributes,
          type: Array,
          desc: 'Array of access levels allowed to approve, with each described by a hash. One of ' \
                '`user_id`, `group_id` or `access_level`. They take the form of `{user_id: integer}`, ' \
                '`{group_id: integer}` or `{access_level: integer}` respectively. You can also specify the ' \
                'number of required approvals from the specified entity with `required_approvals` field.' do
          use :shared_params
          use :shared_update_params

          # rubocop:disable API/AccessLevelStringType -- Introduced before the cop
          optional :access_level,
            type: Integer,
            values: ::ProtectedEnvironments::ApprovalRule::ALLOWED_ACCESS_LEVELS,
            desc: 'The access levels allowed to approve'
          # rubocop:enable API/AccessLevelStringType

          optional :required_approvals,
            type: Integer,
            default: 1,
            desc: 'The number of approvals required for this rule'

          given _destroy: ->(value) { value != true } do
            at_least_one_of :access_level, :user_id, :group_id
          end
        end
      end

      params :optional_deploy_access_levels do
        optional :deploy_access_levels, as: :deploy_access_levels_attributes, type: Array, desc: 'An array of users/groups allowed to deploy environment' do
          use :shared_params
          use :shared_update_params

          # rubocop:disable API/AccessLevelStringType -- Introduced before the cop
          optional :access_level,
            type: Integer,
            values: ::ProtectedEnvironments::DeployAccessLevel::ALLOWED_ACCESS_LEVELS,
            desc: 'The access levels allowed to deploy'
          # rubocop:enable API/AccessLevelStringType
        end
      end
    end

    params do
      requires :id, types: [String, Integer], desc: 'The ID or URL-encoded path of the project owned by the authenticated user'
    end

    resource :projects, requirements: ::API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
      helpers do
        def protected_environment
          @protected_environment ||= user_project.protected_environments.find_by_name!(params[:name])
        end
      end

      before { authorize! :admin_protected_environments, user_project }

      desc 'List all protected environments for a project' do
        detail 'Lists all protected environments for a specified project.'
        success ::API::Entities::ProtectedEnvironment
        failure [
          { code: '404', message: 'Not found' }
        ]
        is_array true
        tags protected_environments_tags
      end
      params do
        use :pagination
      end
      route_setting :authorization, permissions: :read_protected_environment, boundary_type: :project
      get ':id/protected_environments' do
        protected_environments = user_project.protected_environments.sorted_by_name

        present paginate(protected_environments), with: ::API::Entities::ProtectedEnvironment, project: user_project
      end

      desc 'Retrieve a protected environment for a project' do
        detail 'Retrieves a specified protected environment for a project.'
        success ::API::Entities::ProtectedEnvironment
        failure [
          { code: '404', message: 'Not found' }
        ]
        tags protected_environments_tags
      end
      params do
        requires :name, type: String, desc: 'The name of the protected environment'
      end
      route_setting :authorization, permissions: :read_protected_environment, boundary_type: :project
      get ':id/protected_environments/:name', requirements: ENVIRONMENT_ENDPOINT_REQUIREMENTS do
        present protected_environment, with: ::API::Entities::ProtectedEnvironment, project: user_project
      end

      desc 'Protect an environment for a project' do
        detail 'Protects a specified environment for a project.'
        success ::API::Entities::ProtectedEnvironment
        failure [
          { code: '409', message: 'Conflict' },
          { code: '404', message: 'Not found' },
          { code: '422', message: 'Unprocessable entity' }
        ]
        tags protected_environments_tags
      end
      params do
        requires :name, type: String, desc: 'The name of the environment'
        optional :required_approval_count, type: Integer, desc: '[DEPRECATED] The number of approvals required to deploy to this environment', default: 0

        use :deploy_access_levels
        use :optional_approval_rules
      end
      route_setting :authorization, permissions: :create_protected_environment, boundary_type: :project
      post ':id/protected_environments' do
        if has_deprecated_approval_rules_params?
          unprocessable_entity!(s_("ProtectedEnvironment|Parameter 'required_approval_count' is deprecated and shouldn't be used. See https://gitlab.com/groups/gitlab-org/-/epics/9662"))
        end

        protected_environment = user_project.protected_environments.find_by_name(params[:name])

        if protected_environment
          conflict!(format(s_("ProtectedEnvironment|Environment '%{environment_name}' is already protected"), environment_name: params[:name]))
        end

        declared_params = declared_params(include_missing: false)
        protected_environment = ::ProtectedEnvironments::CreateService
                                  .new(container: user_project, current_user: current_user, params: declared_params).execute

        if protected_environment.persisted?
          present protected_environment, with: ::API::Entities::ProtectedEnvironment, project: user_project
        else
          render_api_error!(protected_environment.errors.full_messages, 422)
        end
      end

      desc 'Update a protected environment for a project' do
        detail 'Updates a specified protected environment for a project.'
        success ::API::Entities::ProtectedEnvironment
        failure [
          { code: '404', message: 'Not found' },
          { code: '422', message: 'Unprocessable entity' }
        ]
        tags protected_environments_tags
      end
      params do
        requires :name, type: String, desc: 'The name of the environment'
        optional :required_approval_count, type: Integer, desc: '[DEPRECATED] The number of approvals required to deploy to this environment'

        use :optional_deploy_access_levels
        use :optional_approval_rules
      end
      route_setting :authorization, permissions: :update_protected_environment, boundary_type: :project
      put ':id/protected_environments/:name', requirements: ENVIRONMENT_ENDPOINT_REQUIREMENTS do
        not_found! unless protected_environment

        if has_deprecated_approval_rules_params?
          unprocessable_entity!(s_("ProtectedEnvironment|Parameter 'required_approval_count' is deprecated and shouldn't be used. See https://gitlab.com/groups/gitlab-org/-/epics/9662"))
        end

        declared_params = declared_params(include_missing: false)

        result = ::ProtectedEnvironments::UpdateService
                   .new(container: user_project, current_user: current_user, params: declared_params)
                   .execute(protected_environment)

        if result
          present protected_environment, with: ::API::Entities::ProtectedEnvironment, project: user_project
        else
          render_api_error!(protected_environment.errors.full_messages, 422)
        end
      end

      desc 'Unprotect a protected environment for a project' do
        detail 'Unprotects a specified protected environment for a project.'
        success code: 204, message: 'Resource deleted'
        tags protected_environments_tags
      end
      params do
        requires :name, type: String, desc: 'The name of the protected environment'
      end
      route_setting :authorization, permissions: :delete_protected_environment, boundary_type: :project
      delete ':id/protected_environments/:name', requirements: ENVIRONMENT_ENDPOINT_REQUIREMENTS do
        destroy_conditionally!(protected_environment) do
          ::ProtectedEnvironments::DestroyService.new(container: user_project, current_user: current_user).execute(protected_environment)
        end
      end
    end

    params do
      requires :id, types: [String, Integer], desc: 'The ID or URL-encoded path of the group maintained by the authenticated user'
    end
    resource :groups, requirements: ::API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
      helpers do
        def protected_environment
          @protected_environment ||= user_group.protected_environments.find_by_name!(params[:name])
        end
      end

      before do
        authorize! :admin_protected_environments, user_group
      end

      desc 'List all protected environments for a group' do
        detail 'Lists all protected environments for a specified group.'
        success ::API::Entities::ProtectedEnvironment
        failure [
          { code: '404', message: 'Not found' }
        ]
        is_array true
        tags protected_environments_tags
      end
      params do
        use :pagination
      end
      route_setting :authorization, permissions: :read_protected_environment, boundary_type: :group
      get ':id/protected_environments' do
        protected_environments = user_group.protected_environments.sorted_by_name

        present paginate(protected_environments), with: ::API::Entities::ProtectedEnvironment
      end

      desc 'Retrieve a protected environment for a group' do
        detail 'Retrieves a specified protected environment for a group.'
        success ::API::Entities::ProtectedEnvironment
        failure [
          { code: '404', message: 'Not found' }
        ]
        tags protected_environments_tags
      end
      params do
        requires :name,
          type: String,
          desc: 'The deployment tier of the protected environment. ' \
                'One of `production`, `staging`, `testing`, `development`, or `other`'
      end
      route_setting :authorization, permissions: :read_protected_environment, boundary_type: :group
      get ':id/protected_environments/:name' do
        present protected_environment, with: ::API::Entities::ProtectedEnvironment
      end

      desc 'Protect an environment for a group' do
        detail 'Protects a specified environment for a group.'
        success ::API::Entities::ProtectedEnvironment
        failure [
          { code: '409', message: 'Conflict' },
          { code: '404', message: 'Not found' },
          { code: '422', message: 'Unprocessable entity' }
        ]
        tags protected_environments_tags
      end
      params do
        requires :name,
          type: String,
          desc: 'The deployment tier of the protected environment. ' \
                'One of `production`, `staging`, `testing`, `development`, or `other`'

        optional :required_approval_count,
          type: Integer,
          desc: '[DEPRECATED] The number of approvals required to deploy to this environment',
          default: 0

        use :deploy_access_levels
        use :optional_approval_rules
      end
      route_setting :authorization, permissions: :create_protected_environment, boundary_type: :group
      post ':id/protected_environments' do
        if has_deprecated_approval_rules_params?
          unprocessable_entity!(s_("ProtectedEnvironment|Parameter 'required_approval_count' is deprecated and shouldn't be used. See https://gitlab.com/groups/gitlab-org/-/epics/9662"))
        end

        protected_environment = user_group.protected_environments.find_by_name(params[:name])

        if protected_environment
          conflict!("Protected environment '#{params[:name]}' already exists")
        end

        declared_params = declared_params(include_missing: false)
        protected_environment = ::ProtectedEnvironments::CreateService
                                  .new(container: user_group, current_user: current_user, params: declared_params).execute

        if protected_environment.persisted?
          present protected_environment, with: ::API::Entities::ProtectedEnvironment
        else
          render_api_error!(protected_environment.errors.full_messages, 422)
        end
      end

      desc 'Update a protected environment for a group' do
        detail 'Updates a specified protected environment for a group.'
        success ::API::Entities::ProtectedEnvironment
        failure [
          { code: '404', message: 'Not found' },
          { code: '422', message: 'Unprocessable entity' }
        ]
        tags protected_environments_tags
      end
      params do
        requires :name,
          type: String,
          desc: 'The deployment tier of the protected environment. ' \
                'One of production, staging, testing, development, or other'

        optional :required_approval_count,
          type: Integer,
          desc: '[DEPRECATED] The number of approvals required to deploy to this environment',
          default: 0

        use :optional_deploy_access_levels
        use :optional_approval_rules
      end
      route_setting :authorization, permissions: :update_protected_environment, boundary_type: :group
      put ':id/protected_environments/:name' do
        not_found! unless protected_environment

        if has_deprecated_approval_rules_params?
          unprocessable_entity!(s_("ProtectedEnvironment|Parameter 'required_approval_count' is deprecated and shouldn't be used. See https://gitlab.com/groups/gitlab-org/-/epics/9662"))
        end

        declared_params = declared_params(include_missing: false)

        result = ::ProtectedEnvironments::UpdateService
                   .new(container: user_group, current_user: current_user, params: declared_params)
                   .execute(protected_environment)

        if result
          present protected_environment, with: ::API::Entities::ProtectedEnvironment, project: user_group
        else
          render_api_error!(protected_environment.errors.full_messages, 422)
        end
      end

      desc 'Unprotect a group environment' do
        detail 'Unprotects a specified protected environment for a group.'
        success code: 204, message: 'Resource deleted'
        tags protected_environments_tags
      end
      params do
        requires :name, type: String, desc: 'The tier name of the protected environment'
      end
      route_setting :authorization, permissions: :delete_protected_environment, boundary_type: :group
      delete ':id/protected_environments/:name' do
        destroy_conditionally!(protected_environment) do
          ::ProtectedEnvironments::DestroyService.new(container: user_group, current_user: current_user).execute(protected_environment)
        end
      end
    end
  end
end
