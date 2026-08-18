# frozen_string_literal: true

module Sidebars # rubocop:disable Gitlab/BoundedContexts -- Existing module
  module Groups
    module SuperSidebarMenus
      class DuoAgentsMenu < ::Sidebars::Menu
        override :configure_menu_items
        def configure_menu_items
          return false unless current_user

          return false unless context.group.duo_features_enabled
          return false unless ai_catalog_visible?

          add_item(ai_catalog_agents_menu_item)
          add_item(ai_catalog_flows_menu_item) if show_flows_menu_item?
          add_item(ai_catalog_mcp_servers_menu_item) if show_mcp_servers_menu_item?

          true
        end

        override :title
        def title
          if Feature.enabled?(:ai_catalog_public_explore, :instance)
            s_('DuoAgentsPlatform|AI')
          else
            s_('DuoAgentsPlatform|Automate')
          end
        end

        override :sprite_icon
        def sprite_icon
          'tanuki-ai'
        end

        override :active_routes
        def active_routes
          { controller: :duo_agents_platform }
        end

        private

        def ai_catalog_visible?
          Feature.enabled?(:ai_catalog_public_explore, :instance) ||
            context.current_user.can?(:read_ai_catalog_item_consumer, context.group)
        end

        def show_mcp_servers_menu_item?
          context.current_user.can?(:read_ai_catalog_mcp_server, context.group)
        end

        def show_flows_menu_item?
          context.current_user.can?(:read_ai_catalog_flow, context.group) ||
            context.current_user.can?(:read_ai_foundational_flow, context.group)
        end

        def ai_catalog_agents_menu_item
          ::Sidebars::MenuItem.new(
            title: s_('AICatalog|Agents'),
            link: group_automate_agents_path(context.group),
            active_routes: nil,
            item_id: :ai_agents,
            library_icon: 'agent-ai',
            description: _('Manage AI agents and flows')
          )
        end

        def ai_catalog_flows_menu_item
          ::Sidebars::MenuItem.new(
            title: s_('AICatalog|Flows'),
            link: group_automate_flows_path(context.group),
            active_routes: nil,
            item_id: :ai_flows,
            library_icon: 'flow-ai',
            description: _('Manage AI flows')
          )
        end

        def ai_catalog_mcp_servers_menu_item
          ::Sidebars::MenuItem.new(
            title: s_('AICatalog|MCP servers'),
            link: group_automate_mcp_servers_path(context.group),
            active_routes: nil,
            item_id: :ai_catalog_mcp_servers,
            library_icon: 'api',
            description: s_('AICatalog|Configure automation triggers')
          )
        end
      end
    end
  end
end
