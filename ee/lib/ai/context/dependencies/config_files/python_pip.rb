# frozen_string_literal: true

module Ai
  module Context
    module Dependencies
      module ConfigFiles
        class PythonPip < Base
          OPTION_REGEX = /^-/
          NAME_VERSION_REGEX = /(?<name>^[^!=><~]+)(?<version>[!=><~]+.*$)?/
          EXTRAS_SPECIFIER_REGEX = /\[[\w,\-]*\]/ # Matches the extras specifier, e.g. lib-name[extra_1,extra-2]
          OTHER_SPECIFIERS_REGEX = /[@;]+.*$/ # Matches URL or other non-version specifiers at the end of line
          COMMENT_ONLY_REGEX = /^#/
          INLINE_COMMENT_REGEX = /\s+#.*$/

          # We support nested requirements files by processing all files matching
          # this glob. See https://gitlab.com/gitlab-org/gitlab/-/issues/491800.
          def self.file_name_glob
            '*requirements*.txt'
          end

          def self.lang_name
            'Python'
          end

          def self.supports_multiple_files?
            true
          end

          private

          ### Example format:
          #
          # requests>=2.0,<3.0      # Version range
          # numpy==1.26.4           # Exact version match
          # fastapi-health!=0.3.0   # Exclusion
          #
          # # New supported formats
          # pytest >= 2.6.4 ; python_version < '3.8'
          # openpyxl == 3.1.2
          # urllib3 @ https://github.com/path/main.zip
          #
          # # Options
          # -r other_requirements.txt # A nested requirements file
          # -i https://pypi.org/simple
          # --python-version 3
          #
          def extract_libs
            content.each_line.filter_map do |line|
              line.strip!
              next if line.blank? || Regexp.union(COMMENT_ONLY_REGEX, OPTION_REGEX).match?(line)

              parse_lib(line)
            end
          end

          def parse_lib(line)
            line.gsub!(Regexp.union(INLINE_COMMENT_REGEX, EXTRAS_SPECIFIER_REGEX, OTHER_SPECIFIERS_REGEX), '')
            match = NAME_VERSION_REGEX.match(line)

            Lib.new(name: match[:name], version: match[:version]) if match
          end
        end
      end
    end
  end
end
