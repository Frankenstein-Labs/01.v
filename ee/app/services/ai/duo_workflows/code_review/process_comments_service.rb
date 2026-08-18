# frozen_string_literal: true

module Ai
  module DuoWorkflows
    module CodeReview
      class ProcessCommentsService
        include ::Gitlab::Utils::StrongMemoize
        include ::Ai::DuoWorkflows::CodeReview::FileExclusion

        DRAFT_NOTES_COUNT_LIMIT = 50
        LINE_MATCH_THRESHOLD = 3
        CUSTOM_INSTRUCTIONS_REGEXP = /^According to custom instructions in .+?:/

        class Metrics
          attr_accessor :comments_with_valid_path,
            :comments_with_valid_line,
            :comments_with_custom_instructions,
            :comments_line_matched_by_content,
            :draft_notes_created,
            :total_comments

          def initialize
            @comments_with_valid_path = 0
            @comments_with_valid_line = 0
            @comments_with_custom_instructions = 0
            @comments_line_matched_by_content = 0
            @draft_notes_created = 0
            @total_comments = 0
          end
        end

        def initialize(user:, merge_request:, review_bot:, review_output:)
          @user = user
          @merge_request = merge_request
          @review_bot = review_bot
          @review_output = review_output
          @metrics = Metrics.new
        end

        def execute
          draft_notes = build_draft_notes

          message =
            if draft_notes.empty?
              track_review_merge_request_event('find_no_issues_duo_code_review_after_review')
              build_no_comments_message
            else
              build_summary
            end

          ServiceResponse.success(
            message: message,
            payload: {
              metrics: metrics,
              draft_notes: draft_notes
            }
          )
        end

        private

        attr_reader :user, :merge_request, :review_bot, :review_output, :metrics

        def parsed_body
          @parsed_body ||=
            ::Gitlab::Llm::AiGateway::Completions::ReviewMergeRequest::ResponseBodyParser.new(review_output)
        end

        def build_no_comments_message
          comments_summary = parsed_body.comments_summary

          if comments_summary.present?
            exclusion_message_for_excluded_files +
              ::Gitlab::Duo::CodeReview::Messages.comments_not_posted_message(comments_summary)
          else
            no_issues_summary = parsed_body.no_issues_summary
            base_message = exclusion_message_for_excluded_files + ::Gitlab::Duo::CodeReview::Messages.nothing_to_comment
            return base_message if no_issues_summary.blank?

            "#{base_message}\n\n#{no_issues_summary}"
          end
        end

        def build_draft_notes
          mr_diff_refs = merge_request.diff_refs

          raw_comments = parsed_body.comments
          comments = raw_comments.group_by(&:file)

          metrics.total_comments = raw_comments.count

          draft_notes = ai_reviewable_diff_files.each_with_object([]) do |diff_file, notes|
            file_comments = comments[diff_file.new_path]

            next if file_comments.blank?

            metrics.comments_with_valid_path += file_comments.count

            notes.concat(process_comments(file_comments, diff_file, mr_diff_refs))
          end.first(DRAFT_NOTES_COUNT_LIMIT)

          metrics.draft_notes_created = draft_notes.count

          draft_notes
        end

        def process_comments(comments, diff_file, diff_refs)
          comments.each_with_object([]) do |comment, draft_notes|
            diff_line = match_comment_to_diff_line(comment, diff_file.diff_lines)

            next if diff_line.blank?

            metrics.comments_with_valid_line += 1
            metrics.comments_with_custom_instructions += 1 if comment.content&.match?(CUSTOM_INSTRUCTIONS_REGEXP)

            draft_note_instance = build_draft_note_instance(comment.content, diff_file, diff_line, diff_refs)
            draft_notes << draft_note_instance if draft_note_instance
          end
        end

        def build_draft_note_instance(comment, diff_file, line, diff_refs)
          position = {
            base_sha: diff_refs.base_sha,
            start_sha: diff_refs.start_sha,
            head_sha: diff_refs.head_sha,
            old_path: diff_file.old_path,
            new_path: diff_file.new_path,
            position_type: 'text',
            old_line: line.old_line,
            new_line: line.new_line,
            ignore_whitespace_change: false
          }

          return if review_note_already_exists?(position)

          DraftNote.new(
            merge_request: merge_request,
            author: review_bot,
            note: comment,
            position: position
          )
        end

        def match_comment_to_diff_line(comment, diff_lines)
          diff_line = find_line_by_line_numbers(comment, diff_lines)
          from_lines = comment.from&.lines(chomp: true)

          # We only want to match if we have enough context
          if from_lines.present? && from_lines.count >= LINE_MATCH_THRESHOLD
            # We can skip the full search if the diff_line already matches the first context line
            return diff_line if diff_line&.text(prefix: false) == from_lines.first

            return find_line_by_content(from_lines, diff_lines) || diff_line
          end

          diff_line
        end

        def find_line_by_content(from_lines, diff_lines)
          # We need to ignore removed lines as the match needs to be consecutive lines.
          # Also, removed line cannot have code suggestions so we don't want to match it to removed lines.
          actual_diff_lines = diff_lines.reject(&:removed?)
          found_line = nil

          # We look for the matching lines by iterating through diff_lines and comparing entire sequences of lines
          # from <from> lines.
          actual_diff_lines.each_with_index do |start_line, start_index|
            # If we don't have enough lines left to match, we should skip the rest of the lines and exit early.
            break if start_index + from_lines.count > actual_diff_lines.count
            next unless start_line.text(prefix: false) == from_lines.first

            # Try to match the entire sequence
            sequence_matches = true

            from_lines.each_with_index do |from_line, from_index|
              actual_line = actual_diff_lines[start_index + from_index]

              # If any line doesn't match, the sequence fails
              unless actual_line.text(prefix: false) == from_line
                sequence_matches = false
                break
              end
            end

            next unless sequence_matches

            # If we found a matching sequence
            metrics.comments_line_matched_by_content += 1
            found_line = start_line
            break
          end

          # Return the found line or nil if no match
          found_line
        end

        def find_line_by_line_numbers(comment, diff_lines)
          # NOTE: LLM may return invalid line numbers sometimes so we should double check the existence of the line.
          #   Also, LLM sometimes sets old_line to the same value as new_line when it should be empty
          #   for some unknown reason. We should fallback to new_line to find a match as much as possible.

          # First try to match both old_line and new_line for precision
          exact_match = diff_lines.find do |line|
            line.old_line == comment.old_line && line.new_line == comment.new_line
          end

          return exact_match if exact_match

          # Fall back to matching only new_line
          diff_lines.find { |line| comment.new_line.present? && line.new_line == comment.new_line }
        end

        def review_note_already_exists?(position)
          existing_review_note_positions.any?(position)
        end

        def existing_review_note_positions
          merge_request
            .notes
            .diff_notes
            .authored_by(review_bot)
            .positions
            .map(&:to_h)
        end
        strong_memoize_attr :existing_review_note_positions

        def build_summary
          comments_summary = parsed_body.comments_summary

          if comments_summary.blank?
            track_review_merge_request_event('encounter_duo_code_review_error_during_review')
            ::Gitlab::Duo::CodeReview::Messages.could_not_generate_summary_error
          else
            exclusion_message_for_excluded_files + comments_summary
          end
        end
      end
    end
  end
end
