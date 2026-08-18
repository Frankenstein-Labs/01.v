# frozen_string_literal: true

module Security
  module DependencyFirewall
    # Single place that decides whether the dependency firewall applies to a container.
    #
    # The flag and license resolve against the top-level group, so one flag enablement covers a
    # whole namespace - see doc/development/feature_flags/_index.md ("Mixing actor types").
    module Availability
      FEATURE = :dependency_firewall

      class << self
        def feature_flag_enabled?(container)
          ::Feature.enabled?(:dependency_firewall_phase1, container&.root_ancestor)
        end

        def available?(container)
          return false if container.nil?

          feature_flag_enabled?(container) && licensed?(container)
        end

        # Consulting the setting here would leave the toggle impossible to switch back on. Only
        # .com exposes this surface; self-managed and Dedicated enable at the instance level.
        def namespace_configurable?(group)
          return false unless group&.root?

          namespace_level? && available?(group)
        end

        def instance_configurable?
          return false if namespace_level?

          # nil actor: the flag resolves instance-wide.
          feature_flag_enabled?(nil) && !!::License.feature_available?(FEATURE)
        end

        def enforced_for?(container)
          available?(container) && setting_enabled?(container)
        end

        private

        def namespace_level?
          ::Gitlab::Saas.feature_available?(FEATURE)
        end

        # licensed_feature_available? checks the license through the namespace hierarchy
        # https://gitlab.com/gitlab-org/gitlab/-/issues/588481 is a linked issue
        def licensed?(container)
          !!container.licensed_feature_available?(FEATURE)
        end

        # namespace or instance setting
        def setting_enabled?(container)
          if namespace_level?
            !!container.root_ancestor&.namespace_settings&.dependency_firewall_enabled
          else
            !!::Gitlab::CurrentSettings.dependency_firewall_enabled
          end
        end
      end
    end
  end
end
