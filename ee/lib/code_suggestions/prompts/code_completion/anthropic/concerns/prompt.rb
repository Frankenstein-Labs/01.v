# frozen_string_literal: true

module CodeSuggestions
  module Prompts
    module CodeCompletion
      module Anthropic
        module Concerns
          module Prompt
            # although claude's prompt limit is much bigger, response time grows with prompt size,
            # so we don't attempt to use the whole size of prompt window
            MAX_INPUT_CHARS = 50000

            private

            def prompt
              [
                { role: :system, content: system_prompt },
                { role: :user, content: instructions }
              ]
            end

            def system_prompt
              <<~PROMPT.strip
                You are a code completion tool that performs Fill-in-the-middle. Your task is to complete the #{language.name} code between the given prefix and suffix inside the file '#{file_path_info}'.
                Your task is to provide valid code without any additional explanations, comments, or feedback.

                Important:
                - You MUST NOT output any additional human text or explanation.
                - You MUST output code exclusively.
                - The suggested code MUST work by simply concatenating to the provided code.
                - You MUST not include any sort of markdown markup.
                - You MUST NOT repeat or modify any part of the prefix or suffix.
                - You MUST only provide the missing code that fits between them.

                If you are not able to complete code based on the given instructions, return an empty result.
              PROMPT
            end

            def instructions
              return unless content_above_cursor.present?

              trimmed_content_above_cursor = content_above_cursor.to_s.last(MAX_INPUT_CHARS)
              max_remaining_chars = MAX_INPUT_CHARS - trimmed_content_above_cursor.size
              trimmed_content_below_cursor = content_below_cursor.to_s.first(max_remaining_chars)

              <<~INSTRUCTIONS.strip
                <SUFFIX>
                #{trimmed_content_above_cursor}
                </SUFFIX>
                <PREFIX>
                #{trimmed_content_below_cursor}
                </PREFIX>
              INSTRUCTIONS
            end
          end
        end
      end
    end
  end
end
