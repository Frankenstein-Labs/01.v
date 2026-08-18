# frozen_string_literal: true

module MergeRequests
  module Mergeability
    class CheckPathLocksService < CheckBaseService
      include ::Gitlab::Utils::StrongMemoize

      set_identifier :locked_paths
      set_failure_explanation N_('The files must not be locked by another user.')
      set_description 'Checks whether the merge request contains locked paths'

      CACHE_KEY = 'merge_request:%{id}:%{sha}:path_locks_mergeability:%{epoch}'

      def execute
        return inactive if check_inactive?
        return failure if contains_locked_paths?

        success
      end

      def skip?
        params[:skip_locked_paths_check].present?
      end

      def cacheable?
        true
      end

      def cache_key
        # If the feature is disabled we will return inactive so we don't need
        # to link the cache key to a specific MR.
        return 'inactive_path_locks_mergeability_check' if check_inactive?

        # Cache is linked to a specific MR
        id = merge_request.id
        # Cache is invalidated when new changes are added
        sha = merge_request.diff_head_sha
        # Cache is invalidated when path_locks are added or removed
        epoch = project.path_locks_changed_epoch

        format(CACHE_KEY, id: id, sha: sha, epoch: epoch)
      end

      private

      delegate :project, :changed_paths, :author_id, to: :merge_request

      def contains_locked_paths?
        return false unless project.path_locks.exists?

        paths = changed_paths.map(&:path).uniq
        project.path_locks.for_paths(paths).not_for_users(author_id).exists?
      end

      def check_inactive?
        return true unless project.licensed_feature_available?(:file_locks)

        merge_request.target_branch != project.default_branch
      end
      strong_memoize_attr :check_inactive?
    end
  end
end
