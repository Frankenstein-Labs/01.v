# frozen_string_literal: true

module RemoteDevelopment
  class FixtureFileErbBinding
    include RemoteDevelopment::Files
    include RemoteDevelopment::RemoteDevelopmentConstants
    include RemoteDevelopment::WorkspaceOperations::WorkspaceOperationsConstants
    include RemoteDevelopment::WorkspaceOperations::Create::CreateConstants

    # @return [Binding]
    def get_fixture_file_binding
      binding
    end

    # @param [String] string
    # @param [Integer] indentation
    # @return [String]
    # Adds indentation to the beginning of all line in the string except the first.
    # This allows it to be used in a YAML literal block.
    #
    # Example usage:
    #
    # ```yaml
    # script:
    #   - |
    #     <%= indent_yaml_literal(multiline_script_string, 4) %>
    # ```
    def indent_yaml_literal(string, indentation)
      indent(string, indentation)[indentation..].to_s
    end

    # @param [String] string
    # @param [Integer] indentation
    # @return [String]
    # Adds indentation to the beginning of each line in the string.
    def indent(string, indentation)
      string.gsub(/^/, ' ' * indentation).to_s
    end
  end
end
