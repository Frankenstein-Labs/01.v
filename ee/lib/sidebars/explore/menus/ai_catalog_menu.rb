# frozen_string_literal: true

module Sidebars # rubocop: disable Gitlab/BoundedContexts -- unknown
  module Explore
    module Menus
      class AiCatalogMenu < ::Sidebars::Menu
        override :link
        def link
          explore_ai_catalog_path
        end

        override :title
        def title
          s_('AICatalog|AI Catalog')
        end

        override :sprite_icon
        def sprite_icon
          'tanuki-ai'
        end

        override :render?
        def render?
          if Feature.enabled?(:ai_catalog_public_explore, :instance)
            ::Ai::Catalog.feature_available?
          else
            Ability.allowed?(current_user, :read_ai_catalog)
          end
        end

        override :active_routes
        def active_routes
          { controller: ['explore/ai_catalog'] }
        end
      end
    end
  end
end
