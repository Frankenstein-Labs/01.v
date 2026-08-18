# frozen_string_literal: true

module Resolvers
  module Vulnerabilities
    class ArchivesResolver < VulnerabilitiesBaseResolver
      include Gitlab::Graphql::Authorize::AuthorizeResource

      type [::Types::Vulnerabilities::ArchiveType], null: true

      authorize :read_security_resource
      authorizes_object!

      def resolve
        ensure_feature_available!

        object.vulnerability_archives
      end

      private

      def ensure_feature_available!
        raise_resource_not_available_error! unless object.vulnerability_archival_enabled?
      end
    end
  end
end
