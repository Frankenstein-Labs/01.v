# frozen_string_literal: true

module Security
  module ProjectTrackedContexts
    # FindOrCreateService encapsulates the logic to find or create `Security::ProjectTrackedContext` records.
    # If the tracked context does not exist, it will be created, but only if it's for the default branch.
    # Otherwise, it expects the context to already exist.
    class FindOrCreateService
      include Gitlab::Utils::StrongMemoize
      include LoggableCreation

      def self.from_pipeline(pipeline, allow_untracked: false)
        new(
          project: pipeline.project,
          context_name: pipeline.ref,
          context_type: pipeline.tag? ? :tag : :branch,
          is_default: pipeline.default_branch?,
          allow_untracked: allow_untracked
        )
      end

      def self.project_default_branch(project)
        new(
          project: project,
          context_name: project.default_branch_or_main,
          context_type: :branch,
          is_default: true
        )
      end

      def initialize(**params)
        @project = params[:project]
        @context_name = params[:context_name]
        @context_type = params[:context_type]
        @is_default = params[:is_default]
        @allow_untracked = params[:allow_untracked] || false
        @current_user = params[:current_user]
      end

      attr_reader :project, :context_name, :context_type, :is_default, :allow_untracked, :current_user

      def execute
        return permission_error unless can_manage_contexts?
        return validation_error unless valid_params?
        return ref_not_found_error if current_user && !ref_exists_in_repository?

        if existing_context.present?
          return success(existing_context) if existing_context.tracked? || allow_untracked

          return ServiceResponse.error(message: 'Context is not tracked')
        end

        return success(updated_default_branch_context) if update_default_branch_context?

        return cant_create_non_default_error unless is_default || allow_untracked

        create_context
      end

      private

      def can_manage_contexts?
        return true unless current_user

        Ability.allowed?(current_user, :create_security_project_tracked_ref, project)
      end

      def valid_params?
        context_name.present? &&
          context_type.present? &&
          %w[branch tag].include?(context_type.to_s)
      end

      def ref_exists_in_repository?
        return false unless project.repository_exists?

        case context_type.to_s
        when 'branch'
          project.repository.branch_exists?(context_name)
        when 'tag'
          project.repository.tag_exists?(context_name)
        else
          false
        end
      end

      def permission_error
        ServiceResponse.error(message: 'Permission denied')
      end

      def validation_error
        ServiceResponse.error(message: 'Invalid ref name or type specified')
      end

      def ref_not_found_error
        ServiceResponse.error(message: 'Ref does not exist in repository')
      end

      def existing_context
        Security::ProjectTrackedContext.for_project(project).for_context_name(context_name)
        .for_context_type(context_type).first
      end
      strong_memoize_attr :existing_context

      def create_context
        state = if !is_default && @allow_untracked
                  Security::ProjectTrackedContext::STATES[:untracked]
                else
                  Security::ProjectTrackedContext::STATES[:tracked]
                end

        tracked_context = Security::ProjectTrackedContext.create(
          project: project,
          context_name: context_name,
          context_type: context_type,
          is_default: is_default,
          state: state,
          uuid_version: Security::ProjectTrackedContext::CONTEXT_AWARE_UUID_VERSION
        )

        return error(tracked_context) unless tracked_context.persisted?

        log_created(tracked_context)

        success(tracked_context)
      end

      def success(tracked_context)
        ServiceResponse.success(payload: { tracked_context: tracked_context })
      end

      def error(tracked_context)
        ServiceResponse.error(message: tracked_context.errors.full_messages)
      end

      def cant_create_non_default_error
        ServiceResponse.error(message: 'Expected context to already exist for non-default branches')
      end

      def branch_context?
        context_type == :branch
      end

      def update_default_branch_context?
        branch_context? && is_default && existing_default_branch_context.present?
      end

      def existing_default_branch_context
        project.security_project_tracked_contexts
          .default_branch
          .last
      end
      strong_memoize_attr :existing_default_branch_context

      def updated_default_branch_context
        existing_default_branch_context.tap { |context| context.update!(context_name: project.default_branch) }
      end
    end
  end
end
