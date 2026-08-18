# frozen_string_literal: true

module EE
  module Import
    module GithubService
      include ::Gitlab::Utils::StrongMemoize
      extend ::Gitlab::Utils::Override

      override :extra_project_attrs
      def extra_project_attrs
        super.merge(ci_cd_only: params[:ci_cd_only])
      end

      override :validate_context
      def validate_context
        super || validate_over_repository_size_limit
      end

      def validate_over_repository_size_limit
        return unless over_repository_size_limit?

        error(oversize_error_message, :unprocessable_entity)
      end

      def repository_size_limit
        target_namespace.actual_repository_size_limit
      end
      strong_memoize_attr :repository_size_limit

      def over_repository_size_limit?
        repository_size_limit > 0 && repo[:size] > repository_size_limit
      end

      def oversize_error_message
        format(
          s_('GithubImport|"%{repository_name}" size (%{repository_size}) is larger than the limit of %{limit}.'),
          {
            repository_name: repo[:name],
            repository_size: number_to_human_size(repo[:size]),
            limit: number_to_human_size(repository_size_limit)
          }
        )
      end
    end
  end
end
