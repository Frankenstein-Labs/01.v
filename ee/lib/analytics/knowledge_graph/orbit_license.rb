# frozen_string_literal: true

module Analytics
  module KnowledgeGraph
    # Tier gate for the Orbit (Knowledge Graph) feature.
    #
    # SaaS: entitled when the user holds Reporter+ on any path whose root
    # namespace is :orbit-licensed and enrolled. Roots are resolved via
    # `traversal_ids.first` because `authorized_groups.top_level` is empty
    # for subgroup-only members (it excludes ancestors of direct memberships).
    #
    # Self-managed: delegates to the instance license.
    module OrbitLicense
      CACHE_KEY = 'orbit_feature_licensed'
      POSITIVE_CACHE_PERIOD = 30.minutes
      NEGATIVE_CACHE_PERIOD = 2.minutes

      def self.available_for?(user)
        return false unless user

        return ::License.feature_available?(:orbit) unless ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)

        key = ['users', user.id, CACHE_KEY]

        cached = Rails.cache.read(key)
        return cached unless cached.nil?

        orbit_available = entitled_via_reporter_plus_root?(user)

        Rails.cache.write(
          key,
          orbit_available,
          expires_in: orbit_available ? POSITIVE_CACHE_PERIOD : NEGATIVE_CACHE_PERIOD
        )

        orbit_available
      end

      # Checks entitlement on the root namespace of each authorized path so
      # subgroup-only members inherit the license/enrollment of their root.
      def self.entitled_via_reporter_plus_root?(user)
        root_namespace_ids = ::Analytics::KnowledgeGraph::AuthorizationContext
          .new(user)
          .reporter_plus_root_namespace_ids

        return false if root_namespace_ids.empty?

        ::Group.id_in(root_namespace_ids).include_gitlab_subscription_with_hosted_plan.any? do |root|
          root.licensed_feature_available?(:orbit) && namespace_enrollable_or_enrolled?(root)
        end
      end

      def self.namespace_enrollable_or_enrolled?(group)
        ::Feature.enabled?(:orbit_enroll_namespace, group) ||
          EnabledNamespace.for_root_namespace_id(group.id).exists?
      end
    end
  end
end
