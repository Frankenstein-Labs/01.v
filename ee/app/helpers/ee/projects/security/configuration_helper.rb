# frozen_string_literal: true

module EE
  module Projects
    module Security
      module ConfigurationHelper
        extend ::Gitlab::Utils::Override

        override :group_configuration_path
        def group_configuration_path
          group_security_configuration_path(@project.root_ancestor)
        end
      end
    end
  end
end
