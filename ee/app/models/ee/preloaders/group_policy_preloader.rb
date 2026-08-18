# frozen_string_literal: true

module EE
  module Preloaders
    module GroupPolicyPreloader
      extend ::Gitlab::Utils::Override

      override :execute
      def execute
        return if groups.blank?

        super

        ::Namespaces::Preloaders::GroupRootAncestorPreloader.new(groups, root_ancestor_preloads).execute

        if ::Feature.enabled?(:preload_member_roles, current_user)
          ::Preloaders::UserMemberRolesInGroupsPreloader.new(groups: groups, user: current_user).execute
        end

        ::Gitlab::GroupPlansPreloader.new.preload(groups)
      end

      private

      def root_ancestor_preloads
        [:ip_restrictions, :saml_provider]
      end
    end
  end
end
