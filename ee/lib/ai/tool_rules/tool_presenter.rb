# frozen_string_literal: true

module Ai
  module ToolRules
    module ToolPresenter
      ACRONYMS = %w[CI ASCP GitLab GLQL SAST FP MCP GraphQL].freeze

      DISPLAY_NAME_OVERRIDES = {
        'gitlab__user_search' => 'GitLab User Search',
        'post_sast_fp_analysis_to_gitlab' => 'Post SAST False Positive Analysis to GitLab',
        'post_secret_fp_analysis_to_gitlab' => 'Post Secret False Positive Analysis to GitLab'
      }.freeze

      def self.display_name_for(tool_name)
        DISPLAY_NAME_OVERRIDES.fetch(tool_name) do
          tool_name.split('_').map do |word|
            ACRONYMS.find { |a| a.downcase == word } || word.capitalize
          end.join(' ')
        end
      end
    end
  end
end
