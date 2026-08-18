# frozen_string_literal: true

module EE
  module Sidebars
    module Projects
      module Panel
        extend ::Gitlab::Utils::Override

        override :configure_menus
        def configure_menus
          super

          insert_menu_after(
            ::Sidebars::Projects::Menus::ProjectInformationMenu,
            onboarding_menu
          )

          if ::Sidebars::Projects::Menus::IssuesMenu.new(context).show_jira_menu_items?
            remove_menu(::Sidebars::Projects::Menus::ExternalIssueTrackerMenu)
          end

          if ::Sidebars::Projects::Menus::IssuesMenu.new(context).show_zentao_menu_items?
            remove_menu(::Sidebars::Projects::Menus::ZentaoMenu)
          end
        end

        private

        def onboarding_menu
          if trial_or_on_get_started?
            ::Sidebars::Projects::Menus::GetStartedMenu.new(context)
          else
            ::Sidebars::Projects::Menus::LearnGitlabMenu.new(context)
          end
        end

        def trial_or_on_get_started?
          # While we are in-between redesign for trial only and legacy for free,
          # we need to handle the case where trial has not yet been applied in the background
          # so the namespace may not register `trial?` correctly, but we still want to use the new page.
          # This is most likely to only happen on the first page load and this fix can be removed
          # once fully cutover to the new design for free and trials.
          # Detect the current path and if it matches project_get_started_path(context.project) then return true
          return context.show_get_started_menu unless context.project.namespace.trial?

          true
        end
      end
    end
  end
end
