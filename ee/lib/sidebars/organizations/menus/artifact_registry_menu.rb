# frozen_string_literal: true

module Sidebars # rubocop:disable Gitlab/BoundedContexts -- overridden class is not inside a bounded context namespace
  module Organizations
    module Menus
      class ArtifactRegistryMenu < ::Sidebars::Menu
        override :render?
        def render?
          return false unless context.current_user
          return false unless can?(context.current_user, :read_artifact_registry, context.container)

          Feature.enabled?(:artifact_registry_ui, context.container)
        end

        override :title
        def title
          s_('ArtifactRegistry|Artifact registry')
        end

        override :sprite_icon
        def sprite_icon
          'infrastructure-registry'
        end

        override :pick_into_super_sidebar?
        def pick_into_super_sidebar?
          true
        end

        override :configure_menu_items
        def configure_menu_items
          add_item(repositories_menu_item)

          true
        end

        private

        def repositories_menu_item
          link = artifact_registry_repositories_organization_path(
            context.container, ::Organizations::ArtifactRegistry::STUB_SLUG
          )

          ::Sidebars::MenuItem.new(
            title: s_('ArtifactRegistry|Repositories'),
            link: link,
            super_sidebar_parent: ::Sidebars::Organizations::Menus::ArtifactRegistryMenu,
            active_routes: { page: link },
            item_id: :artifact_registry_repositories
          )
        end
      end
    end
  end
end
