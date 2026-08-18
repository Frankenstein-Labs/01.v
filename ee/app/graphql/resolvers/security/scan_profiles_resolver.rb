# frozen_string_literal: true

module Resolvers
  module Security
    class ScanProfilesResolver < BaseResolver
      include Gitlab::Graphql::Authorize::AuthorizeResource

      type [Types::Security::ScanProfileType], null: false
      authorize :read_security_scan_profiles
      description 'Available security scan profiles.'

      argument :type, Types::Security::ScanProfileTypeEnum,
        required: false,
        description: 'Filter scan profiles by type.'

      argument :gitlab_recommended, GraphQL::Types::Boolean,
        required: false,
        description: 'Filter scan profiles by GitLab Recommended.'

      alias_method :group, :object

      def resolve(type: nil, gitlab_recommended: nil)
        authorize!(object)

        existing_profiles = fetch_existing_profiles(type, gitlab_recommended)
        applicable_defaults = fetch_applicable_defaults(type, existing_profiles, gitlab_recommended)

        existing_profiles + applicable_defaults
      end

      private

      def root_ancestor
        @root_ancestor ||= group.root_ancestor
      end

      def fetch_existing_profiles(type, gitlab_recommended)
        # Eager-load trigger configurations to avoid N+1s when resolving ScanProfileType#configuration.
        profiles = ::Security::ScanProfile.not_deleted.by_namespace(root_ancestor).with_trigger_configurations
        profiles = filter_by_type(profiles, type)
        filter_by_gitlab_recommended(profiles, gitlab_recommended)
      end

      def filter_by_type(profiles, type)
        return profiles if type.blank?

        profiles.by_type(type)
      end

      def filter_by_gitlab_recommended(profiles, gitlab_recommended)
        return profiles if gitlab_recommended.nil?

        profiles.by_gitlab_recommended(gitlab_recommended)
      end

      def fetch_applicable_defaults(type, existing_profiles, gitlab_recommended)
        return [] if gitlab_recommended == false

        persisted_recommended_types = existing_profiles.select(&:gitlab_recommended).map(&:scan_type).uniq

        default_scan_profiles
          .select { |profile| matches_requested_type?(profile, type) }
          .reject { |profile| persisted_recommended_types.include?(profile.scan_type) }
      end

      def matches_requested_type?(profile, type)
        type.blank? || profile.scan_type == type
      end

      def default_scan_profiles
        profiles = ::Security::DefaultScanProfilesHelper.default_scan_profiles

        unless Feature.enabled?(:security_remediation_profiles, root_ancestor)
          profiles = profiles.reject(&:post_processing?)
        end

        profiles.each { |scan_profile| scan_profile.namespace_id = root_ancestor.id }
        profiles
      end
    end
  end
end
