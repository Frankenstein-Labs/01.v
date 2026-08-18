# frozen_string_literal: true

module API
  class GroupProtectedBranches < ::API::Base
    include PaginationParams

    BRANCH_ENDPOINT_REQUIREMENTS = ::API::NAMESPACE_OR_PROJECT_REQUIREMENTS.merge(name: ::API::NO_SLASH_URL_PART_REGEX)

    before { authorize_admin_group }

    feature_category :source_code_management

    helpers Helpers::ProtectedBranchesHelpers

    helpers do
      def protected_branch
        @protected_branch ||= user_group.protected_branches.by_name(params[:name]).first
      end

      def declared_params_without_missing
        declared_params(include_missing: false)
      end
    end

    params do
      requires :id, type: String, desc: 'The ID or URL-encoded path of a group'
    end
    resource :groups do
      desc 'List all protected branches' do
        detail 'Lists all protected branches from a group. If a wildcard is set, it is returned instead ' \
          'of the exact name of the branches that match that wildcard.'
        success code: 200, model: Entities::GroupProtectedBranch
        is_array true
        failure [
          { code: 404, message: '404 Group Not Found' },
          { code: 401, message: '401 Unauthorized' }
        ]
        tags ['protected_branches']
      end
      params do
        use :pagination
        optional :search, type: String, desc: 'Search for a protected branch by name', documentation: { example: 'mai' }
      end
      route_setting :authorization, permissions: :read_protected_branch, boundary_type: :group
      get ':id/protected_branches' do
        protected_branches =
          ProtectedBranchesFinder
            .new(user_group, params)
            .execute
            .preload_access_levels

        present paginate(protected_branches), with: Entities::GroupProtectedBranch
      end

      desc 'Retrieve a protected branch' do
        detail 'Retrieves a specified protected branch. Retrieve multiple branches by using a wildcard in the ' \
          '`name`.'
        success code: 200, model: Entities::GroupProtectedBranch
        failure [
          { code: 404, message: '404 Group Not Found' },
          { code: 404, message: '404 ProtectedBranch Not Found' },
          { code: 401, message: '401 Unauthorized' }
        ]
        tags ['protected_branches']
      end
      params do
        requires :name, type: String, desc: 'The name of the branch or wildcard', documentation: { example: 'main' }
      end
      route_setting :authorization, permissions: :read_protected_branch, boundary_type: :group
      get ':id/protected_branches/:name', requirements: BRANCH_ENDPOINT_REQUIREMENTS do
        not_found!("ProtectedBranch") unless protected_branch

        present protected_branch, with: Entities::GroupProtectedBranch
      end

      desc 'Protect a repository branch' do
        detail 'Protects a specified repository branch. Protect multiple branches by using a wildcard in the ' \
          '`name`.'
        success code: 201, model: Entities::GroupProtectedBranch
        failure [
          { code: 422, message: 'name is missing' },
          { code: 409, message: "Protected branch 'main' already exists" },
          { code: 404, message: '404 Group Not Found' },
          { code: 401, message: '401 Unauthorized' }
        ]
        tags ['protected_branches']
      end
      params do
        requires :name, type: String, desc: 'The name of the protected branch', documentation: { example: 'main' }
        # rubocop:disable API/AccessLevelStringType -- Introduced before the cop
        optional :push_access_level, type: Integer,
          values: ProtectedBranch::PushAccessLevel.allowed_access_levels,
          desc: 'Access levels allowed to push (defaults: `40`, maintainer access level)'
        optional :merge_access_level, type: Integer,
          values: ProtectedBranch::MergeAccessLevel.allowed_access_levels,
          desc: 'Access levels allowed to merge (defaults: `40`, maintainer access level)'
        # rubocop:enable API/AccessLevelStringType
        optional :allow_force_push, type: Boolean,
          default: false,
          desc: 'Allow force push for all users with push access.'

        use :optional_params_ee
      end
      route_setting :authorization, permissions: :create_protected_branch, boundary_type: :group
      post ':id/protected_branches' do
        conflict!("Protected branch '#{params[:name]}' already exists") if protected_branch

        api_service = ::ProtectedBranches::ApiService.new(user_group, current_user, declared_params_without_missing)
        created_protected_branch = api_service.create

        if created_protected_branch.persisted?
          present created_protected_branch, with: Entities::GroupProtectedBranch
        else
          render_api_error!(created_protected_branch.errors.full_messages, 422)
        end
      end

      desc 'Update a protected branch' do
        detail 'Updates a protected branch for a specified group.'
        success code: 200, model: Entities::GroupProtectedBranch
        failure [
          { code: 422, message: 'Push access levels access level has already been taken' },
          { code: 404, message: '404 Group Not Found' },
          { code: 404, message: '404 ProtectedBranch Not Found' },
          { code: 401, message: '401 Unauthorized' }
        ]
        tags ['protected_branches']
      end
      params do
        requires :name, type: String, desc: 'The name of the branch', documentation: { example: 'main' }
        optional :allow_force_push, type: Boolean,
          desc: 'Allow force push for all users with push access.'

        use :optional_params_ee
      end
      route_setting :authorization, permissions: :update_protected_branch, boundary_type: :group
      patch ':id/protected_branches/:name', requirements: BRANCH_ENDPOINT_REQUIREMENTS do
        not_found!("ProtectedBranch") unless protected_branch

        api_service = ::ProtectedBranches::ApiService.new(user_group, current_user, declared_params_without_missing)
        updated_protected_branch = api_service.update(protected_branch)

        if updated_protected_branch.valid?
          present updated_protected_branch, with: Entities::GroupProtectedBranch
        else
          render_api_error!(updated_protected_branch.errors.full_messages, 422)
        end
      end

      desc 'Unprotect repository branches' do
        detail 'Unprotects a specified protected branch Unprotect multiple branches by using a wildcard in the ' \
          '`name`.'
        success code: 204
        failure [
          { code: 404, message: '404 Group Not Found' },
          { code: 404, message: '404 ProtectedBranch Not Found' },
          { code: 401, message: '401 Unauthorized' }
        ]
        tags ['protected_branches']
      end
      params do
        requires :name, type: String, desc: 'The name of the protected branch', documentation: { example: 'main' }
      end
      route_setting :authorization, permissions: :delete_protected_branch, boundary_type: :group
      delete ':id/protected_branches/:name', requirements: BRANCH_ENDPOINT_REQUIREMENTS, urgency: :low do
        not_found!("ProtectedBranch") unless protected_branch

        destroy_service = ::ProtectedBranches::DestroyService.new(user_group, current_user)
        destroy_service.execute(protected_branch)

        present protected_branch, with: Entities::GroupProtectedBranch
      end
    end
  end
end
