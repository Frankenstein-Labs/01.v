# frozen_string_literal: true

module Sidebars
  module Projects
    module Menus
      class LearnGitlabMenu < ::Sidebars::Menu
        override :link
        def link
          project_learn_gitlab_path(context.project)
        end

        override :active_routes
        def active_routes
          { controller: :learn_gitlab }
        end

        override :title
        def title
          _('Learn GitLab')
        end

        override :sprite_icon
        def sprite_icon
          'bulb'
        end

        override :render?
        def render?
          context.learn_gitlab_enabled
        end

        override :serialize_as_menu_item_args
        def serialize_as_menu_item_args
          super.merge({
            sprite_icon: sprite_icon,
            super_sidebar_parent: ::Sidebars::StaticMenu,
            item_id: :learn_gitlab
          })
        end
      end
    end
  end
end
