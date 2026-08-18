# frozen_string_literal: true

module DependencyManagement
  module SecurityUpdate
    # Parses the output.json artifact produced by the dependency management
    # orchestrator. Extracts only the fields needed to commit files and
    # create a merge request.
    #
    # See: https://gitlab.com/gitlab-org/security-products/dependency-management/orchestrator
    class OutputParser
      ParseError = Class.new(StandardError)

      DependencyChange = Struct.new(:name, :previous_version, :version, keyword_init: true)
      UpdatedFile = Struct.new(:path, :content, :encoding, keyword_init: true)
      Result = Struct.new(:dependencies, :updated_files, keyword_init: true)

      # @param raw_json [String] raw content of output.json
      # @return [Result]
      def self.parse(raw_json)
        data = Gitlab::Json.safe_parse(raw_json)
        raise ParseError, 'output.json must be a JSON object' unless data.is_a?(Hash)

        Result.new(
          dependencies: parse_dependencies(data),
          updated_files: parse_updated_files(data)
        )
      rescue JSON::ParserError => e
        raise ParseError, "Invalid JSON in output.json: #{e.message}"
      end

      def self.parse_dependencies(data)
        Array(data['dependency_updates']).filter_map do |dep|
          next unless dep.is_a?(Hash) && dep['name'].present?

          DependencyChange.new(
            name: dep['name'].to_s,
            previous_version: dep['previous_version'].to_s,
            version: dep['new_version'].to_s
          )
        end
      end

      def self.parse_updated_files(data)
        Array(data['updated_files']).filter_map do |file|
          next unless file.is_a?(Hash) && file['directory'].present? && file['name'].present?

          path = sanitize_path(file['directory'], file['name'])
          next unless path

          UpdatedFile.new(
            path: path,
            content: file['content'].to_s,
            encoding: 'text'
          )
        end
      end

      def self.sanitize_path(directory, name)
        # Reject name values that are absolute paths (e.g. "/etc/passwd")
        # to prevent Pathname#join from discarding the directory entirely.
        return if name.start_with?('/')

        # The directory from the dependency updater always starts with a leading "/"
        # (e.g. "/" or "/src"), indicating the project root.
        # Strip the leading "/" so Pathname doesn't interpret it as an absolute filesystem path.
        relative_dir = directory.delete_prefix('/')
        normalized = Pathname.new(relative_dir).join(name).cleanpath.to_s

        return if normalized.start_with?('/', '..')

        normalized
      end

      private_class_method :parse_dependencies, :parse_updated_files, :sanitize_path
    end
  end
end
