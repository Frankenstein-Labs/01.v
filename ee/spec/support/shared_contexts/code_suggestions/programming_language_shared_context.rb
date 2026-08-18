# frozen_string_literal: true

RSpec.shared_context 'with comment contents_above_cursor' do
  # Builds a hash with items: { [array of programming languages] => [array of comment contents_above_cursor] }
  # for example:
  # {
  #   ["Clojure", "Lisp", "Scheme"]=>[";"],
  #   ["SQL", "Haskell", "Lean"]=>["--"],
  #   ["VBScript"]=>["'", "REM"],
  #   ...
  # }
  # The reason is that LANGUAGE_COMMENT_FORMATS defines either simple string comment contents_above_cursor or
  # regexps which match multiple content_above_cursor options. If simple string is used, we can just reuse it,
  # if regexp is used, we need to add all matching options here.
  def self.single_line_comment_contents_above_cursor
    CodeSuggestions::ProgrammingLanguage::LANGUAGE_COMMENT_FORMATS
      .transform_values { |format| Array.wrap(format[:single]) if format[:single] }
      .compact
      .merge({
        %w[VBScript] => ["'", 'REM']
      })
  end

  def self.languages_missing_single_line_comments
    %w[OCaml]
  end

  def self.languages_with_single_line_comment_content_above_cursor
    all_contents_above_cursor = single_line_comment_contents_above_cursor

    CodeSuggestions::ProgrammingLanguage::SUPPORTED_LANGUAGES.keys.each_with_object([]) do |lang, tuples|
      next if languages_missing_single_line_comments.include?(lang)

      contents_above_cursor = all_contents_above_cursor.find { |langs, _| langs.include?(lang) }&.last
      if contents_above_cursor.blank?
        raise "#{lang} has missing single line comment content_above_cursor, " \
          "if it's a simple string match, add it to LANGUAGE_COMMENT_FORMATS, " \
          "if it's a regexp, add all regexp possibilities to " \
          "single_line_comment_content_above_cursor"
      end

      contents_above_cursor.each { |content_above_cursor| tuples << [lang, content_above_cursor] }
    end
  end
end
