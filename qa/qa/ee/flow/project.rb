# frozen_string_literal: true

module QA
  module EE
    module Flow
      module Project
        extend self

        def enable_secrets_manager_feature(project)
          project.visit!

          Page::Project::Menu.perform(&:go_to_general_settings)
          Page::Project::Settings::Main.perform do |settings|
            settings.expand_visibility_project_features_permissions(&:enable_secrets_manager)
          end
        end
      end
    end
  end
end
