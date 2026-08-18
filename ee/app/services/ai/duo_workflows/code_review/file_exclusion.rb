# frozen_string_literal: true

module Ai
  module DuoWorkflows
    module CodeReview
      module FileExclusion
        include ::Gitlab::Utils::StrongMemoize
        include ::Ai::DuoWorkflows::CodeReview::Observability

        private

        def excluded_files
          file_paths = merge_request.diffs.diff_files.map(&:file_path)
          return [] if file_paths.empty?

          result = ::Ai::FileExclusionService.new(merge_request.project).execute(file_paths)
          return [] unless result.success?

          result.payload.filter_map { |file_result| file_result[:path] if file_result[:excluded] }
        end
        strong_memoize_attr :excluded_files

        def ai_reviewable_diff_files
          merge_request.ai_reviewable_diff_files.filter_map do |diff_file|
            diff_file unless excluded_files.include?(diff_file.file_path)
          end
        end
        strong_memoize_attr :ai_reviewable_diff_files

        def exclusion_message_for_excluded_files
          return "" if excluded_files.empty?

          track_review_merge_request_event('excluded_files_from_duo_code_review')

          context_exclusion_help_path = ::Gitlab::Utils.append_path(
            Gitlab::Routing.url_helpers.root_url,
            Gitlab::Routing.url_helpers.help_page_path('user/gitlab_duo/context.md',
              anchor: 'exclude-context-from-gitlab-duo')
          )

          <<~MESSAGE
               I do not have access to the following files due to an active context exclusion policy:
               #{excluded_files.map { |file| "* #{file}" }.join("\n")}
               [Learn more](#{context_exclusion_help_path})
          MESSAGE
        end
        strong_memoize_attr :exclusion_message_for_excluded_files
      end
    end
  end
end
