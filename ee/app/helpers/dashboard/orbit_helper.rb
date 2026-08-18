# frozen_string_literal: true

module Dashboard
  module OrbitHelper
    def orbit_app_data
      data = {
        router_base: dashboard_orbit_path,
        duo_accessible: duo_accessible?.to_s,
        orbit_settings_enabled: orbit_settings_enabled?.to_s
      }

      if admin_orbit_configure_available?
        data[:configure_mode] = 'admin'
        data[:admin_configuration_path] = admin_orbit_path
      elsif saas_orbit_configure_available?
        data[:configure_mode] = 'groups'
      end

      data
    end

    def orbit_page_label
      case params[:vueroute]
      when /\Aschema/ then _('Schema')
      else _('Explore')
      end
    end

    private

    # Can the user reach Duo at all from this dashboard? Independent of
    # whether Orbit is enabled in Duo (that's `orbit_settings_enabled?`).
    # The dashboard sits outside any group scope, so Duo access must
    # resolve against the user's default namespace rather than a
    # surrounding subject.
    def duo_accessible?
      return false unless current_user

      namespace = current_user.user_preference.duo_default_namespace_with_fallback
      return false unless namespace

      current_user.can?(:access_duo_features, namespace) &&
        current_user.can?(:access_duo_entry_point)
    end

    def orbit_settings_enabled?
      ::Ai::Orbit::Settings.killswitch_on?(current_user)
    end

    def admin_orbit_configure_available?
      can?(current_user, :read_admin_knowledge_graph_settings)
    end

    def saas_orbit_configure_available?
      return false unless ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
      return false unless current_user.present?

      ::Feature.enabled?(:knowledge_graph, current_user)
    end
  end
end
