# frozen_string_literal: true

module EE
  module Sidebars # rubocop:disable Gitlab/BoundedContexts -- Existing module
    module Organizations
      module Menus
        module SettingsMenu
          extend ::Gitlab::Utils::Override

          override :configure_menu_items
          def configure_menu_items
            super

            insert_item_after(:organization_settings_general, artifact_registry_menu_item)
          end

          private

          def artifact_registry_menu_item
            unless show_artifact_registry_menu_item?
              return ::Sidebars::NilMenuItem.new(item_id: :organization_settings_artifact_registry)
            end

            ::Sidebars::MenuItem.new(
              title: _('Artifact registry'),
              link: artifact_registry_settings_organization_path(context.container),
              super_sidebar_parent: ::Sidebars::Organizations::Menus::SettingsMenu,
              active_routes: { controller: 'organizations/settings/artifact_registry' },
              item_id: :organization_settings_artifact_registry
            )
          end

          def show_artifact_registry_menu_item?
            ::Feature.enabled?(:artifact_registry_ui, context.container) &&
              can?(context.current_user, :read_artifact_registry, context.container)
          end
        end
      end
    end
  end
end
