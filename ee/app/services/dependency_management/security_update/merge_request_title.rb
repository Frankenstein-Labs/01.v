# frozen_string_literal: true

module DependencyManagement
  module SecurityUpdate
    module MergeRequestTitle
      # Grouped titles ("Security: Update N dependencies") intentionally don't match:
      # version-aware dismissal for grouped updates is out of scope for now.
      SINGLE_DEPENDENCY_REGEX = /\ASecurity: Update (?<name>.+) from \S+ to (?<version>\S+)\z/

      def self.build(dependencies)
        if dependencies.size == 1
          dep = dependencies.first
          "Security: Update #{dep.name} from #{dep.previous_version} to #{dep.version}"
        else
          "Security: Update #{dependencies.size} dependencies"
        end
      end

      def self.parse_single_dependency(title)
        SINGLE_DEPENDENCY_REGEX.match(title)
      end
    end
  end
end
